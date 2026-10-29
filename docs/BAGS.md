# Bag add-on support

The BoE upgrade arrow and the junk coin (Tips → Automatic Upgrades / Inventory) work in the default bags and in three bag add-ons. One adapter layer (`TBCGuide/UI/BagAdapters.lua`) tells `UI/GearMarkers.lua` which buttons show the player's bags and which bag/slot each one shows. Evaluation, junk rules, drawing and tooltips stay in one place, so every bag add-on shows the same marks as the default bags.

## Compatibility

| Bag add-on | Version read | How TBCGuide attaches | Arrow | Junk | Tooltip lines | Tested in game |
|---|---|---|---|---|---|---|
| Default bags | client 2.5.6 | `ContainerFrame1..13`, bags 0-4 only | yes | yes | yes | yes (0.7.0) |
| Bagnon | 12.1.7 (TOC 20506) | post-hook on `BagBrother.ContainerItem:Update` (`hooksecurefunc`) | yes | yes | yes | **no** |
| AdiBags | 1.10.29 (TBC TOC says **20504**) | an AdiBags module listening to `AdiBags_UpdateButton` | yes | yes | yes | **no** |
| Baganator | 839 (TOC lists 20506) | public API: `RegisterCornerWidget` (arrow), `RegisterJunkPlugin` (junk) | yes (Baganator draws it) | Baganator's own junk coin, fed by TBCGuide's junk rules (choose "TBCGuide" in its junk setting) | yes | **no** |
| Other bag add-ons | - | none | no | no | no | - |

Each version was read from its source: Bagnon from the installed copy, AdiBags and Baganator from the release archives. A different version may rename what the adapter uses. If so, the adapter does nothing (every entry point is checked before use) and the default bags keep working.

## Rules every adapter follows

- **Player bags only (0-4).** Bank, reagent bank, guild bank and other characters' cached bags never get a mark: Bagnon's `IsCached()`, AdiBags' `IsBank()`, and Baganator's bag id outside 0-4 all resolve to "no slot".
- **Item check.** A mark is drawn only while the slot still holds the item it was computed for, so a recycled button or a moved item never keeps a stale arrow.
- **Optional.** Nothing loads or errors when a bag add-on is missing. Adapters retry on `ADDON_LOADED`, so load order does not matter.
- **Hooks are additive.** Only post-hooks and the add-ons' own plugin APIs are used; nothing of theirs is replaced.
- **No new automation.** The markers inform. The BoE prohibition stands: unbound Bind-on-Equip items are never equipped automatically.

## Known issues

- **AdiBags** 1.10.29 lists interface 20504 for TBC; on a 20506 client it may need "Load out of date AddOns".
- **Baganator** shows the arrow in a corner chosen in its own Icons settings (default top-left). Its junk coin appears only if "TBCGuide" is picked as its junk source.
- None of the three has been run in the game with TBCGuide yet. In-game checklist: `docs/COMPATIBILITY.md` → Bag add-ons.

Tests: `tests/test_locales_bags_setup.lua` (stand-ins with the same entry points).
