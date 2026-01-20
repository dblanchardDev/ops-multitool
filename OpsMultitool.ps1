<#
.SYNOPSIS
    Operations Multitool
.DESCRIPTION
    A common place to store and run various simple automation tools and scripts originally used
    by the Esri Canada GeoFoundation Exchange operations team.
.NOTES
    Authored by David Blanchard
    Copyright Esri Canada 2023-2026 - All Rights Reserved
#>

# spell-checker: ignore multitool

. $PSScriptRoot\tools\InteractiveMenu.ps1

& {
    <#
    .SYNOPSIS
        Self invoking function which runs the interactive tool.
    #>
    for (;;) {

        # Print header
        Clear-Host
        Write-Host "------------------------------------"
        Write-Host "           Ops Multitool            "
        Write-Host "  Copyright Esri Canada 2023-2026   "
        Write-Host "------------------------------------"
        Write-Host ""

        # Assemble list of tools
        $options = [ordered]@{}

        Get-ChildItem $PSScriptRoot\tools -Filter *.ps1 |
        Foreach-Object {
            if ($_.BaseName -ne "InteractiveMenu") {
                $options.Add($_.FullName, $_.BaseName.Replace("_", " "))
            }
        }


        # Request selection then execute tool or quit
        $selected = InteractiveMenuWithQuit "What tool do you want to run?" $options

        Clear-Host

        if ($null -eq $selected) {
            break
        }

        & $selected
        Write-Host ""
        Read-Host -Prompt "Press enter to return to main menu"
    }
}