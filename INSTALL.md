# Installing TBCGuide

## Players

1. Download `TBCGuide-<version>.zip` from the GitHub **Releases** page (https://github.com/GREYsaurus/TBCGuide/releases), or build it yourself (it lands in `dist/`). If you use GitHub's *Code > Download ZIP* instead, copy only the inner `TBCGuide` folder out of `TBCGuide-main`.
2. Close World of Warcraft.
3. Extract the zip so that this folder exists:
   ```
   World of Warcraft\_anniversary_\Interface\AddOns\TBCGuide\TBCGuide.toc
   ```
   The TBC Anniversary client folder is `_anniversary_`. If your install uses a different folder name (for example `_classic_`), use that client's `Interface\AddOns`.
4. Start the game. On the character screen, open **AddOns** and make sure **TBCGuide** is enabled. If the client says it is "out of date", tick *Load out of date AddOns*.
5. Log in. The guide window opens with a recommended guide. Type `/tbcg help` for commands.

Optional: install **TomTom** if you want its waypoint arrow as well as the built-in one.

### Upgrading

Delete the old `Interface\AddOns\TBCGuide` folder before extracting the new one. Your progress is stored separately in `WTF\Account\<account>\SavedVariables\TBCGuide.lua` and `...\<realm>\<character>\SavedVariables\TBCGuide.lua`, so it survives upgrades.

### Uninstalling

Delete `Interface\AddOns\TBCGuide`. You can also delete the `TBCGuide.lua` files under `WTF` to remove saved progress.

## Building from source (Windows)

Requirements: Windows PowerShell 5.1+ (built into Windows 10/11). Nothing else: the build tools are C# compiled on the fly by PowerShell.

```bash
powershell -ExecutionPolicy Bypass -File tools/build.ps1 all
```

This compiles the guides, lints all Lua, validates the content, writes `docs/COVERAGE_REPORT.md` and produces:

- `dist/TBCGuide-<version>.zip`: the installable add-on (licence and notices included)
- `dist/TBCGuide-<version>-source.zip`: the corresponding source (guide sources, tools, tests, docs)

The data import steps (`fetch`, `import-questie`, `import-client`) only need to run when refreshing the upstream data. See `docs/DATA_PIPELINE.md`.
