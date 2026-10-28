# Data pipeline: refreshing the bundled database and talent data

Players never run any of this. The released add-on already contains the generated files.

```
tools/upstream.json  --fetch-->  .cache/  --import-questie-->  TBCGuide/Database/QuestieTBC/*.lua
                                          --import-client--->  TBCGuide/Talents/Data/TalentTrees.lua
                                                               TBCGuide/Database/RaceClass.lua
guides-src/*.guide  --guides (uses the generated DB)-->  TBCGuide/Guides/Compiled/*.lua
```

## 1. Pin the upstream version

Edit `tools/upstream.json`:

- `questiedb.commit`: a specific QuestieDB commit or release, never `master`/`latest`. To find the commit Questie shipped, open the `release.json` asset of a Questie release (`bundle/vX+vY`) and read `questiedb.producerCommit`.
- `questiedb.archiveSha256`: SHA-256 of `https://codeload.github.com/Questie/QuestieDB/zip/<commit>`. The build refuses a mismatched archive. When you change the commit, download the zip once, run `Get-FileHash`, and record the value.
- `clientTables.build`: the client build to export talent and race tables from (see https://wago.tools/api/builds, product `wow_anniversary`).

## 2. Fetch and verify

```bash
powershell -ExecutionPolicy Bypass -File tools/build.ps1 fetch
```

This downloads the pinned QuestieDB source archive into `.cache/`, verifies its SHA-256, extracts only the files listed in `upstream.json` (missing files are an error), and downloads the client CSV tables.

## 3. Import

```bash
powershell -ExecutionPolicy Bypass -File tools/build.ps1 import-questie
powershell -ExecutionPolicy Bypass -File tools/build.ps1 import-client
```

`import-questie`:

- parses the upstream Lua data with a literal-only reader. **No upstream code is executed.**
- applies `tbcQuestFixes.lua` with a restricted static evaluator. It accepts literals, enum constants, `l10n("...")` and `+`/`-`; anything runtime-dependent is skipped and logged.
- writes the trimmed data and `docs/generated/questie-import.log`, which has record counts, applied and skipped corrections, and dangling references.

`import-client` writes the talent trees (positions, ranks, prerequisites and spell ids per rank) and the legal race/class table.

## 4. Re-validate everything

```bash
powershell -ExecutionPolicy Bypass -File tools/build.ps1 all
```

If quests changed upstream, the guide compiler reports any guide step whose quest no longer exists, changed name or changed faction.

## 5. Licence housekeeping when updating

- Copy the upstream `LICENSE.md` and `PROVENANCE.md` into `TBCGuide/Database/QuestieTBC/UPSTREAM_*.md` again. `fetch` puts them in `.cache/upstream/questiedb/`.
- Update the commit, version and checksum in `THIRD_PARTY_LICENSES.md` and `NOTICE.md`.
- Re-read the upstream licence for changes before releasing.

## Data provenance of each generated file

| File | Source | Generator |
|---|---|---|
| `Database/QuestieTBC/Quests.lua` | QuestieDB `data/TBC/tbcQuestDB.lua` + `tbcQuestFixes.lua` | `QuestieImport.cs`, `QuestieCorrections.cs` |
| `Database/QuestieTBC/Npcs.lua`, `Objects.lua`, `Items.lua` | QuestieDB TBC entity tables | `QuestieImport.cs` |
| `Database/QuestieTBC/Zones.lua` | QuestieDB `support/Zones/*` | `QuestieImport.cs` |
| `Talents/Data/TalentTrees.lua` | client DB2 `Talent`, `TalentTab`, `SpellName` | `ClientTables.cs` |
| `Database/RaceClass.lua` | client DB2 `CharBaseInfo`, `ChrRaces` | `ClientTables.cs` |
| `Guides/Compiled/*.lua` | `guides-src/*.guide` + the files above | `GuideCompiler.cs` |
