# TBCGuide

A **free** leveling guide and talent add-on for **World of Warcraft: The Burning Crusade Classic** (Anniversary realms, client 2.5.6, interface `20506`).

Everything is in the base install. There are no guide packs, accounts, subscriptions or downloads after installing.

- **Level 1-70 guides for every race/class combination.** There are 54 guides with 4,281 steps and 1,314 distinct quests, covering all 10 racial starts (including Draenei and Blood Elf), 32 Azeroth zones and all 7 Outland leveling zones. Every one of the 52 race/class combinations has a validated route from 1 to 70.
- **Bundled TBC quest database**, derived from QuestieDB: 6,648 quests, 7,302 NPCs, 1,325 objects and 3,919 items. It provides quest names, objectives, prerequisites, givers and coordinates. **You do not need to install Questie.**
- **Automatic progression** from the quest log, quest-completion flags, level, hearthstone bind location and flight-path messages. **Every step can also be completed or skipped by hand**, so you never get stuck.
- **Navigation**: a built-in arrow, a world-map pin, and optional TomTom waypoints.
- **Talent guide and calculator** for all nine classes. Trees come straight from the 2.5.6 client data. There are 21 builds (leveling and level 70: tank, healer and DPS), each checked point by point for tier gating, prerequisites and the 61-point budget. You can compare a build with your real talents (your own class) or with a simulated allocation (any class).
- **Class leveling tips** for every class.

> **Status: untested in the game client.** Everything was built and checked with offline tools: Lua 5.1 syntax and API lint, the guide compiler and the content validator. Nobody has loaded it in WoW yet. Expect some API, UI and route issues on first run, and please report them. See `docs/KNOWN_LIMITATIONS.md`.

## Install

1. **Download.** Use either:
   - the latest **Release** (right-hand side of this page): download `TBCGuide-<version>.zip`. The zip already contains the right folder; or
   - the green **Code** button, then **Download ZIP**. This downloads the whole repository.
2. **Close World of Warcraft.**
3. **Copy the `TBCGuide` folder** (the one containing `TBCGuide.toc`) into your AddOns folder:
   ```
   World of Warcraft\_anniversary_\Interface\AddOns\TBCGuide\TBCGuide.toc
   ```
   - If you used *Download ZIP*, extract it first. The `TBCGuide` folder is inside `TBCGuide-main`. Copy only that inner folder, **not** `TBCGuide-main` itself, or the game will not find the add-on.
   - The folder must be named exactly `TBCGuide`.
   - Create `Interface\AddOns` if it does not exist yet.
4. **Start the game.** On the character screen, click **AddOns** and make sure **TBCGuide** is ticked. If it shows as out of date, tick **Load out of date AddOns**.
5. **Log in.** The guide window opens with a guide picked for your character. Type `/tbcg help` for commands.

Optional: install [TomTom](https://www.curseforge.com/wow/addons/tomtom) to get its waypoint arrow as well.

**Updating:** delete the old `Interface\AddOns\TBCGuide` folder and copy in the new one. Your progress is kept, because it is saved under `WTF\`.

**Troubleshooting:** if the add-on does not appear in the list, check that the path ends in `AddOns\TBCGuide\TBCGuide.toc` with no extra folder level in between. If you see Lua errors, run `/tbcg debug errors` and open an issue with the output.

More detail, including building from source, is in [INSTALL.md](INSTALL.md).

## Use

| Command | Action |
|---|---|
| `/tbcg` | Show/hide the guide window |
| `/tbcg guide` | Guide browser (filter by faction, race, class, level and chapter; load or restart guides) |
| `/tbcg talents` | Talent guide and calculator |
| `/tbcg next` / `/tbcg prev` / `/tbcg skip` | Manual step control |
| `/tbcg auto` | Load the recommended guide for this character |
| `/tbcg nextguide` | Load the next guide in your route |
| `/tbcg reset` | Reset the current guide's progress |
| `/tbcg class` | Class leveling tips |
| `/tbcg options` | Settings |
| `/tbcg debug` / `debug api` / `debug talents` / `debug quest <id>` | Diagnostics |
| `/tbcg help` | All commands |

In the guide window, **left-click** a step to mark it done and **right-click** it to skip it.

## Licence

TBCGuide is free software under the **GNU General Public License v3.0 only** (`LICENSE`, `COPYING`). The full corresponding source is this repository; the release also ships a `-source.zip`. It includes the guide sources (`guides-src/`), the build tools (`tools/`), tests and docs, so you can inspect, modify, rebuild and redistribute it.

Bundled third-party data and its licensing situation are described in [NOTICE.md](NOTICE.md) and [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md). In particular, read what the QuestieDB upstream says about historic contributions.

## For developers

- [docs/DEVELOPER.md](docs/DEVELOPER.md): architecture and build commands
- [docs/GUIDE_FORMAT.md](docs/GUIDE_FORMAT.md): how to write guides
- [docs/DATA_PIPELINE.md](docs/DATA_PIPELINE.md): refreshing the bundled database and talent data
- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md): target client and in-game test checklist
- [docs/COVERAGE_REPORT.md](docs/COVERAGE_REPORT.md): generated coverage report
- [docs/RESEARCH.md](docs/RESEARCH.md): research findings and decisions
