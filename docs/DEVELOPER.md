# Developer guide

## Layout

```
TBCGuide/                       the add-on (this folder is what players install)
  TBCGuide.toc                  manifest (interface 20506) - load order lives here
  Core/Init.lua                 namespace, event bus, throttling, helpers
  Config/Target.lua             EVERYTHING client/ruleset specific (interface, level cap, talent points, XP rate, integrations)
  Compat/Compat.lua             every game API call goes through here; missing APIs degrade, never error
  Core/SavedVars.lua            TBCGuideDB (account) / TBCGuideCharDB (character), defaults, validation
  Database/Schema.lua           field layout of the bundled data
  Database/QuestieTBC/*.lua     GENERATED quest/NPC/object/item/zone data (QuestieDB-derived)
  Database/RaceClass.lua        GENERATED race/class table
  Database/Overrides.lua        project-owned data corrections (client/realm specific)
  Database/QuestDB.lua          query API: GetQuestByID, GetNPCPosition, IsQuestAvailable, ...
  Guides/Registry.lua           guide registration, filtering, route resolution
  Guides/Compiled/              GENERATED guides + Guides.xml (load list)
  Classes/ClassAdvice.lua       class leveling tips (unverified text)
  Talents/Data/TalentTrees.lua  GENERATED talent trees from client tables
  Talents/Talents.lua           build expansion/validation, live talent reading (by tier/column)
  Talents/Builds/*.lua          talent builds per class + Builds.xml
  Core/QuestTracker.lua         live quest log + turn-in tracking
  Core/QuestAuto.lua            quest accept / turn-in automation (escort + reward-choice rules)
  Core/Vendor.lua               junk selling at vendors (+ protection list)
  Core/Orphans.lua              quests in the log the route will never turn in; confirmed abandon
  Database/EscortQuests.lua     curated never-auto-accept list (one of several escort signals)
  Core/Selector.lua             recommended guide / route for a character
  Core/Engine.lua               step state machine, auto/manual progression
  Core/StepText.lua             step text + navigation target per step
  Core/Navigation.lua           arrow, world-map pin, TomTom
  UI/*.lua                      main window, browser, talent calculator, options, automation options, orphan window
  Core/Commands.lua             /tbcg
  Core/Diagnostics.lua          /tbcg debug ...
  Core/Boot.lua                 ADDON_LOADED / PLAYER_LOGIN sequence (each stage pcall-guarded)
guides-src/                     guide SOURCES (edit these)
tools/                          build tooling (PowerShell + C#), allowlist, upstream pins
tests/                          Lua test harness with WoW API mocks (needs a Lua 5.1 interpreter)
docs/                           documentation; docs/generated/ holds build logs
```

## Build commands

```bash
powershell -ExecutionPolicy Bypass -File tools/build.ps1 all
```

`all` runs `guides`, `lint`, `validate`, `routes`, `report` and `package`. `routes` is the route optimization model (see docs/ROUTE_OPTIMIZATION.md); it fails the build on impossible quest orders or quest-log overflow. Individual commands are documented at the top of `tools/build.ps1`. `zonequests "<Zone>" <Faction>` is an authoring aid that lists every quest in a zone from the bundled data.

## The lint gate

`tools/build.ps1 lint` parses every shipped `.lua` file as Lua 5.1 and fails on:

- syntax errors;
- assignments to undeclared globals (a missing `local`);
- reads of globals that are neither Lua builtins, our own globals, nor listed in `tools/wow_api_allowlist.txt`.

The allowlist is deliberately small and annotated. **Adding a WoW API is a reviewed decision**, which is how we keep Retail-only APIs out. If an API may be missing on some Classic build, wrap it in `Compat.lua` and nil-check it.

## Principles

- **Never block the player.** Every step can be marked done or skipped by hand. Auto-completion uses only reliable signals.
- **Database optional at runtime.** Compiled guides carry their own quest ids, NPC names and coordinates. `QuestDB.lua` returns nil or empty when records are missing.
- **No fabricated data.** Quest ids, NPCs and coordinates come from the database or are explicitly marked unverified (`v=0`).
- **Client specifics live in `Config/Target.lua` and `Compat/Compat.lua`.**

## Tests

- `tests/run_tests.lua` is a headless harness. It loads the add-on files in TOC order against mock WoW APIs (`tests/mock_wow.lua`) and exercises boot, guide loading, step progression, manual controls, saved-variable recovery and the talent engine. Run it with a Lua 5.1 interpreter:
  ```bash
  lua5.1 tests/run_tests.lua
  ```
  It now runs and passes (284 checks in 0.2.0). Any Lua 5.1 interpreter works. On Windows without one, the Lua 5.1 runtime bundled in Python's `lupa` package works too:
  ```bash
  python -m pip install lupa
  python -c "import lupa.lua51 as l; l.LuaRuntime().execute('dofile(\"tests/run_tests.lua\")')"
  ```
- `tests/test_automation.lua` covers junk selling, quest acceptance and turn-in (escort and reward rules), orphaned quests, the speed-route option and setting repair.
- `tools/build.ps1 lint/validate` are the checks that **were** run (see `docs/COVERAGE_REPORT.md`).
