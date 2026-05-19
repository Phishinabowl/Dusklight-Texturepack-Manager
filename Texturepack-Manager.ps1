<#
.SYNOPSIS
Merges files from a source folder tree into a target folder tree.

.DESCRIPTION
The script prompts for a merge mode, source folder, and target folder.

Mode 1: Replace matching files.
It crawls the source folder recursively, builds a lookup by file name, then crawls
the target folder recursively. Whenever a target file has the same file name as a
source file, the source file is copied over the target file.

Mode 2: Append missing files.
It crawls both folder trees and copies source files into the target folder only when
no file with the same name exists anywhere in the target folder tree. Missing files
are copied into the target folder using their relative path from the source folder,
with "-Imported" appended to each subfolder name.

If the source tree contains duplicate file names, the script reports them and asks
which one should be used for that name in replacement mode.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$excludedFileNames = @(
    'tex1_608x100_0c1c70378fb8cb46_6.dds',
    'tex1_224x29_175aea04816c34a7_2.dds'
)

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

function Read-MergeMode {
    Write-Host ''
    Write-Host 'Select merge mode:'
    Write-Host "[1] Replace matching files - Overwrite one pack's textures with another pack's for a specific set of textures. (Ex: Replace TPHD pack textures with Henriko UI textures.)"
    Write-Host "[2] Append missing files - Add missing textures to another pack."

    while ($true) {
        $choice = Read-Host 'Enter 1 or 2'

        switch ($choice.Trim()) {
            '1' { return 'Replace' }
            '2' { return 'AppendMissing' }
            default { Write-Warning 'Invalid choice. Please enter 1 or 2.' }
        }
    }
}

function Get-SourceLookupByName {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$SourceFiles
    )

    $sourceByName = @{}
    $SourceFiles |
        Group-Object -Property Name |
        ForEach-Object {
            if ($_.Count -eq 1) {
                $sourceByName[$_.Name] = $_.Group[0]
            }
            else {
                $sourceByName[$_.Name] = Select-SourceFile -FileName $_.Name -Files ([System.IO.FileInfo[]]$_.Group)
            }
        }

    return $sourceByName
}

function Get-RelativePathFromFolder {
    param(
        [Parameter(Mandatory)]
        [string]$BaseFolder,

        [Parameter(Mandatory)]
        [string]$FullPath
    )

    $baseWithSeparator = $BaseFolder.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    return $FullPath.Substring($baseWithSeparator.Length)
}

function ConvertTo-ImportedRelativePath {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $fileName = [System.IO.Path]::GetFileName($RelativePath)
    $folderPath = [System.IO.Path]::GetDirectoryName($RelativePath)

    if ([string]::IsNullOrWhiteSpace($folderPath)) {
        return $fileName
    }

    $importedSegments = @(
        $folderPath -split '[\\/]' |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { "$_-Imported" }
    )

    $importedFolderPath = [System.IO.Path]::Combine([string[]]$importedSegments)
    return Join-Path -Path $importedFolderPath -ChildPath $fileName
}

function Get-ImportedDestinationPath {
    param(
        [Parameter(Mandatory)]
        [string]$SourceFolder,

        [Parameter(Mandatory)]
        [string]$TargetFolder,

        [Parameter(Mandatory)]
        [System.IO.FileInfo]$SourceFile
    )

    $relativePath = Get-RelativePathFromFolder -BaseFolder $SourceFolder -FullPath $SourceFile.FullName
    $importedRelativePath = ConvertTo-ImportedRelativePath -RelativePath $relativePath
    return Join-Path -Path $TargetFolder -ChildPath $importedRelativePath
}

function New-PlannedCopy {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$SourceFile,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    [PSCustomObject]@{
        Source = $SourceFile
        Destination = $Destination
    }
}

