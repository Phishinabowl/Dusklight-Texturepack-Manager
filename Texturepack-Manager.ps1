<#
.SYNOPSIS
Merges files from a source folder tree into a target folder tree.

.DESCRIPTION
The script prompts for a merge mode, source folder, and target folder.

Mode 1: Append missing files.
It crawls both folder trees and copies source files into the target folder only when
no matching file exists anywhere in the target folder tree. DDS and PNG files match
by base file name even when their extensions are different, so append mode will not
add a PNG when a same-base DDS already exists, or vice versa. Missing files are
copied into the target folder using their relative path from the source folder,
with "-Imported" appended to each subfolder name.

Mode 2: Replace matching files.
It crawls the source folder recursively, builds a lookup by file name, then crawls
the target folder recursively. Whenever a target file has the same file name as a
source file, the source file is copied over the target file. DDS and PNG files can
also match by base file name even when their extensions are different. Source files
with no matching target file are copied into an "Extras-Imported" folder inside
the destination folder.

If the source tree contains duplicate file names, the script reports them and asks
which one should be used for that name in replacement mode.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# These are two incorrect texture files that Henriko left in the 1080p version of his pack. They're the "4K" and "4K Textures by Henriko" textures from the title screen. Ignoring them leaves it saying "HD" properly.
$excludedFileNames = @(
    
    'tex1_608x100_0c1c70378fb8cb46_6.dds',
    'tex1_224x29_175aea04816c34a7_2.dds'
)

# These are the 3 known bad map files that have incorrect filenames. They're used later in the script to optionally apply a fix as part of pack compliation. The fix is currently specific to replacing part of the filename with a $ but can be modified to be more flexible if needed in the future.
$knownBadMapFileNames = @(
    'tex1_102x120_f3773035018b6280_459566e922a89796_9.dds',
    'tex1_144x106_8263979b7265344e_61057d76cd16c174_9.dds',
    'tex1_146x212_9f9bde0945cd631a_985f853111328ba7_9.dds'
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
    Write-Host "[1] Add additional base pack - Add missing textures to another pack WITHOUT overwriting anything existing (Ex. Fill in missing textures in TPHD with ones from Henriko)."
    Write-Host "[2] Add/Replace additional texture mod - Overwrite one pack's textures with another pack's for a specific set of textures as well as add missing ones that are in the new pack. (Ex: Replace TPHD UI textures with Henriko or Nacho UI textures and add missing ones that come with the new UI's.)"

    while ($true) {
        $choice = Read-Host 'Enter 1 or 2'

        switch ($choice.Trim()) {
            '1' { return 'AppendMode' }
            '2' { return 'ReplaceMode' }
            default { Write-Warning 'Invalid choice. Please enter 1 or 2.' }
        }
    }
}

function Restart-ExplorerIfRequested {
    Write-Host ''
    Write-Host 'Windows File Explorer may keep folder handles open after many files are copied or replaced.'
    Write-Host 'If you cannot rename or delete the merged folder after this script finishes, restarting Explorer usually releases those handles.'
    $confirmation = Read-Host 'Restart File Explorer now? Type YES to restart it, or press Enter to skip'

    if ($confirmation -ne 'YES') {
        Write-Host 'Skipped Explorer restart.'
        return
    }

    try {
        Stop-Process -Name explorer -Force -ErrorAction Stop
        Start-Process explorer.exe
        Write-Host 'File Explorer restarted.'
    }
    catch {
        Write-Warning "Could not restart File Explorer: $($_.Exception.Message)"
    }
}

function Test-PathIsInsideFolder {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Folder
    )

    try {
        $resolvedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
        $resolvedFolder = [System.IO.Path]::GetFullPath($Folder).TrimEnd('\', '/')
        $folderWithSeparator = $resolvedFolder + [System.IO.Path]::DirectorySeparatorChar

        return (
            $resolvedPath.Equals($resolvedFolder, [System.StringComparison]::OrdinalIgnoreCase) -or
            $resolvedPath.StartsWith($folderWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
        )
    }
    catch {
        return $false
    }
}

function Clear-ComObjectReference {
    param(
        [object]$ComObject
    )

    if ($null -eq $ComObject) {
        return
    }

    try {
        if ([System.Runtime.InteropServices.Marshal]::IsComObject($ComObject)) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ComObject) | Out-Null
        }
    }
    catch {
        # COM cleanup is best-effort; merge behavior should not fail if cleanup cannot release a reference.
    }
}

