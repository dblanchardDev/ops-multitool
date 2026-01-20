<#
.SYNOPSIS
    Startup and shutdown Azure Virtual Machines.

.NOTES
    Will only list machines that are added to the
    Azure_VM_Management\az_vm_config.json configuration file.

    If this file doesn't already exist, create it and use the JSON
    schema from Azure_VM_Management\az_vm_config.schema.json.

    Authored by David Blanchard
    Copyright Esri Canada 2023-2026 - All Rights Reserved
#>

. $PSScriptRoot\InteractiveMenu.ps1


# Print header
Write-Host "----------------------------------------"
Write-Host "           Azure VM Management          "
Write-Host "----------------------------------------"
Write-Host ""


function Select-AzureVM {
    <#
    .SYNOPSIS
        Choose the VM to manage or login to an account.
    .OUTPUTS
        The object defining the VM as read from the JSON config file. Returns null if the user requested to quit.
        @{"subscription":[String]; "resourceGroup":[String]; "computerName":[String]}
    #>

    $machines = (Get-Content -Path "$($PSScriptRoot)\Azure_VM_Management\az_vm_config.json" | ConvertFrom-Json).machines

    $entries = [ordered]@{}
    $machine_lookup = @{}

    foreach ($machine in $machines) {
        $label = "$($machine.computerName) ($($machine.subscription) | $($machine.resourceGroup))"
        $entries.Add($machine.computerName, $label)
        $machine_lookup.Add($machine.computerName, $machine)
    }

    $entries.Add("______login______", "<< LOGIN TO AZURE >>")

    $selection = InteractiveMenuWithQuit "Select an Azure VM:" $entries

    if ($selection -eq "______login______") {
        Write-Host ""
        az login
        Write-Host ""
        $selection = Select-AzureVM
    }
    elseif ($null -ne $selection) {
        $selection = $machine_lookup[$selection]
    }

    return $selection
}


function Get-AzureVMStatus {
    param (
        [parameter(Mandatory=$true)]
        [System.Object]
        $machine_info
    )

    $status = az vm get-instance-view --name $machine_info.computerName --resource-group $machine_info.resourceGroup --subscription $machine_info.subscription --query instanceView.statuses[1] | ConvertFrom-Json

    Write-Host "Status: $($status.displayStatus)"
}


function Update-AzureVMState {
    param(
        [parameter(Mandatory=$true)]
        [System.Object]
        $machine_info
    )

    $entries = [ordered]@{
        "start"="Start Machine";
        "stop"="Stop Machine";
        "deallocate"="Deallocate Machine (Stops billing)";
    }

    $selection = InteractiveMenuWithQuit "Select an operation:" $entries -quitLabel "CANCEL"

    Write-Host ""
    switch ($selection)
    {
        "start" {
            az vm start --subscription $machine_info.subscription -g $machine_info.resourceGroup -n $machine_info.computerName
        }
        "stop" {
            az vm stop --subscription $machine_info.subscription -g $machine_info.resourceGroup -n $machine_info.computerName
        }
        "deallocate" {
            az vm deallocate --subscription $machine_info.subscription -g $machine_info.resourceGroup -n $machine_info.computerName
        }
    }
}


& {
    <#
    .SYNOPSIS
        Self invoking function which runs the script.
    #>

    $machine = Select-AzureVM

    if ($null -ne $machine) {
        Write-Host ""
        Get-AzureVMStatus $machine

        Write-Host ""
        Update-AzureVMState $machine

        Write-Host ""
        Get-AzureVMStatus $machine
    }
}