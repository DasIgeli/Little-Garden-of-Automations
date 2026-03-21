# Copy Exif Data from File to File.ps1

<#
.SYNOPSIS
Copies EXIF data from source video files to corresponding encoded video files in a specified folder.

.DESCRIPTION
This script searches for video files in a specified directory, excluding those in "Encode" subfolders,
and copies the EXIF data from the original video files to their corresponding encoded video files.
The script uses ExifTool to perform this operation.

.PARAMETER FolderPath
The path to the main folder containing the video files.

.PARAMETER ExifBinary
The path to the ExifTool executable.

.EXAMPLE
.\Copy-ExifData.ps1 -FolderPath "D:\Video\2021-07-09 Saalbach" -ExifBinary "D:\Exif\exiftool.exe"
#>

param (
    [string]$folderPath,
    [string]$exifBinary
)

# Define video file extensions
$videoExtensions = @(".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".mpeg", ".mpg", ".3gp")

# Validate the paths
if (-not (Test-Path -Path $folderPath)) {
    Write-Error "The specified folder path does not exist: $folderPath"
    exit 1
}

if (-not (Test-Path -Path $exifBinary)) {
    Write-Error "ExifTool executable does not exist at the specified path: $exifBinary"
    exit 1
}

# Get all video files recursively, excluding any in "Encode" subfolders
$videoFiles = Get-ChildItem -Path $folderPath -Recurse -File | Where-Object {
    $videoExtensions -contains $_.Extension.ToLower() -and
    $_.FullName -notmatch "\\Encode\\"
}

# Output the results
Write-Host "Found $($videoFiles.Count) video files in '$folderPath' (excluding 'Encode' folders):`n"

foreach ($file in $videoFiles) {
    $encodedFilePath = Join-Path -Path "$($file.Directory)\Encode" -ChildPath "$($file.BaseName).mp4"
    
    if (Test-Path -Path $encodedFilePath) {
        Write-Host "Updating Target File: $encodedFilePath with information from source file: $($file.FullName)"
        & $exifBinary -m -TagsFromFile "$($file.FullName)" -all:all $encodedFilePath
    } else {
        Write-Warning "Encoded file not found for source file: $($file.FullName)"
    }
}