function Get-MatchingExplorerWindowPaths {
    param(
        [Parameter(Mandatory)]
        [string[]]$Folders
    )

    $shell = $null
    $explorerWindows = $null
    $matchingPaths = New-Object System.Collections.Generic.List[string]

    try {
        $shell = New-Object -ComObject Shell.Application
        $explorerWindows = $shell.Windows()

        for ($i = 0; $i -lt $explorerWindows.Count; $i++) {
            $window = $null

            try {
                $window = $explorerWindows.Item($i)
                $folderPath = $window.Document.Folder.Self.Path

                if ([string]::IsNullOrWhiteSpace($folderPath)) {
                    continue
                }

                foreach ($folder in $Folders) {
                    if (Test-PathIsInsideFolder -Path $folderPath -Folder $folder) {
                        if (-not $matchingPaths.Contains($folderPath)) {
                            $matchingPaths.Add($folderPath)
                        }

                        break
                    }
                }
            }
            catch {
                continue
            }
            finally {
                Clear-ComObjectReference -ComObject $window
            }
        }
    }
    catch {
        Write-Warning "Could not inspect File Explorer windows: $($_.Exception.Message)"
    }
    finally {
        Clear-ComObjectReference -ComObject $explorerWindows
        Clear-ComObjectReference -ComObject $shell
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
    }

    return @($matchingPaths)
}

function Close-MatchingExplorerWindows {
    param(
        [Parameter(Mandatory)]
        [string[]]$Folders
    )

    $shell = $null
    $explorerWindows = $null

    try {
        $shell = New-Object -ComObject Shell.Application
        $explorerWindows = $shell.Windows()

        for ($i = $explorerWindows.Count - 1; $i -ge 0; $i--) {
            $window = $null

            try {
                $window = $explorerWindows.Item($i)
                $folderPath = $window.Document.Folder.Self.Path

                if ([string]::IsNullOrWhiteSpace($folderPath)) {
                    continue
                }

                foreach ($folder in $Folders) {
                    if (Test-PathIsInsideFolder -Path $folderPath -Folder $folder) {
                        $window.Quit()
                        Write-Host "Closed Explorer window: $folderPath"
                        break
                    }
                }
            }
            catch {
                continue
            }
            finally {
                Clear-ComObjectReference -ComObject $window
            }
        }
    }
    catch {
        Write-Warning "Could not close File Explorer windows: $($_.Exception.Message)"
    }
    finally {
        Clear-ComObjectReference -ComObject $explorerWindows
        Clear-ComObjectReference -ComObject $shell
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
    }
}

function Close-ExplorerWindowsForFoldersIfRequested {
    param(
        [Parameter(Mandatory)]
        [string[]]$Folders
    )

    $matchingPaths = @(Get-MatchingExplorerWindowPaths -Folders $Folders)

    if ($matchingPaths.Count -eq 0) {
        return
    }

    Write-Host ''
    Write-Host 'The following File Explorer window(s) are open inside the selected destination folder:'
    foreach ($matchingPath in $matchingPaths) {
        Write-Host "  $matchingPath"
    }

    Write-Host ''
    Write-Host 'Closing these windows before the merge can help prevent Windows from locking folders afterward.'
    $confirmation = Read-Host 'Close these File Explorer window(s) now? Type YES to close them, or press Enter to skip'

    if ($confirmation -ne 'YES') {
        Write-Host 'Skipped closing File Explorer windows.'
        return
    }

    Close-MatchingExplorerWindows -Folders $Folders
}

function Get-FixedMapFileName {
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $parts = $FileName -split '_'

    if ($parts.Count -lt 5) {
        return $FileName
    }

    $parts[3] = '$'
    return ($parts -join '_')
}

function Get-NormalizedFileName {
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    if ($FileName -in $knownBadMapFileNames) {
        return Get-FixedMapFileName -FileName $FileName
    }

    return $FileName
}

