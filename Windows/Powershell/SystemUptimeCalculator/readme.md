
# System Uptime Calculator

## Overview
System Uptime Calculator is a Windows utility for tracking, logging, and visualizing system uptime. It provides accurate uptime data, logs key Windows Event Log startup events, and can display toast notifications with the latest uptime statistics. The tool is designed for easy analysis and can optionally integrate with Excel for advanced reporting.

## Features
- **Accurate Uptime Logging:** Calculates and logs system uptime, including event log startup times (IDs 6005, 12).
- **CSV Output:** Outputs results to a .csv file in your Documents folder (no Microsoft Office required for logging).
- **Fast Startup Awareness:** Checks and optionally disables Windows Fast Startup for reliable uptime tracking. Includes registry files to enable/disable Fast Startup manually.
- **Toast Notifications:** Displays a desktop toast notification with the latest uptime stats using a customizable XML template. (Requires Excel for current implementation.)
- **Simple Installer:** Batch installer copies scripts to `C:\ProgramData\SystemUptimeCalculator` and creates a desktop shortcut.

## Folder Contents

| File/Folder                  | Description |
|------------------------------|-------------|
| Systemuptimescript.ps1       | Main PowerShell script: calculates/logs uptime, checks Fast Startup, logs event data to CSV. |
| Toast_SystemUptime_Run.ps1   | PowerShell script: reads latest uptime from Excel, displays toast notification (uses Toast_Uptime.xml). |
| SystemUptimeCalc.cmd         | Batch file: runs Systemuptimescript.ps1 via PowerShell. |
| SystemUptimeCalc-Toast.cmd   | Batch file: runs Toast_SystemUptime_Run.ps1 via PowerShell. |
| Install_SystemUptimeCalculator.cmd | Installer: copies scripts to ProgramData, creates desktop shortcut. |
| Disable-FastStartup.reg      | Registry file: disables Windows Fast Startup. |
| Enable-FastStartup.reg       | Registry file: enables Windows Fast Startup. |
| Toast_Uptime.xml             | XML template for toast notification (placeholders replaced by script). |
| Uptime.xlsx (not included)   | Excel file for advanced reporting and toast notification (required for Toast_SystemUptime_Run.ps1). |

## Setup
1. **Run the Installer:**
	- Run `Install_SystemUptimeCalculator.cmd` as Administrator.
	- Scripts are copied to `C:\ProgramData\SystemUptimeCalculator`.
	- A desktop shortcut is created for easy access.
2. **(Optional) Excel Integration:**
	- For toast notifications, place an `Uptime.xlsx` file in the script directory. (Current implementation reads from Excel; refactoring to .csv is recommended.)
3. **(Optional) Fast Startup Registry:**
	- Use `Disable-FastStartup.reg` or `Enable-FastStartup.reg` to manually change Fast Startup settings if needed.

## Usage
### Logging Uptime
1. Double-click the desktop shortcut, or run `Systemuptimescript.ps1` from `C:\ProgramData\SystemUptimeCalculator`.
2. If Fast Startup is enabled, you will be prompted to disable it for accurate tracking.
3. Each run appends a new row to `SystemUptimeResults.csv` in your Documents folder, including:
	- Last boot time
	- Current time
	- Uptime in minutes
	- Most recent Event 6005 and Event 12 timestamps

### Toast Notification
1. Run `SystemUptimeCalc-Toast.cmd` or `Toast_SystemUptime_Run.ps1` to display a toast notification with the latest uptime stats.
2. Requires `Uptime.xlsx` in the script directory and Excel installed.
3. The notification uses `Toast_Uptime.xml` as a template.

## Requirements
- Windows 10/11
- PowerShell 5.1+
- (Optional) Excel for toast notification feature
- Administrator rights for full functionality (especially for registry changes)

## Troubleshooting
- **Permissions:** If you see errors about permissions, right-click the installer and select "Run as administrator."
- **Fast Startup:** If Fast Startup cannot be disabled, run the script as Administrator or use the provided .reg files.
- **Excel/Toast:** Toast notification requires Excel and `Uptime.xlsx`. If you want to use only CSV, consider refactoring the toast script.

## Uninstall
Delete the folder `C:\ProgramData\SystemUptimeCalculator` and the desktop shortcut.

## Credits
Created by Daniel Iglhaut (DasIgeli). Refactored for .csv output and event log integration.
