<#
.SYNOPSIS
Extracts metadata from MP3 and MP4 files in a specified directory.

.DESCRIPTION
The Get-MP3MetaData function scans a given directory for MP3 and MP4 files and extracts their metadata using the Windows Shell COM object. The metadata includes properties such as Title, Author, Album, Genre, Duration, and more. The function outputs a custom PowerShell object for each file containing the extracted metadata, the directory, full file path, and file extension.

.PARAMETER Directory
The path to the directory containing MP3 or MP4 files. Accepts pipeline input.

.OUTPUTS
PSCustomObject. Each object contains metadata fields and file information.

.EXAMPLE
Get-MP3MetaData -Directory "C:\Music"
Extracts metadata from all MP3 and MP4 files in the C:\Music directory.

.EXAMPLE
'C:\Music' | Get-MP3MetaData | Select Title, Authors
Extracts metadata and selects only the Title and Authors fields.

.NOTES
Author: DasIgeli
Date: 2022-03-11
Requires: Windows PowerShell, Shell.Application COM object

#>
Function Get-MP3MetaData
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([Psobject])]
    Param
    (
        [String] [Parameter(Mandatory=$true, ValueFromPipeline=$true)] $Directory
    )

    Begin
    {
        $shell = New-Object -ComObject "Shell.Application"
    }
    Process
    {

        Foreach($Dir in $Directory)
        {
            $ObjDir = $shell.NameSpace($Dir)
            $Files = gci $Dir | ?{$_.Extension -in '.mp3','.mp4'}

            Foreach($File in $Files)
            {
                $ObjFile = $ObjDir.parsename($File.Name)
                $MetaData = @{}
                $MP3 = ($ObjDir.Items()|?{$_.path -like "*.mp3" -or $_.path -like "*.mp4"})
                $PropertArray = 0,1,2,12,13,14,15,16,17,18,19,20,21,22,27,28,36,220,223
            
                Foreach($item in $PropertArray)
                { 
                    If($ObjDir.GetDetailsOf($ObjFile, $item)) #To avoid empty values
                    {
                        $MetaData[$($ObjDir.GetDetailsOf($MP3,$item))] = $ObjDir.GetDetailsOf($ObjFile, $item)
                    }
                 
                }
            
                New-Object psobject -Property $MetaData |select *, @{n="Directory";e={$Dir}}, @{n="Fullname";e={Join-Path $Dir $File.Name -Resolve}}, @{n="Extension";e={$File.Extension}}
            }
        }
    }
    End
    {
    }
}


$MP3Data = Get-MP3MetaData -Directory "C:\Music" | select Title, Authors
foreach ($entry in $MP3Data)
{
$Title = $entry.Title
$Author = $entry.Authors

$NewName = $Author + " " + $Title | Out-file  C:\Music\CheckedSongs.txt -append

#$NewName = $Author + " " + $Title
}


