<#
.SYNOPSIS
Replaces files in a target folder tree with same-named files found in a source folder tree.

.DESCRIPTION
The script prompts for a source folder and target folder. It crawls the source folder
recursively, builds a lookup by file name, then crawls the target folder recursively.
Whenever a target file has the same file name as a source file, the source file is
copied over the target file.

If the source tree contains duplicate file names, the script reports them and asks
which one should be used for that name.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-FolderPath {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    while ($true) {
        $path = Read-Host $Prompt
        $path = $path.Trim().Trim('"')

        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-Warning 'Please enter a folder path.'
            continue
        }

        if (Test-Path -LiteralPath $path -PathType Container) {
            return (Resolve-Path -LiteralPath $path).Path
        }

        Write-Warning "Folder not found: $path"
    }
}

function Select-SourceFile {
    param(
        [Parameter(Mandatory)]
        [string]$FileName,

        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$Files
    )

    Write-Host ''
    Write-Warning "Multiple source files are named '$FileName'."

    for ($i = 0; $i -lt $Files.Count; $i++) {
        Write-Host ("[{0}] {1}" -f ($i + 1), $Files[$i].FullName)
    }

    while ($true) {
        $choice = Read-Host "Choose which source file to use for '$FileName' [1-$($Files.Count)]"
        $number = 0

        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $Files.Count) {
            return $Files[$number - 1]
        }

        Write-Warning 'Invalid choice. Please enter one of the listed numbers.'
    }
}

Write-Warning "This script will overwrite files in the destination folder. Make sure you have backups of any important files before proceeding. This is an AI generated script that HAS been reviewd and tested. Review it yourself to be sure you are comfortable running it. I am not responsible for any damage or loss of data that may occur from running this script."

write-host ''
Write-Host 'You will be prompted for a source and destination folder momentarily. The source should be the folder containing the textures you want to use for replacement. The destination should be the folder containing the textures you want to have replaced. Ex: You want to copy Henriko UI into TPHD pack. Henriko UI folder would be source, TPHD pack would be destination. Note: technically this script can be used for any files, not just textures, but it was designed with texture pack merging in mind so the prompts and warnings are worded with that use case in mind.'

write-host ''
$sourceFolder = Read-FolderPath -Prompt 'Enter the source folder (Make sure to select the subfolder for the textures you want to have get replaced. NOT the main parent folder unless you want to replace the entire pack.)'
$targetFolder = Read-FolderPath -Prompt 'Enter the destination folder (This can be the parent folder for the target pack as it will only replace files that have the same name as those in the source folder regardless of destination folder.)'

if ($sourceFolder -eq $targetFolder) {
    throw 'Source and target folders must be different.'
}

Write-Host ''
Write-Host "Scanning source folder: $sourceFolder"
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceFolder -File -Recurse)

if ($sourceFiles.Count -eq 0) {
    Write-Warning 'No source files were found. Nothing to replace.'
    exit 0
}

$sourceByName = @{}
$sourceFiles |
    Group-Object -Property Name |
    ForEach-Object {
        if ($_.Count -eq 1) {
            $sourceByName[$_.Name] = $_.Group[0]
        }
        else {
            $sourceByName[$_.Name] = Select-SourceFile -FileName $_.Name -Files ([System.IO.FileInfo[]]$_.Group)
        }
    }

Write-Host ''
Write-Host "Scanning target folder: $targetFolder"
$targetFiles = @(Get-ChildItem -LiteralPath $targetFolder -File -Recurse)
$matches = @(
    $targetFiles | Where-Object { $sourceByName.ContainsKey($_.Name) }
)

if ($matches.Count -eq 0) {
    Write-Host 'No target files matched source file names. Nothing to replace.'
    exit 0
}

Write-Host ''
Write-Host "Found $($matches.Count) target file(s) to replace:"
foreach ($targetFile in $matches) {
    $sourceFile = $sourceByName[$targetFile.Name]
    Write-Host "Target: $($targetFile.FullName)"
    Write-Host "Source: $($sourceFile.FullName)"
    Write-Host ''
}

$confirmation = Read-Host "Replace these $($matches.Count) file(s)? Type YES to continue"
if ($confirmation -ne 'YES') {
    Write-Host 'Cancelled. No files were changed.'
    exit 0
}

$replaced = 0
$failed = 0

foreach ($targetFile in $matches) {
    $sourceFile = $sourceByName[$targetFile.Name]

    try {
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $targetFile.FullName -Force
        $replaced++
        Write-Host "Replaced: $($targetFile.FullName)"
    }
    catch {
        $failed++
        Write-Warning "Failed to replace '$($targetFile.FullName)': $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Host "Done. Replaced: $replaced. Failed: $failed."