function Invoke-KnownBadMapFileFixIfRequested {
    param(
        [Parameter(Mandatory)]
        [string]$TargetFolder
    )

    $foundBadMapFiles = @(
        Get-ChildItem -LiteralPath $TargetFolder -File -Recurse |
            Where-Object { $_.Name -in $knownBadMapFileNames }
    )

    if ($foundBadMapFiles.Count -eq 0) {
        return
    }

    $plannedRenames = @(
        foreach ($badMapFile in $foundBadMapFiles) {
            $fixedName = Get-FixedMapFileName -FileName $badMapFile.Name
            $fixedPath = Join-Path -Path $badMapFile.DirectoryName -ChildPath $fixedName

            [PSCustomObject]@{
                Source = $badMapFile
                Destination = $fixedPath
            }
        }
    )

    Write-Host ''
    Write-Host "Found $($plannedRenames.Count) known bad map file(s) that can be renamed:"
    foreach ($plannedRename in $plannedRenames) {
        Write-Host "Current: $($plannedRename.Source.FullName)"
        Write-Host "Fixed:   $($plannedRename.Destination)"
        Write-Host ''
    }

    $confirmation = Read-Host 'Apply known map filename fix? Type YES to rename these file(s), or press Enter to skip'

    if ($confirmation -ne 'YES') {
        Write-Host 'Skipped known map filename fix.'
        return
    }

    $renamed = 0
    $failed = 0

    foreach ($plannedRename in $plannedRenames) {
        try {
            if (Test-Path -LiteralPath $plannedRename.Destination -PathType Leaf) {
                Write-Warning "Cannot rename '$($plannedRename.Source.FullName)' because '$($plannedRename.Destination)' already exists."
                $failed++
                continue
            }

            Rename-Item -LiteralPath $plannedRename.Source.FullName -NewName ([System.IO.Path]::GetFileName($plannedRename.Destination))
            $renamed++
            Write-Host "Renamed: $($plannedRename.Destination)"
        }
        catch {
            $failed++
            Write-Warning "Failed to rename '$($plannedRename.Source.FullName)': $($_.Exception.Message)"
        }
    }

    Write-Host ''
    Write-Host "Map filename fix complete. Renamed: $renamed. Failed: $failed."
}

function Get-ReplacementMatchKey {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File
    )

    $extension = $File.Extension.ToLowerInvariant()
    $normalizedFileName = Get-NormalizedFileName -FileName $File.Name

    if ($extension -eq '.dds' -or $extension -eq '.png') {
        return [System.IO.Path]::GetFileNameWithoutExtension($normalizedFileName)
    }

    return $normalizedFileName
}

function Test-DdsOrPngFile {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File
    )

    $extension = $File.Extension.ToLowerInvariant()
    return ($extension -eq '.dds' -or $extension -eq '.png')
}

function Get-SourceLookupForReplacement {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$SourceFiles
    )

    $sourceGroupsByKey = @{}

    foreach ($sourceFile in $SourceFiles) {
        $matchKey = Get-ReplacementMatchKey -File $sourceFile

        if (-not $sourceGroupsByKey.ContainsKey($matchKey)) {
            $sourceGroupsByKey[$matchKey] = @()
        }

        $sourceGroupsByKey[$matchKey] = @($sourceGroupsByKey[$matchKey] + $sourceFile)
    }

    $sourceByKey = @{}
    foreach ($matchKey in $sourceGroupsByKey.Keys) {
        $sourceGroup = @($sourceGroupsByKey[$matchKey])

        if ($sourceGroup.Count -eq 1) {
            $sourceByKey[$matchKey] = $sourceGroup[0]
        }
        else {
            $sourceByKey[$matchKey] = Select-SourceFile -FileName $matchKey -Files ([System.IO.FileInfo[]]$sourceGroup)
        }
    }

    return $sourceByKey
}

function Get-SourceFileForReplacement {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$TargetFile,

        [Parameter(Mandatory)]
        [hashtable]$SourceLookup
    )

    $matchKey = Get-ReplacementMatchKey -File $TargetFile
    return $SourceLookup[$matchKey]
}

function Test-ReplacementMatchExists {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$TargetFile,

        [Parameter(Mandatory)]
        [hashtable]$SourceLookup
    )

    $matchKey = Get-ReplacementMatchKey -File $TargetFile
    return $SourceLookup.ContainsKey($matchKey)
}

function Get-ReplacementDestinationPath {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$SourceFile,

        [Parameter(Mandatory)]
        [System.IO.FileInfo]$TargetFile
    )

    $sourceIsTexture = Test-DdsOrPngFile -File $SourceFile
    $targetIsTexture = Test-DdsOrPngFile -File $TargetFile

    if ($sourceIsTexture -and $targetIsTexture -and $SourceFile.Extension -ne $TargetFile.Extension) {
        $targetFolder = Split-Path -Path $TargetFile.FullName -Parent
        return Join-Path -Path $targetFolder -ChildPath (Get-NormalizedFileName -FileName $SourceFile.Name)
    }

    return $TargetFile.FullName
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
    $normalizedFileName = Get-NormalizedFileName -FileName $fileName

    if ([string]::IsNullOrWhiteSpace($folderPath)) {
        return $normalizedFileName
    }

    $importedSegments = @(
        $folderPath -split '[\\/]' |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { "$_-Imported" }
    )

    $importedFolderPath = [System.IO.Path]::Combine([string[]]$importedSegments)
    return Join-Path -Path $importedFolderPath -ChildPath $normalizedFileName
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

