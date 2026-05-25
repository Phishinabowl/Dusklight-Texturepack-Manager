# Dusklight Community Texture Pack Manager

Mod tool for merging and creating texture packs for the Dusklight port of *The Legend of Zelda: Twilight Princess*.

This project is currently focused on building a core PowerShell-based management script in preparation to create a better GUI based version later. This script currently supports adding, merging and patching new and existing texture packs to create one finalized texture pack that's a combination of many others in a properly formatted way.

## Current Script

The main active script is:

```text
Texturepack-Manager.ps1
```

It currently supports:

- Append mode for adding missing textures (Base packs using Henriko's pack to fill in textures that TPHD doesn't have but Henriko does)
- Append+Replace mode for replacing matching textures and adding any additional ones (Addon mods like UI, Link's Outfits, Weapons, etc)
- Basic Windows Folder Picker UI functionality by default
- DDS/PNG base-name matching/replacement when detected
- Loose texture files copied into `Extras-Imported` folder
- Known filename fixes/deletions for specific bad map texture names and Ganon fight crash
- Intelligent exclusion for incorrect "4K" text textures on title screen from Henriko 1080p pack during import
- Optional closing of File Explorer windows open inside the destination folder before applying changes (good for preventing accidental file/folder locking issues due to overwrites)
- Preview and explicit `YES` confirmation before file operations
- Proper error catching/handling for clean exits/re-prompts where needed
- Advanced user terminal switches for running script in more efficient way

## How-To Use:
### How-To Video:
- Note: Launching script has been simplified now so the complicated part Jordan shows at first with manually typing commands has been replaced with a one-click launcher
- There's a video by community member TheeJordanAvery which goes over texture and model replacement both manually and using this script. I'll be making a video later myself going over the script itself in detail specifically but for now, huge thanks to Jordan for making a how-to so quickly: https://www.youtube.com/watch?v=QCxksUVozhA

### TL:DR
- Download/unzip script to whatever folder you want
- Double-click "Run-Texturepack-Manager.bat" to start script
- Follow prompts in script

### Safety Notice
- This script is unsigned (I don't have the resources to get a signing cert myself right now) so by default, it won't run on most PC's as unsigned script execution is disabled. To get around this, the batch launcher TEMPORARILY allows unsigned scripts for the current powershell window/session when it runs. This will only be for THIS session, you're not lowering security on your PC permanently with this.

### Script Execution
- Script will first prompt for mode. Select from 3 available options:
  - Add/Append Mode [1] - Add additional base packs in non-destructive way
  - Replace Mode [2] - Add additional addon mod in add+replace way that overwrites existing textures that match and adds any that aren't already present
  - Patch Mode [3] - Used for only applying known pack fixes to existing packs. Useful for people with exsiting packs to fix known bugs
- Source Folder: Folder where source pack is, as of now, best practice is to choose GZ2 folder of pack if it has one
- Destination Folder: Folder where destination pack is, as of now, best practice is to choose GZ2 folder of pack if it has one
- Script will check if you have open file explorer window in destination folder location. If so, you'll be prompted by script to have it auto-close that window. This is recommended if it detects it as open explorer windows can cause unintended file/folder locks during overwrite operations for replace mode
- Choosing same source and destination folders will cause re-prompt to easily correct
- Script will then scan both source and destination folders recursively and show preview of all intended texture adds/replacements. If you accept, type "yes" and hit enter
- Script will compile and then run detection for known pack bugs to optionally apply fixes. If bug fixes detected, type "yes" at each prompt and hit enter
- Final pack will be in whatever destination folder you chose. Just move to texture_replacements folder and you should be all set

### Advanced User Terminal Switches
- The following switches are intended for advanced-user use to make testing easier or just speed up using the script
  - -noUI: Supress all Windows Folder Picker dialogs and fallback to terminal input for all selections/path entry
  - -Mode: Pass in mode parameter directly to script. Supports 1, 2, 3 and common used alternatives (add/replace/patch, etc. Check script for exact aliases)
  - -Source: Pass in source folder parameter directly to script. Folder path must be contained in quotes
  - -Destination: Pass in destination folder parameter directly to script. Folder path must be contained in quotes
 
## Project Status

This tool is still in early stages/dev. The script works in it's current form and it works well, but the larger pack-manager design is still evolving alongside Dusklight itself. If you want to help, or want full status, read [CONTRIBUTING.md](CONTRIBUTING.md) first. It outlines the full status, milestones, and submission expectations/requirements.

## Disclaimer

This tool performs file copy, rename, and replacement operations. Always keep backups of important texture packs before running merge operations.

This project is not affiliated with or endorsed by the Dusklight project, TwilitRealm, Nintendo, or the owners of *The Legend of Zelda: Twilight Princess*.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

You are welcome to share this tool with others. If you redistribute modified versions, please keep the license notice and make it clear what changed.
