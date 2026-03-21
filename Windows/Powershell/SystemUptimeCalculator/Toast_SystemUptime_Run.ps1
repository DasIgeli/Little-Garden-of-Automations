<#
.SYNOPSIS
        Displays a toast notification with system uptime information, using data from an Excel file.

.DESCRIPTION
        This script reads the latest uptime and boot data from an Excel file, formats a custom toast notification using a template XML,
        and displays it on the desktop. Intended for quick, visual feedback on system uptime.

.EXAMPLE
        .\Toast_SystemUptime_Run.ps1
        Shows a toast notification with the most recent uptime stats from the Excel file.

.NOTES
        Requires Excel and Windows 10/11. Created by Daniel Iglhaut.
        Refactoring to use .csv instead of Excel is recommended for future compatibility.
#>


#region Parameters
param(
        [string]$mediapath = $PSScriptRoot
)
#endregion


# Temporary file is created in the folder below. Its always overwritten
$Xmltemppath = "$env:TEMP"


# Don't change
$xmlfilename = "Toast_Uptime.xml"


# Current Logo for toast
$logopath = Join-Path -Path $mediapath -ChildPath "logo.png"


# How long should the script wait until popup in seconds. Smallest value = 1
$waituntilpopup = 2


# Set path to Excelfile
$Excelpath = Join-Path -Path $mediapath -ChildPath "Uptime.xlsx"


# Pause script to let other things display a message beforehand
Start-Sleep -Seconds $waituntilpopup
 


#Launch Excel
$XL = New-Object -ComObject Excel.Application
#Open the workbook
$WB = $XL.Workbooks.Open("$Excelpath")
#Activate Sheet1, pipe to Out-Null to avoid 'True' output to screen
$WB.Sheets.Item("Sheet1").Activate() | Out-Null
#Find first blank row #, and activate the first cell in that row
$FirstBlankRow = $($xl.ActiveSheet.UsedRange.Rows)[-1].Row + 0
$XL.ActiveSheet.Range("A$FirstBlankRow").Activate()
$Lastboot = $XL.Cells.Item($FirstBlankRow, 1).Text
[double]$LastUptimeDuration = $XL.Cells.Item($FirstBlankRow, 3).Text
[double]$LastUptimeDuration = [math]::Round(($LastUptimeDuration /60),2)
[double]$TotalUptimeH = $XL.Cells.Item(3, 6).Value2
[double]$TotalUptimeD = $XL.Cells.Item(3, 7).Value2
$XL.Quit() | Out-Null


        
        
        if ($LastUptimeDuration -lt 6)
        {
        $LastUptimeText = "Der Rechner lief $lastuptimeduration Stunden."
        }
        elseif ($LastUptimeDuration -lt 10)  
        {
        $LastUptimeText = "Die Kiste war $lastuptimeduration Stunden an!"
        }
        elseif ($LastUptimeDuration -lt 14)  
        {
        $LastUptimeText = "Unermüdlich wurde der Rechner für $lastuptimeduration Stunden gequält!"
        }
        elseif ($LastUptimeDuration -ge 14)  
        {
        $LastUptimeText = "Da wollte es aber wer wissen... $lastuptimeduration Stunden!!!"
        }
              
        $TotalUptime = "$totaluptimeH Stunden bzw. $totaluptimeD Tage"     

        Write-Host "$TotalUptime"
        Write-Host "$LastUptimeText"

        ### Create Toast Notification
        # Get Source XML
        $xmlsourcepath = Join-Path -Path $mediapath -ChildPath "Toast_Uptime.xml"

        # Replace the values with the placeholders in the xml file
        $Content = Get-Content -Path $xmlsourcepath 
        $CleanContent = $Content -replace '__totaluptime__', "$totalUptime"
        $CleanContent = $CleanContent -replace '__path__', "$logopath"
        $CleanContent = $CleanContent -replace '__lastboot__', "$LastBoot"
        $CleanContent = $CleanContent -replace '__lastuptimetext__', "$LastUptimeText"
        Set-Content $CleanContent -Path (Join-Path -Path $Xmltemppath -ChildPath $xmlfilename)

        #Loading required Runtimes to launch the Toast
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

        # Use the AppID for Windows PowerShell for reliable toast notifications.
        $AppId = 'Windows.PowerShell'

        # Load XML file
        $ToastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
        $ToastXml.LoadXml((Get-Content -Path (Join-Path -Path $Xmltemppath -ChildPath $xmlfilename)))

        Write-Host "Toast XML file exists: $(Test-Path "$(Join-Path -Path $Xmltemppath -ChildPath $xmlfilename)")"

        #Launch Toast along with AppID
        $Toast = [Windows.UI.Notifications.ToastNotification]::new($ToastXml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($Toast)
                                                       
    
exit 0