function Invoke-ReplaceMatchingFiles {
    param(
        [Parameter(Mandatory)]
        [string]$SourceFolder,

        [Parameter(Mandatory)]
        [string]$TargetFolder,

        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$SourceFiles,

        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$TargetFiles
    )

    $sourceByName = Get-SourceLookupByName -SourceFiles $SourceFiles
    $matches = @(
        $TargetFiles | Where-Object { $sourceByName.ContainsKey($_.Name) }
    )

    if ($matches.Count -eq 0) {
        Write-Host 'No target files matched source file names. Nothing to replace.'
        return
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
        return
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
}

function Invoke-AppendMissingFiles {
    param(
        [Parameter(Mandatory)]
        [string]$SourceFolder,

        [Parameter(Mandatory)]
        [string]$TargetFolder,

        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$SourceFiles,

        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$TargetFiles
    )

    $targetNames = @{}
    foreach ($targetFile in $TargetFiles) {
        $targetNames[$targetFile.Name] = $true
    }

    $missingSourceFiles = @(
        $SourceFiles | Where-Object { -not $targetNames.ContainsKey($_.Name) }
    )

    if ($missingSourceFiles.Count -eq 0) {
        Write-Host 'No source files were missing from the destination by file name. Nothing to append.'
        return
    }

    $plannedCopies = @(
        foreach ($sourceFile in $missingSourceFiles) {
            $destinationPath = Get-ImportedDestinationPath -SourceFolder $SourceFolder -TargetFolder $TargetFolder -SourceFile $sourceFile
            New-PlannedCopy -SourceFile $sourceFile -Destination $destinationPath
        }
    )

    Write-Host ''
    Write-Host "Found $($missingSourceFiles.Count) source file(s) missing from the destination:"
    foreach ($plannedCopy in $plannedCopies) {
        Write-Host "Source:      $($plannedCopy.Source.FullName)"
        Write-Host "Destination: $($plannedCopy.Destination)"
        Write-Host ''
    }

    $confirmation = Read-Host "Copy these $($missingSourceFiles.Count) missing file(s) into the destination? Type YES to continue"
    if ($confirmation -ne 'YES') {
        Write-Host 'Cancelled. No files were changed.'
        return
    }

    $copied = 0
    $failed = 0

    foreach ($plannedCopy in $plannedCopies) {
        $destinationFolder = Split-Path -Path $plannedCopy.Destination -Parent

        try {
            if (-not (Test-Path -LiteralPath $destinationFolder -PathType Container)) {
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
            }

            Copy-Item -LiteralPath $plannedCopy.Source.FullName -Destination $plannedCopy.Destination -Force
            $copied++
            Write-Host "Copied: $($plannedCopy.Destination)"
        }
        catch {
            $failed++
            Write-Warning "Failed to copy '$($plannedCopy.Source.FullName)': $($_.Exception.Message)"
        }
    }

    Write-Host ''
    Write-Host "Done. Copied: $copied. Failed: $failed."
}

Write-Warning "This script can overwrite files when running in replace mode. Make sure you have backups of any important files before proceeding. This is an AI generated script that HAS been reviewed and tested. Review it yourself to be sure you are comfortable running it. I am not responsible for any damage or loss of data that may occur from running this script."

write-host ''
Write-Host 'You will be prompted for a source and destination folder momentarily. The source should be the folder containing the textures you want to use for replacement. The destination should be the folder containing the textures you want to have replaced. Ex: You want to copy Henriko UI into TPHD pack. Henriko UI folder would be source, TPHD pack would be destination. Note: technically this script can be used for any files, not just textures, but it was designed with texture pack merging in mind so the prompts and warnings are worded with that use case in mind.'

write-host ''
$mergeMode = Read-MergeMode

write-host ''
$sourceFolder = Read-FolderPath -Prompt 'Enter the source folder (Make sure to select the subfolder for the textures you want to have get replaced. NOT the main parent folder unless you want to replace the entire pack.)'
$targetFolder = Read-FolderPath -Prompt 'Enter the destination folder (This can be the parent folder for the target pack as it will only replace files that have the same name as those in the source folder regardless of destination folder.)'

if ($sourceFolder -eq $targetFolder) {
    throw 'Source and target folders must be different.'
}

Write-Host ''
Write-Host "Scanning source folder: $sourceFolder"
$allSourceFiles = @(Get-ChildItem -LiteralPath $sourceFolder -File -Recurse)
$sourceFiles = @(
    $allSourceFiles | Where-Object { $_.Name -notin $excludedFileNames }
)
$excludedSourceFiles = @(
    $allSourceFiles | Where-Object { $_.Name -in $excludedFileNames }
)

if ($excludedSourceFiles.Count -gt 0) {
    Write-Host "Excluded $($excludedSourceFiles.Count) source file(s) by configured filename exclusions."
}

if ($sourceFiles.Count -eq 0) {
    Write-Warning 'No source files were found. Nothing to merge.'
    exit 0
}

Write-Host ''
Write-Host "Scanning target folder: $targetFolder"
$targetFiles = @(Get-ChildItem -LiteralPath $targetFolder -File -Recurse)

switch ($mergeMode) {
    'Replace' {
        Invoke-ReplaceMatchingFiles -SourceFolder $sourceFolder -TargetFolder $targetFolder -SourceFiles $sourceFiles -TargetFiles $targetFiles
    }
    'AppendMissing' {
        Invoke-AppendMissingFiles -SourceFolder $sourceFolder -TargetFolder $targetFolder -SourceFiles $sourceFiles -TargetFiles $targetFiles
    }
}
