:: Run the GFX Ops Multitool as an administrator in PowerShell
:: spell-checker: ignore noprofile multitool

powershell -noprofile -command "&{ start-process powershell -ArgumentList '-noprofile -file %~dp0OpsMultitool.ps1' -verb RunAs}"