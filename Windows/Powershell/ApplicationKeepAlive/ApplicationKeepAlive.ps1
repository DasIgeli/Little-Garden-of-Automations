<#
.SYNOPSIS
    Ensures a given process is running and that sleep/hibernation are disabled,
    so the system never suspends or drops network connectivity while locked.

.DESCRIPTION
    1. Checks whether the target process is running.
    2. If not, sets location to the process's folder and starts it.
    3. Verifies the process actually came up.
    4. Verifies sleep + hibernation are disabled; disables them if not.
    5. (Optional) Disables power management on network adapters.
    6. Logs every action to C:\terra\KeepAlive.log.

.PARAMETER ProcessName
    Process name as shown by Get-Process, without the .exe extension (e.g. "MyApp").

.PARAMETER ProcessPath
    Folder that contains the executable (e.g. "C:\Program Files\MyApp").

.PARAMETER ExeName
    Optional. Executable filename inside ProcessPath, if it differs from
    "$ProcessName.exe". Defaults to "$ProcessName.exe".

.PARAMETER LogFile
    Optional. Full path to the log file. Defaults to C:\windows\temp\ApplicationKeepAlive.log.

.EXAMPLE
    .\Ensure-ProcessAndPowerState.ps1 -ProcessName "MyApp" -ProcessPath "C:\Program Files\MyApp"

.NOTES
    Requires administrative privileges for the powercfg / network adapter changes.
    Intended to run as a Scheduled Task (e.g. on logon, or every N minutes) as SYSTEM
    or an account with local admin rights.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ProcessName = "members",

    [Parameter(Mandatory = $true)]
    [string]$ProcessPath = "C:\terra\athletics",

    [string]$ExeName = "members.exe",

    [string]$LogFile = "C:\windows\temp\ApplicationKeepAlive.log"
)

# === 5. Logging function (kept as the one explicit function, everything else is inline) ===
function Write-Log {
    param([string]$Message)

    $logDir = Split-Path -Path $LogFile -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"

    Add-Content -Path $LogFile -Value $line
    Write-Output $line
}

Write-Log "===================================================="
Write-Log "Script started. ProcessName='$ProcessName' ProcessPath='$ProcessPath' ExeName='$ExeName'"

# Warn early if not elevated, since powercfg changes need admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "WARNING: Not running elevated. Power setting changes (powercfg) will likely fail."
}

# === 1. Check if process is running ===
$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue

if (-not $proc) {
    Write-Log "Process '$ProcessName' is not running. Starting it."

    try {
        # === 2. Set location to process path and start the process ===
        Set-Location -Path $ProcessPath -ErrorAction Stop
        Start-Process -FilePath (Join-Path -Path $ProcessPath -ChildPath $ExeName) -WorkingDirectory $ProcessPath -ErrorAction Stop
        Write-Log "Start-Process issued for '$ExeName' in '$ProcessPath'."
    }
    catch {
        Write-Log "ERROR: Failed to start process. $($_.Exception.Message)"
    }

    # === 3. Verify process is started (poll for up to 10 seconds) ===
    $retryCount = 0
    while (-not $proc -and $retryCount -lt 10) {
        Start-Sleep -Seconds 1
        $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        $retryCount++
    }

    if ($proc) {
        Write-Log "Verified: '$ProcessName' is now running (PID: $($proc.Id))."
    }
    else {
        Write-Log "ERROR: '$ProcessName' did not start within 10 seconds. Check ProcessPath/ExeName/permissions."
    }
}
else {
    Write-Log "Process '$ProcessName' is already running (PID: $($proc.Id)). No action needed."
}

# === 4. Verify hibernation & sleep are disabled, fix if not ===

# --- Hibernation ---
$hiberEnabled = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name HiberFileEnabled -ErrorAction SilentlyContinue).HiberFileEnabled

if ($hiberEnabled -eq 1) {
    Write-Log "Hibernation is currently ENABLED. Disabling it (powercfg /hibernate off)."
    powercfg /hibernate off
    Write-Log "Hibernation disabled."
}
else {
    Write-Log "Hibernation already disabled."
}

# --- Sleep / standby timeout (AC + DC) ---
# Setting GUID for "Sleep after" under the Sleep subgroup, locale-independent.
$sleepSettingGuid = "29f6c1db-86da-48c5-9fdb-f2b67b0f90d5"

$sleepQueryOutput = powercfg /query SCHEME_CURRENT SUB_SLEEP $sleepSettingGuid
$sleepIndexes = [regex]::Matches($sleepQueryOutput, '0x[0-9A-Fa-f]+') | ForEach-Object { [Convert]::ToInt32($_.Value, 16) }

$sleepAC = $sleepIndexes[0]
$sleepDC = $sleepIndexes[1]

if ($sleepAC -ne 0 -or $sleepDC -ne 0) {
    Write-Log "Sleep timeout is NOT disabled (AC: $sleepAC sec, DC: $sleepDC sec). Setting both to 0 (Never)."
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
    Write-Log "Sleep timeout disabled for AC and DC."
}
else {
    Write-Log "Sleep timeout already disabled (AC and DC both 0)."
}

# === 4b. Optional: prevent network adapters from being powered off (addresses connectivity drops while locked) ===
# Remove/comment this block out if you only want steps 1-5 as listed.
try {
    $netAdapters = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -ErrorAction Stop
    foreach ($adapter in $netAdapters) {
        if ($adapter.Enable -eq $true) {
            $instanceName = $adapter.InstanceName
            Write-Log "Disabling power-saving 'allow device to be turned off' for adapter instance: $instanceName"
            $adapter.Enable = $false
            Set-CimInstance -InputObject $adapter -ErrorAction Stop
        }
    }
    Write-Log "Network adapter power management check complete."
}
catch {
    Write-Log "WARNING: Could not adjust network adapter power management. $($_.Exception.Message)"
}

Write-Log "Script completed."
Write-Log "===================================================="