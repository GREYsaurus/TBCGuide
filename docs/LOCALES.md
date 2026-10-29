# Client languages

TBCGuide reads item tooltips for a few things the item APIs do not report: the binding of an item copy, use/equip/proc effects, set bonuses and red "can't use" lines. All of that tooltip reading is in `TBCGuide/Core/TooltipText.lua`.

## Order of trust

1. **Structured data:** `C_Container.GetContainerItemInfo().isBound` for a bag copy, `GetItemInfo` bind type, `GetItemStats` for stats. Language independent.
2. **The client's own strings:** `ITEM_SOULBOUND`, `ITEM_BIND_ON_EQUIP` / `_PICKUP` / `_USE`, `ITEM_SPELL_TRIGGER_ONUSE` / `ONEQUIP` / `ONPROC`, `ITEM_SET_BONUS(_GRAY)`. The client builds its tooltips from these globals, so they match in every language. Binding lines must match the whole line.
3. **English patterns, English clients only (enUS, enGB):** which "Equip:" lines are plain stats, and "+N school damage" amounts.
4. **Other languages, by counting:** `GetItemStats` lists the stats the client shows as "Equip:" lines. More "Equip:" lines than those stats means an effect TBCGuide cannot score. The item is then marked as having an effect it could not read, which makes the comparison *uncertain*. Uncertain upgrades are never equipped automatically and get no arrow.

**Binding is never guessed.** If no binding line matches, the binding stays unknown, and an unknown binding blocks automatic equipping.

## Coverage

| Feature | enUS / enGB | deDE, frFR, esES, esMX, ruRU, koKR, zhCN, zhTW, ptBR, itIT |
|---|---|---|
| Soulbound / BoE / BoP / BoU | client strings | client strings |
| Use, chance-on-hit, set-bonus effects | client strings | client strings |
| Equip stat lines vs. equip effects | English patterns | counted against `GetItemStats` (conservative) |
| School damage ("+N Shadow damage") | parsed | not parsed; counted as an effect it could not read (conservative) |
| Red requirement lines | colour, any language | colour, any language |
| Number formats (1,234 / 1.234) | handled | handled |
| Guide text, quest names | English | English |

Tests (`tests/test_locales_bags_setup.lua`) cover English, German and French strings: bound and unbound BoE, similar text that must not match, missing tooltips, an unknown locale and number formats. They use the strings as those clients define them; no non-English client was run.

**Limitation:** on non-English clients, school-damage gear (for example Shadow-damage items for a Shadow Priest) is uncertain and is not equipped automatically. You can still equip it yourself.
