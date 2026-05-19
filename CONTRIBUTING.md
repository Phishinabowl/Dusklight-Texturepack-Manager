# Contributing

Welcome to helping the modding community. This is a team effort and the goal is to improve things for everyone, not just one person or team. This pack manager is being built around creating and managing Dusklight texture packs and applying known patches . 

I'd love the help and what helps the most are things like bug reports, edge cases I haven't thought of, documentation help, and code changes (as long as you understand them).

## Project Direction

The current script is the first of multiple  milestones leading toward a full-blown texture pack manager/converter/previewer. Some features may be intentionally kept out of the script if they make more sense in a future GUI workflow as that's the intended direction once core script functionatlity is finished/finalized and intended pack output structures are decided. The biggest thing I'll need help with is when it comes to making the GUI. I'm an enterprise tooling/automation engineer by trade so scripting isn't an issue but I have zero experience with graphic design/UX design. I can come up with decent layouts but have no clue how to implement them outside of basic .NET windows. People that can helpe make a nice GUI to leverage the backend script/functions will be especially welcome.

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

It's 2026, people use AI. That being said, if you're using it, it should be to help validate your thinking and be a sounding board for ideas/debugging. Do NOT expect submissions that are clearly fully AI generated to be accepted. Contributors are expected to understand, review, and test anything they get from any AI and they should be ready to be questioned on it and be able to explain what the code is doing without saying "uhhhh I have no clue..."
