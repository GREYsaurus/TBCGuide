# Research findings and decisions (Phase 1)

Recorded 2026-10-28.

## Target client

- TBC Classic **Anniversary** realms are the live TBC Classic product in 2026: pre-patch 2026-01-13, launch 2026-02-05, Phase 2 on 2026-05-14.
- wago.tools lists product `wow_anniversary` at **2.5.6.70577**.
- Questie's latest release (`bundle/v12.3.1+v1.0.9`, 2026-10-26) ships flavor `bcc` at **interface 20506**. RestedXP's `RXPGuides_TBC.toc` also declares 20506.
- **Decision:** target interface 20506 / build 2.5.6, configured in `Config/Target.lua`.

## RestedXP (RXPGuides)

- Repository reviewed: layout (`Guides/`, `GuideLoader.lua`, `QuestLog.lua`, `map.lua`, `Talents.lua`, `RXPGuides_TBC.toc`) and feature set (step lists, auto-progression, waypoints, talents, guide selection).
- **Licence: CC BY-NC-SA 4.0.** This is non-commercial and share-alike, so it is incompatible with redistributing under GPLv3.
- **Decision:** use it for design ideas only. No code, guide text, routes or assets were copied. TBCGuide's guide format, engine and routes are independent.

## Icy Veins

- Proprietary site. **Decision:** no text copied. Talent builds are the project's own, checked against client data.

## Questie / QuestieDB

- QuestieDB is now a separate repository with flavor data (`data/TBC/*.lua`), corrections and a generator that "bakes" data into TOC metadata (CBOR) for runtime use.
- The Questie release bundle includes a prebuilt `QuestieDB_TBC.toc` (21 MB). Its baked format needs QuestieDB's runtime reader and decompression.
- **Decision:** read the plain-Lua **source** data at the commit the bundle was built from (`producerCommit 7901fee...`). Transform it offline into compact Lua tables that load directly, and keep an adapter API (`Database/QuestDB.lua`) independent of Questie's runtime.
- **Licence:** see THIRD_PARTY_LICENSES.md. The upstream team permits copying under GPLv3 but notes that not all historic contributors have consented. The project redistributes under those offered terms, documents the residual risk, and keeps the data separable.

## Client tables

- wago.tools provides CSV exports of the client's DB2 tables for build 2.5.6.70577.
- **Decision:** generate talent trees (tier, column, ranks, prerequisites, spell ids) and the legal race/class list from these. Talent builds are validated mechanically, and race/class legality comes from the client's own `CharBaseInfo` table (52 combinations).

## Tooling constraints in this environment

- No Lua interpreter, Python, Node or git was installed. Fetching a portable Lua binary was blocked by the environment's safety policy.
- **Decision:** write the build tooling in C# compiled by Windows PowerShell 5.1: a Lua literal reader, a Lua 5.1 parser/linter, the importers, the guide compiler and the validator. The Lua runtime test harness is written but unexecuted.

## Open questions

1. Is `_anniversary_` the AddOns folder name for every install? (INSTALL.md hedges.)
2. Which options API does 2.5.6 expose: new Settings, legacy InterfaceOptions, or both? (Both are handled.)
3. Does `GetTalentInfo` on 2.5.6 index talents in the same tree order as `TalentTab.OrderIndex`? (Mapped by tier/column; `/tbcg debug talents` checks.)
4. ~~Copyright holder~~ - resolved: GREYsaurus (https://github.com/GREYsaurus), confirmed by the project owner.
