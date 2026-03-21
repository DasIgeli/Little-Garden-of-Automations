# Copy Exif Data from File to File

This PowerShell script copies EXIF data from original video files to their corresponding encoded video files in a specified directory. It uses the ExifTool executable to perform this operation.

## Prerequisites

- [ExifTool](https://exiftool.org/) must be installed and accessible via the provided path.

## Usage

Run the script with the following parameters:

```powershell
.\Copy-ExifData.ps1 -FolderPath "D:\Video\2021-07-09 Saalbach" -ExifBinary "D:\Exif\exiftool.exe"
```

### Parameters

- `-FolderPath`: The path to the main folder containing the video files.
- `-ExifBinary`: The path to the ExifTool executable.

## Notes

- The script excludes any video files located within an "Encode" subfolder.
- Detailed logging is provided to indicate whether each encoded file was updated successfully or if it was not found.