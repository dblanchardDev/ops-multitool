<!-- spell-checker: word multitool -->
# Ops Multitool

Various tools used during development and infrastructure operations, originally developed for the Esri Canada GeoFoundation Exchange project.

## Running the Multitool

Run the _OpsMultitool.ps1_ PowerShell script using Windows PowerShell with administrative privileges. You may use the _OpsMultitool.bat_ file to automatically launch the PowerShell script with administrative privileges.

Please note that this tool is untested with PowerShell Core (6+) and may not work as expected.

## Tools

The following tools are available in the Ops Multitool. Some tools may require additional configuration before being run.

### Azure VM Management

Run simple operations on your Azure hosted VMs, such as checking their state, starting them, shutting them down, and de-allocating them.

If you are not already logged-in to Azure via the CLI, you will need to select the log-in option before attempting operations on your VMs.

#### Requirements and Configuration

The [Azure CLI on Windows](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&pivots=winget) must be installed on the machine running the tool and the `az` command must be specified in the environment variable paths.

Additionally, only machines configured in the [tools\Azure_VM_Management\az_vm_config.json](tools\Azure_VM_Management\az_vm_config.json) will be available for management. If the file doesn't exist yet, create it and use the JSON schema located in [tools\Azure_VM_Management\az_vm_config.schema.json](tools\Azure_VM_Management\az_vm_config.schema.json) to define the structure of the configuration file.

```json
{
    "$schema": "az_vm_config.schema.json",

    "machines": [
        {
            "subscription": "XYZ Co. Subscription",
            "resourceGroup": "Core-Systems",
            "computerName": "my-machine-name"
        }
    ]
}
```

### Hyper-V Machine Management

Run simple startup, shutdown, and checkpoint operations on your local Hyper-V VMs along with updating your host file with the VM IPs and hostnames.

| Operation | Description |
| --------- | ----------- |
| Update Host File | Update the host file to point the VMs hostname (not the VM name in Hyper-V) to the machine's IP. Allows users to point their client software to a hostname rather than a dynamic (and changing) IP address. The VM must have _Guest services_ enabled in the _Integration Services_ settings for this to work. For Linux machines, you may need to install the Azure-tuned Kernel using `sudo apt-get update` followed by `sudo apt-get install linux-azure` to make the _Guest Services_ work. |
| Start and Update Host File | Will start the VM using its previous state and update the host file (see _Update Host File_ operation). |
| Shutdown | Gracefully shut down the guest operating system. |
| Save and Stop | Save the VMs current state to disk and stops the VM (similar to hibernation). |
| Apply Checkpoint, Start, and Update Host File | Restore the VM state from an existing VM, after which the VM will be started and the host file update (see _Update Host File_ operation). This will erase the current state of the VM. |
| Take New Checkpoint After Shutting Down VM | Will shut down the VM before taking a new checkpoint. Will prompt for the name to give to this new checkpoint. |

_The list of available operations will vary depending on the state of the VM._

## Development

To add new tools, create a PowerShell script file (.ps1) in the _\tools_ directory. The name displayed to users will be derived from the filename, with underscores replaced with spaces. When a user selects the corresponding entry in the menu, the PowerShell script will be executed. Therefore, your script should self-invoke.

If you need to include additional files beyond the main script, create a sub-directory that has the same name as your main script file and place the additional files into that sub-directory.

Remember to document your tool in the [Tools](#tools) section of this README.

### Interactive Menu

If you want to include an interactive menu like the one used in the main menu, simply import the _tools\InteractiveMenu.ps1_ file and follow the instructions found at the top of that file.

## Support

This tool is distributed "AS IS" and is not supported nor certified by Esri Canada. No guarantees are made regarding the functionality and proper functioning of this tool.

## Contributions

If you wish to contribute to this project, please contact David Blanchard in advance.

## License

Copyright 2023-2026 Esri Canada

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see [https://www.gnu.org/licenses/](https://www.gnu.org/licenses/).