function Get-ExtrasDestinationPath {
    param(
        [Parameter(Mandatory)]
        [string]$SourceFolder,

        [Parameter(Mandatory)]
        [string]$TargetFolder,

        [Parameter(Mandatory)]
        [System.IO.FileInfo]$SourceFile
    )

    $relativePath = Get-RelativePathFromFolder -BaseFolder $SourceFolder -FullPath $SourceFile.FullName
    $relativeFolder = [System.IO.Path]::GetDirectoryName($relativePath)
    $normalizedFileName = Get-NormalizedFileName -FileName $SourceFile.Name
    $extrasFolder = Join-Path -Path $TargetFolder -ChildPath 'Extras-Imported'

    if ([string]::IsNullOrWhiteSpace($relativeFolder)) {
        return Join-Path -Path $extrasFolder -ChildPath $normalizedFileName
    }

    return Join-Path -Path (Join-Path -Path $extrasFolder -ChildPath $relativeFolder) -ChildPath $normalizedFileName
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

    $sourceByName = Get-SourceLookupForReplacement -SourceFiles $SourceFiles
    $foundMatches = @(
        $TargetFiles | Where-Object { Test-ReplacementMatchExists -TargetFile $_ -SourceLookup $sourceByName }
    )

    $targetMatchKeys = @{}
    foreach ($targetFile in $TargetFiles) {
        $targetMatchKeys[(Get-ReplacementMatchKey -File $targetFile)] = $true
    }

    $plannedExtras = @(
        foreach ($sourceFile in $SourceFiles) {
            $sourceMatchKey = Get-ReplacementMatchKey -File $sourceFile

            if ($targetMatchKeys.ContainsKey($sourceMatchKey)) {
                continue
            }

            $destinationPath = Get-ExtrasDestinationPath -SourceFolder $SourceFolder -TargetFolder $TargetFolder -SourceFile $sourceFile
            New-PlannedCopy -SourceFile $sourceFile -Destination $destinationPath
        }
    )

    if ($foundMatches.Count -eq 0 -and $plannedExtras.Count -eq 0) {
        Write-Host 'No target files matched source file names and no extra source files were found. Nothing to replace or add.'
        return
    }

    if ($foundMatches.Count -gt 0) {
        Write-Host ''
        Write-Host "Found $($foundMatches.Count) target file(s) to replace:"
        foreach ($targetFile in $foundMatches) {
            $sourceFile = Get-SourceFileForReplacement -TargetFile $targetFile -SourceLookup $sourceByName
            $destinationPath = Get-ReplacementDestinationPath -SourceFile $sourceFile -TargetFile $targetFile
            Write-Host "Target: $($targetFile.FullName)"
            Write-Host "Source: $($sourceFile.FullName)"

            if ($destinationPath -ne $targetFile.FullName) {
                Write-Host "Destination: $destinationPath"
                Write-Host 'Same texture with different extension detected. Texture will be replaced with new one with updated extension.'
            }

            Write-Host ''
        }
    }

    if ($plannedExtras.Count -gt 0) {
        Write-Host ''
        Write-Host "Found $($plannedExtras.Count) extra source file(s) to add:"
        foreach ($plannedExtra in $plannedExtras) {
            Write-Host "Source:      $($plannedExtra.Source.FullName)"
            Write-Host "Destination: $($plannedExtra.Destination)"
            Write-Host ''
        }
    }

    $confirmation = Read-Host "Apply $($foundMatches.Count) replacement(s) and add $($plannedExtras.Count) extra file(s)? Type YES to continue"
    if ($confirmation -ne 'YES') {
        Write-Host 'Cancelled. No files were changed.'
        return
    }

    Close-ExplorerWindowsForFoldersIfRequested -Folders @($TargetFolder)

    $replaced = 0
    $added = 0
    $failed = 0

    foreach ($targetFile in $foundMatches) {
        $sourceFile = Get-SourceFileForReplacement -TargetFile $targetFile -SourceLookup $sourceByName
        $destinationPath = Get-ReplacementDestinationPath -SourceFile $sourceFile -TargetFile $targetFile

        try {
            if ($destinationPath -ne $targetFile.FullName) {
                Remove-Item -LiteralPath $targetFile.FullName -Force
            }

            Copy-Item -LiteralPath $sourceFile.FullName -Destination $destinationPath -Force
            $replaced++
            Write-Host "Replaced: $destinationPath"
        }
        catch {
            $failed++
            Write-Warning "Failed to replace '$($targetFile.FullName)': $($_.Exception.Message)"
        }
    }

    foreach ($plannedExtra in $plannedExtras) {
        $destinationFolder = Split-Path -Path $plannedExtra.Destination -Parent

        try {
            if (-not (Test-Path -LiteralPath $destinationFolder -PathType Container)) {
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
            }

            Copy-Item -LiteralPath $plannedExtra.Source.FullName -Destination $plannedExtra.Destination -Force
            $added++
            Write-Host "Added extra: $($plannedExtra.Destination)"
        }
        catch {
            $failed++
            Write-Warning "Failed to add extra '$($plannedExtra.Source.FullName)': $($_.Exception.Message)"
        }
    }

    Write-Host ''
    Write-Host "Done. Replaced: $replaced. Added extras: $added. Failed: $failed."
    Invoke-KnownBadMapFileFixIfRequested -TargetFolder $TargetFolder
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

    $targetTexturesByKey = @{}
    foreach ($targetFile in $TargetFiles) {
        if (-not (Test-DdsOrPngFile -File $targetFile)) {
            continue
        }

        $matchKey = Get-ReplacementMatchKey -File $targetFile

        if (-not $targetTexturesByKey.ContainsKey($matchKey)) {
            $targetTexturesByKey[$matchKey] = @()
        }

        $targetTexturesByKey[$matchKey] = @($targetTexturesByKey[$matchKey] + $targetFile)
    }

    $plannedCopies = @(
        foreach ($sourceFile in $SourceFiles) {
            if ($targetNames.ContainsKey($sourceFile.Name)) {
                continue
            }

            if (Test-DdsOrPngFile -File $sourceFile) {
                $matchKey = Get-ReplacementMatchKey -File $sourceFile

                if ($targetTexturesByKey.ContainsKey($matchKey)) {
                    continue
                }
            }

            $destinationPath = Get-ImportedDestinationPath -SourceFolder $SourceFolder -TargetFolder $TargetFolder -SourceFile $sourceFile
            New-PlannedCopy -SourceFile $sourceFile -Destination $destinationPath
        }
    )

    if ($plannedCopies.Count -eq 0) {
        Write-Host 'No source files were missing from the destination. Nothing to append.'
        return
    }

    Write-Host ''
    Write-Host "Found $($plannedCopies.Count) source file(s) to append:"
    foreach ($plannedCopy in $plannedCopies) {
        Write-Host "Source:      $($plannedCopy.Source.FullName)"
        Write-Host "Destination: $($plannedCopy.Destination)"
        Write-Host ''
    }

    $confirmation = Read-Host "Apply these $($plannedCopies.Count) additons? Type YES to continue"
    if ($confirmation -ne 'YES') {
        Write-Host 'Cancelled. No files were changed.'
        return
    }

    Close-ExplorerWindowsForFoldersIfRequested -Folders @($TargetFolder)

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
            Write-Host "Added: $($plannedCopy.Destination)"
        }
        catch {
            $failed++
            Write-Warning "Failed to add '$($plannedCopy.Source.FullName)': $($_.Exception.Message)"
        }
    }

    Write-Host ''
    Write-Host "Done. Added: $copied. Failed: $failed."
    Invoke-KnownBadMapFileFixIfRequested -TargetFolder $TargetFolder
}

