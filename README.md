# Dusklight Texture Pack Merge Tools

Utilities for preparing and merging texture packs for the Dusklight port of *The Legend of Zelda: Twilight Princess*.

This project is currently focused on a PowerShell-based merge script while the broader texture pack manager concept is being designed. The long-term goal is to make texture pack preparation safer, easier to understand, and friendlier to Dusklight's current and future texture replacement workflows.

## Current Script

The main active script is:

```text
Replace-SameNamedFiles-WithExtras.ps1
```

It currently supports:

- Append mode for adding missing textures.
- Replace mode for replacing matching textures.
- DDS/PNG base-name matching where appropriate.
- Replace-mode extras copied into `Extras-Imported`.
- Known filename fixes for specific bad map texture names.
- Optional closing of File Explorer windows open inside the destination folder before applying changes.
- Preview and explicit `YES` confirmation before file operations.

The older script is kept for reference:

```text
Replace-SameNamedFiles.ps1
```

## Project Status

This is an early-stage community tool. The script works for current workflows, but the larger pack-manager design is still evolving alongside Dusklight itself.

Planned future work may include:

- Safer output folder/build structure handling.
- Manager-friendly prioritized pack output.
- Storage-friendly merged pack output.
- Better pack layout detection.
- GUI-based pack management.
- Texture preview and conversion support.

## Contributing

Issues, testing notes, edge cases, and pull requests are welcome. If you are contributing code, please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## Disclaimer

This tool performs file copy, rename, and replacement operations. Always keep backups of important texture packs before running merge operations.

This project is not affiliated with or endorsed by the Dusklight project, TwilitRealm, Nintendo, or the owners of *The Legend of Zelda: Twilight Princess*.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

You are welcome to share this tool with others. If you redistribute modified versions, please keep the license notice and make it clear what changed.
