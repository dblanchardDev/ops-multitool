<#
.SYNOPSIS
    Startup and shutdown Hyper-V VMs and automatically update their IP addresses in the host file.

.NOTES
    Authored by David BLanchard
    Copyright Esri Canada 2023-2026 - All Rights Reserved
#>

# spell-checker: ignore hostfile


. $PSScriptRoot\InteractiveMenu.ps1


# Print header
Write-Host "----------------------------------------"
Write-Host "        Hyper-V Machine Management      "
Write-Host "----------------------------------------"
Write-Host ""


# region: Host File Management


function Write-FullFileSafely {
    <#
    .SYNOPSIS
    Safely rewrites a file by writing to a temporary file, then replacing the original atomically.
    Retries once if the destination file is locked.

    .PARAMETER Lines
    The complete array of lines to write.

    .PARAMETER Path
    The target file to replace.

    .PARAMETER Encoding
    Encoding to use (default ASCII for hosts compatibility).
    #>

    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string[]] $Lines,


        [Parameter(Mandatory=$true)]
        [string] $Path,

        [string] $Encoding = "ASCII"
    )

    $temp = [System.IO.Path]::GetTempFileName()

    try {
        # 1. Write the full content to a temp file
        $Lines | Out-File -FilePath $temp -Encoding $Encoding -ErrorAction Stop
    }
    catch {
        Remove-Item $temp -ErrorAction SilentlyContinue
        throw
    }

    # 2. Try replacing the original atomically (with one retry)
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            Move-Item -Path $temp -Destination $Path -Force -ErrorAction Stop
            return  # success
        }
        catch {
            if ($attempt -eq 1) {
                Start-Sleep -Seconds 2
                continue
            }
            # Final failure — clean temp and rethrow
            Remove-Item $temp -ErrorAction SilentlyContinue
            throw
        }
    }
}


function Add-EntryToHostfile {
    <#
    .SYNOPSIS
        Add an entry to a host file, removing other matching host-names first.
    .PARAMETER filename
        Path to the host file to edit.
    .PARAMETER ip
        IP address to be added to the host file.
    .PARAMETER hostname
        Host name to be directed to the IP address.
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]
        $filename,
        [parameter(Mandatory = $true)]
        [string]
        $ip,
        [parameter(Mandatory = $true)]
        [string]
        $hostname
    )

    Remove-EntryFromHost $filename $hostname

    $newLines = Get-Content -LiteralPath $filename -ErrorAction Stop #existing contents
    $newLines += $ip + "`t`t" + $hostname + "`t`t# Hyper-V VM" # add new IP

    Write-FullFileSafely -Lines $newLines -Path $filename -Encoding ASCII
}


function Remove-EntryFromHost {
    <#
    .SYNOPSIS
        Remove entries with a certain host name from a host file.
    .PARAMETER filename
        Path to the host file to edit.
    .PARAMETER hostname
        Host name to be directed to the IP address.
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]
        $filename,
        [parameter(Mandatory = $true)]
        [string]
        $hostname
    )

    $c = Get-Content $filename
    $newLines = @()

    foreach ($line in $c) {
        $cleanLine = $line.Trim()

        # Skip comment lines
        if (-not $cleanLine.StartsWith("#")) {

            # If hostname matches, skip to next loop
            $bits = [regex]::Split($line.Trim(), "\s+")
            if ($bits.count -ge 2) {
                if ($bits[1] -eq $hostname) {
                    continue
                }
            }

        }

        $newLines += $line
    }

    # Write file
    Write-FullFileSafely -Lines $newLines -Path $filename -Encoding ASCII
}


function Update-HostFileForHost {
    <#
    .SYNOPSIS
        Update the hostfile entry for a specific VM.
    .PARAMETER vm_name
        Name of the VM whose hostfile entry is to be updated.
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]
        $vm_name
    )

    $ipv4 = (Get-VMNetworkAdapter $vm_name).IPAddresses[0];
    if ($null -ne $ipv4) {
        $hostname = ([System.Net.Dns]::GetHostByAddress($ipv4).Hostname).Split(".")[0]
        if ($null -ne $hostname) {
            Add-EntryToHostfile "C:\Windows\System32\drivers\etc\hosts" $ipv4 $hostname
        }
        else {
            Write-Warning "Could not update the hostfile as no hostname available."
        }
    }
    else {
        Write-Warning "Could not update the hostfile as no IP available."
    }
}