Write-Warning "This script can overwrite files when running in replace mode. Make sure you have backups of any important files before proceeding. The base script was AI generated and then improved upon and tested. Review it yourself to be sure you are comfortable running it. I am not responsible for any damage or loss of data that may occur from running this script."

write-host ''
Write-Host 'You will be prompted for a source and destination folder momentarily. The source should be the folder containing the textures you want to use for replacement. The destination should be the folder containing the textures you want to have replaced. Ex: You want to copy Henriko UI into TPHD pack. Henriko UI folder would be source, TPHD pack would be destination.'

write-host ''
$mergeMode = Read-MergeMode

write-host ''
$sourceFolder = Read-FolderPath -Prompt 'Enter the source folder (Either the GZ2 folder of a pack or a subfolder of it for specific textures.)'
$targetFolder = Read-FolderPath -Prompt 'Enter the destination folder (This can be the parent folder for the target pack as it will only replace files that have the same name as those in the source folder regardless of destination folder or add new textures to folders with -Imported appended.)'

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
    'ReplaceMode' {
        Invoke-ReplaceMatchingFiles -SourceFolder $sourceFolder -TargetFolder $targetFolder -SourceFiles $sourceFiles -TargetFiles $targetFiles
    }
    'AppendMode' {
        Invoke-AppendMissingFiles -SourceFolder $sourceFolder -TargetFolder $targetFolder -SourceFiles $sourceFiles -TargetFiles $targetFiles
    }
}
