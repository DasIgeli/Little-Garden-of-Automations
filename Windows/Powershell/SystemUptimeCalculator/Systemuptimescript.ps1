# <#
# .SYNOPSIS
#   Calculates and logs Windows system uptime, including event log startup times, and outputs results to a .csv file.
#
# .DESCRIPTION
#   This script checks the Fast Startup registry setting, optionally disables it, queries the Windows Event Log for recent startup events (IDs 6005 and 12),
#   and appends the results to a .csv file in the user's Documents folder. Designed for accurate uptime tracking and easy analysis.
#
# .EXAMPLE
#   .\Systemuptimescript.ps1
#   Runs the script, checks Fast Startup, logs uptime and event data to SystemUptimeResults.csv in Documents.
#
# .OUTPUTS
#   CSV file: SystemUptimeResults.csv in the user's Documents folder, with columns for boot time, current time, uptime, and event log times.
#
# .NOTES
#   Requires PowerShell 5.1+ and may require Administrator rights to change registry settings.
#   Created by DasIgeli, refactored for .csv output and event log integration.
#>


# Query Windows Event Log for startup events
# System Event ID 6005: "The Event log service was started" (system boot)
$event6005 = Get-WinEvent -FilterHashtable @{LogName='System'; Id=6005} -MaxEvents 5 | Select-Object -Property TimeCreated
# Kernel-Boot Event ID 12: "Operating system started" (boot)
$event12 = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-General'; Id=12} -MaxEvents 5 | Select-Object -Property TimeCreated

# Get the most recent event times (if available)
$lastEvent6005 = $event6005[0].TimeCreated
$lastEvent12 = $event12[0].TimeCreated
# Check Fast Startup registry setting
$fastStartupKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
$fastStartupValue = 'HiberbootEnabled'
$fastStartup = Get-ItemProperty -Path $fastStartupKey -Name $fastStartupValue -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $fastStartupValue -ErrorAction SilentlyContinue

if ($null -eq $fastStartup) {
    Write-Host "[INFO] Fast Startup registry value not found. Skipping check."
} elseif ($fastStartup -eq 1) {
    Write-Host "[WARNING] Fast Startup is ENABLED. This may affect uptime calculations."
    $choice = Read-Host "Do you want to disable Fast Startup now? (Y/N)"
    if ($choice -eq 'Y' -or $choice -eq 'y') {
        try {
            Set-ItemProperty -Path $fastStartupKey -Name $fastStartupValue -Value 0 -Force
            Write-Host "[INFO] Fast Startup has been disabled. A reboot may be required for changes to take effect."
        } catch {
            Write-Host "[ERROR] Failed to disable Fast Startup. Please run this script as Administrator."
        }
    } else {
        Write-Host "[INFO] Fast Startup remains enabled. Uptime results may be inaccurate."
    }
} else {
    Write-Host "[INFO] Fast Startup is already disabled."
}

# Set path to output CSV file
$outputPath = "$env:USERPROFILE\Documents\SystemUptimeResults.csv"

# Create entries for the CSV file
$Lastboottime = (Get-CimInstance -ClassName win32_operatingsystem).LastBootUpTime
$CurrentTime = Get-Date
$DifferenceTime = [math]::Round(($CurrentTime - $Lastboottime).TotalMinutes,0)


# Create PSObject with the properties that we want, including event log data
$Record = [PSCustomObject]@{
    'LastbootTime' = $Lastboottime
    'CurrentTime' = $CurrentTime
    'DifferenceTime_Minutes' = $DifferenceTime
    'Event6005_Time' = $lastEvent6005
    'Event12_Time' = $lastEvent12
}

# Check if the CSV file exists
if (-Not (Test-Path $outputPath)) {
    # Create new CSV with headers
    $Record | Export-Csv -Path $outputPath -NoTypeInformation
} else {
    # Append to existing CSV (no headers)
    $Record | Export-Csv -Path $outputPath -NoTypeInformation -Append
}