# endregion
# region Hyper-V Checkpoints/Snapshots


function Select-CheckpointFromTree {
    <#
    .SYNOPSIS
    Show checkpoints (snapshots) for a VM in a tree (parent → children) with indentation,
    similar to the Hyper‑V UI, and let the user pick one.

    .PARAMETER vm_name
    Name of the VM whose checkpoints will be listed.

    .OUTPUTS
    String. The chosen checkpoint's Id (GUID) as a string. Null if cancel was chosen or none exist.

    .NOTES
    - Uses checkpoint Ids (GUIDs) as menu keys to avoid ambiguity when names repeat.
    - Indents children by 2 spaces per level.
    - Written with the help of Copilot
    #>
    [OutputType([String])]
    param(
        [parameter(Mandatory = $true)]
        [string] $vm_name
    )

    # Retrieve all checkpoints and pre-sort newest first for stable sibling ordering
    $snapshots = Get-VMSnapshot -VMName $vm_name -ErrorAction Stop

    if (-not $snapshots -or $snapshots.Count -eq 0) {
        Write-Warning "No checkpoints found for '$vm_name'."
        return $null
    }

    # Build lookup tables
    $byId = @{}
    $children = @{}  # ParentId -> [child snapshots]
    foreach ($s in $snapshots) {
        $byId[$s.Id.Guid] = $s
        $parentId = $null
        # Some hosts expose ParentSnapshotId as null for roots
        if ($s.PSObject.Properties.Match('ParentSnapshotId').Count -gt 0) {
            $parentId = $s.ParentSnapshotId
        }
        if ($null -ne $parentId) {
            $vmPID = $parentId.Guid
            if (-not $children.ContainsKey($vmPID)) { $children[$vmPID] = New-Object System.Collections.Generic.List[object] }
            $children[$vmPID].Add($s)
        }
    }

    # Roots are checkpoints that are not listed as a child of anyone
    $allIds = [System.Collections.Generic.HashSet[string]]::new()
    $childIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($s in $snapshots) { [void]$allIds.Add($s.Id.Guid) }
    foreach ($kvp in $children.GetEnumerator()) {
        foreach ($c in $kvp.Value) { [void]$childIds.Add($c.Id.Guid) }
    }
    $rootIds = $allIds.Where({ -not $childIds.Contains($_) })

    # Render a depth‑first, indented list
    $options = [ordered]@{}

    function AddNode([string]$id, [int]$depth) {
        $node = $byId[$id]
        if ($null -eq $node) { return }

        # Use Id (GUID) as the stable key returned by the menu
        $indent   = ('  ' * $depth)
        $options[$node.Id.Guid] = "$indent$($node.Name)"

        # Add children (already globally sorted newest-first)
        if ($children.ContainsKey($node.Id.Guid)) {
            foreach ($child in $children[$node.Id.Guid]) {
                AddNode $child.Id.Guid ($depth + 1)
            }
        }
    }

    # Start from roots, newest-first (roots already in $snapshots order, so filter)
    foreach ($s in $snapshots) {
        $sid = $s.Id.Guid
        if ($rootIds -contains $sid) {
            AddNode $sid 0
        }
    }

    # Interactive menu
    $selection = InteractiveMenuWithQuit "Select a checkpoint for '$vm_name':" $options -quitLabel "CANCEL"
    return $selection
}


