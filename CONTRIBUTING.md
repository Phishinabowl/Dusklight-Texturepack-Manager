# Contributing

Welcome to helping the modding community. This is a team effort and the goal is to improve things for everyone, not just one person or team. This pack manager is being built around creating and managing Dusklight texture packs and applying known patches . 

I'd love some help and what helps the most are things like bug reports, edge cases I haven't thought of, documentation help, and code changes (as long as you understand them).

## Project Direction

The current script is the first of multiple  milestones leading toward a full-blown texture pack manager/converter/previewer. Some features may be intentionally kept out of the script if they make more sense in a future GUI workflow as that's the intended direction once core script functionatlity is finished/finalized and intended pack output structures are decided. The biggest thing I'll need help with is when it comes to making the GUI. I'm an enterprise tooling/automation engineer by trade so scripting isn't an issue but I have zero experience with graphic design/UX design. I can come up with decent layouts but have no clue how to implement them outside of basic .NET windows. People that can help make a nice GUI to leverage the backend script/functions will be especially welcome.

## Intended Milestones
### Milestone 1: Core Functionality - 90% Complete - Core functionality present and working as intended. Looking for additional ways to polish/known pack fixes to implement
- Append, Append+Replace, Patch modes
- Logic for adding/replacing/merging files with respect to source and destination folder structure
- PNG/DDS extension detection/replacement logic
- Open File Explorer Window handling
- Add optional known-fix patches:
  - Bad Map filename fix
  - Ganon fight crash fix
- Windows Folder Picker functionality for basic UI
- Script terminal parameters for advanced/dev use
- Intelligent same folder selected behavior/clean exit in advanced-user mode
- Build plan creation and preview presentation to user

### Milestone 2: Output Format Finalization - 25% Complete - Have basics sorted for things like Pack\GZ2\Subfolder tree but need to finalize/standardize multiple other things 
- Two output styles:
  - Manager/Dusklight-friendly prioritized packs (better for Dusklight, horrible for storage size as more packs get added)
  - Storage-friendly merged single pack (better for users that are tight on storage but will break Dusklight's priority system and make individual pack selection inside of Dusk, once they eventually add that, impossible)
- Standardize naming conventions (things like GZ2 for root of pack folder etc)
- Decide priority prefix format (Most likely 010_, 020_, 030_., etc so it fits with Dusklight's current model and what will likely make most sense and leave room to insert additional packs later in-between)
- Define safe folder-name rules to prevent any issues

### Milestone 3: Pack Detection - 0% Complete - This shouldn't be too hard but just will require careful logic in the script to account for all edge cases
- Detect whether selected pack has a GZ2 folder or not, if it's the root, if it's not, what is, etc
- Loose file handling (already puts loose textures into Extras-Imported. Might just stick with that)
- Make sure to be able to handle packs with no GZ2 folder
- Prompt user if all layout detection fails (should try to avoid this at all costs unless we want prompt for friendly pack names that users can define to make their in-game pack list more organized)

### Milestone 4: Build Planning Improvements - 75% Complete - This is mostly just improvements to what I already do with showing previews to the user etc. Will be more relevant once multi-pack support is added so needs to be 100% here before moving on
- Present detection summary and show intended layout to user before pack compliation
- Shift toward a “plan full pack structure first, execute once finalized” flow (pretty much already is but ensure it's ready to account for Milestone 5 and adding multiple packs at once in one run
- Track all additions, replacements, skipped files, conflicts, and patches in one place for easy summary collection/presentation
- Improve logic where needed to make it easier to reuse in the future GUI version

### Milestone 5: Multi-Pack Compilation - 0% Complete
- Support adding multiple packs at the same time (both base additions and replacements)
- Track base packs vs addon packs
- Apply pack order/priority rules
- Compile either:
  - Manager/Dusklight-friendly prioritized output version
  - Storage-friendly merged output version
 - Add ability to choose whether it outputs directly to texture_replcaements or a given location
 - Prompt user if they want to overwrite everything that's currently in texture_replacements if they chose to put compiled pack there

### Milestone 6: GUI - 1% Complete - I managed to leverage the built-in Windows Folder Picker dialog box...horray for me...lol
- Visual pack list w/ priority re-ordering
- Base/addon pack labels/auto-detected and custom names
- Up/down priority buttons
- Compiled pack type (manager vs. storage) selection
- Compiled pack output location selection
- Preview panel (for final pack structure preview)
- Compile/install buttons
- Eventually texture preview/conversion support (this will be significantly harder and will need to leverage 3rd party conversion tools. Free ones exist that I've already looked into but this would be a "nice to have" feature but really not needed. The converter is more important than an in-app previewer so final compliation could potentially convert any PNG's to DDS's at compliation time)

## Before Opening A PR

Please try to shoot for small PR's that target one specific issue. I don't want to have to read a million changes to a ton of different functions/features all at once and it makes organization/tracking a mess. All code submissions are expected to be fully commented so people can follow the script even at a high level just reading through it.

For code changes:
- List what problem(s) you're fixing
- Tell me/us how you tested it
- Don't remove existing safety prompts/guardrails unless you explain why and it's absolutely necessary (should almost never happen)
- Use proper error catching/handling. If I/we can break your proposed change in 5 minutes and things exit sloppily, you didn't test enough

## Contribution License

By submitting a pull request or other contribution to this repository, you agree that your contribution may be included in this project under the MIT License.

You retain copyright to your own contributions, but you grant the project permission to use, modify, distribute, and sublicense those contributions as part of the project under the MIT License.

## AI-Generated Contributions

It's 2026, people use AI. That being said, if you're using it, it should be to help validate your thinking and be a sounding board for ideas, explainng things so you understand more completely, or debugging. Think "unpaid, 24/7 reserach assistant". Do NOT expect submissions that are clearly fully AI generated to be accepted. Contributors are expected to understand, review, and test anything they get from any AI and they should be ready to be questioned on it and be able to explain what the code is doing without saying "uhhhh I have no clue..."
