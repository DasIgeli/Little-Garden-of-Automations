# MP3 Metadata Extractor

## Overview
This PowerShell script provides a function, `Get-MP3MetaData`, to extract metadata from MP3 and MP4 files in a specified directory. It uses the Windows Shell COM object to access file properties and outputs structured metadata for each file.

## Features
- Scans a given directory for `.mp3` and `.mp4` files
- Extracts metadata such as Title, Author, Album, Genre, Duration, and more
- Outputs results as PowerShell custom objects for easy filtering and export
- Supports pipeline input for directory paths

## Usage
### Import and Run
1. Open PowerShell.
2. Navigate to the script directory:
   ```powershell
   cd "<path-to-script-directory>"
   ```
3. Run the script or dot-source it to use the function in your session:
   ```powershell
   . .\Get MP3 Metadata.ps1
   ```
4. Call the function:
   ```powershell
   Get-MP3MetaData -Directory "C:\Music"
   ```

### Example: Exporting Title and Author
```powershell
$MP3Data = Get-MP3MetaData -Directory "C:\Music" | Select Title, Authors
foreach ($entry in $MP3Data) {
    $Title = $entry.Title
    $Author = $entry.Authors
    $NewName = $Author + " " + $Title | Out-File C:\Music\CheckedSongs.txt -Append
}
```

## Parameters
| Name      | Type   | Description                                 |
|-----------|--------|---------------------------------------------|
| Directory | String | Path to the directory to scan (mandatory)   |

- Accepts pipeline input.

## Output
- Returns a custom PowerShell object for each file, containing metadata fields and file information (directory, full path, extension).

## Requirements
- Windows PowerShell
- Access to the Shell.Application COM object

## Author
- DasIgeli

## License
See main project LICENSE file.