function Restore-CheckpointFromTree {
    <#
    .SYNOPSIS
    Show the user a tree of checkpoints available for a specific VM. The selection will be applied to the VM.

    .PARAMETER vm_name
    Name of the VM whose checkpoints will be listed.

    .OUTPUTS
    Boolean. Whether a checkpoint was restored.
    #>
    [OutputType([bool])]
    param(
        [parameter(Mandatory = $true)]
        [string] $vm_name
    )

    # Ask user to select an available checkpoint
    $checkpointId = Select-CheckpointFromTree -vm_name $vm_name
    if (-not $checkpointId) {
        Write-Host "No checkpoint selected. Operation cancelled."
        return $false
    }

    $snapshot = Get-VMSnapshot -VMName $vm_name -ErrorAction Stop | Where-Object { $_.Id.Guid -eq $checkpointId }

    # Confirm with the user that they want to apply the checkpoint
    Write-Host ""
    $confirmOptions = [ordered]@{
        "cancel" = "Cancel Checkpoint Restore"
        "proceed" = "Erase Current VM State and Restore Checkpoint"
    }
    $confirmChoice = InteractiveMenu "Are you sure you want to restore checkpoint '$($snapshot.Name)' to VM '$($vm_name)'?" $confirmOptions

    if ($confirmChoice -eq "cancel") {
        return $false
    }

    # Proceed with checkpoint restore
    Restore-VMSnapshot -VMSnapshot $snapshot -Confirm:$false

    return $true
}

function New-Checkpoint {
    <#
    .SYNOPSIS
    Create a new checkpoint for a specific VM, prompting the user for a name.

    .PARAMETER vm_name
    Name of the VM whose checkpoints will be listed.
    #>
    param(
        [parameter(Mandatory = $true)]
        [string] $vm_name
    )

    $checkpointName = Read-Host -Prompt "Please enter a name for the checkpoint"
    Checkpoint-VM -Name $vm_name -SnapshotName $checkpointName
}


# endregion


function Select-VMOperation {
    <#
    .SYNOPSIS
        Provide the user with options to manage a specific Hyper-V VM.
    .PARAMETER vm_name
        Name of the VM to be managed.
    #>
    param(
        [parameter(Mandatory = $true)]
        [String]
        $vm_name
    )

    # Create list of valid operations
    $vm_info = Get-VM -Name $vm_name
    $operations = [ordered]@{}

    if ($vm_info.state -eq "Running") {
        $operations.Add("shutdown", "Shutdown")
        $operations.Add("save", "Save and Stop")
        $operations.Add("host", "Update Host-file")
    }
    else {
        $operations.Add("start", "Start and Update Host-file")
    }
    $operations.Add("apply-checkpoint", "Apply Checkpoint, Start, and Update Host-file")
    $operations.Add("take-checkpoint", "Take New Checkpoint After Shutting Down VM")

    # Get user to choose and then run the operation
    $selection = InteractiveMenuWithQuit "Select an operation:" $operations -quitLabel "CANCEL"
    Write-Host ""

    switch ($selection) {
        "start" {
            Start-VM -Name $vm_name
            Start-Sleep -Seconds 10
            Update-HostFileForHost $vm_name
        }
        "host" {
            Update-HostFileForHost $vm_name
        }
        "shutdown" {
            Stop-VM -Name $vm_name
        }
        "save" {
            Save-VM -Name $vm_name
        }
        "apply-checkpoint" {
            $vm_restored = Restore-CheckpointFromTree -vm_name $vm_name
            if ($vm_restored) {
                Start-Sleep -Seconds 1
                Start-VM -Name $vm_name
                Start-Sleep -Seconds 10
                Update-HostFileForHost $vm_name
            }
        }
        "take-checkpoint" {
            Stop-VM -Name $vm_name
            New-Checkpoint -vm_name $vm_name
            Start-VM -Name $vm_name
        }
    }
}


function Select-VMByName {
    <#
    .SYNOPSIS
        Ask the user to interactively choose a VM.

    .OUTPUTS
        String. Name of the VM chosen by the user. Null if quit was chosen.
    #>
    [OutputType([String])]

    # Get list of VMs
    $vm_options = [ordered]@{}

    foreach ($machine in Get-VM) {
        $vm_options.Add($($machine.Name), "$($machine.Name) ($($machine.State))")
    }

    # Ask user to choose VM
    $selection = InteractiveMenuWithQuit "Select a VM:" $vm_options

    return $selection
}


& {
    <#
    .SYNOPSIS
        Self invoking function which runs the script.
    #>

    $vm_name = Select-VMByName
    if ($null -ne $vm_name) {
        Write-Host ""
        Select-VMOperation $vm_name
    }
}