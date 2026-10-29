# Auction house: Upgrades tab

TBCGuide adds an **Upgrades** tab to the auction house window. It lists gear for sale that is an upgrade for your chosen spec profile, grouped by equipment slot. It is TBCGuide's own feature and is unrelated to the add-on called *Auctioneer*. It works next to such add-ons and needs none.

Turn it on or off with **Tips → Item Upgrade → Enable Auctioneer** (on by default). When it is off, the tab is hidden and the native auction window is untouched.

**Not yet tested in the game client.** Offline checks pass, including scan, cache, filter and interruption tests against a mock of the client API. The in-game checklist is at the end.

## Scanning

Scans start only when you press **Scan auction house** on the Upgrades tab, with the auction house open.

**Client API:**
- TBC Classic Anniversary has the legacy auction interface: `QueryAuctionItems`, answered by `AUCTION_ITEM_LIST_UPDATE`, 50 listings per page, throttled by `CanSendAuctionQuery()`.
- TBCGuide does not use the `getAll` full scan. Its cooldown and size on a big auction house can disconnect players, and gear needs far less.

**What is scanned:** each page asks for the gear you could use:
- weapons and armor (the class filter; older clients ignore it);
- *usable* by your character;
- uncommon or better;
- required level up to yours.

**Pacing:** a page is sent only when the client allows a query, and the next one after the answer arrives.

**Progress and cancelling:** the status line shows "Scanning page N of M". **Cancel** stops the scan at once.

**Limits:**
- A scan stops after 120 pages (6,000 listings).
- At most 4,000 distinct items are kept per auction house.
- Only the three most recently scanned auction houses are kept.

**Interruptions:** the scan stops, and keeps what it found as **partial** data, when:
- you close the auction house;
- the server doesn't answer a page within 15 seconds;
- you, or another add-on, start a different search. TBCGuide notices any `QueryAuctionItems` call it didn't make and stops, rather than reading someone else's results.

**Pages still loading:** a page whose item details are still loading is read again once, after a short wait.

## What is stored

Saved account-wide in `TBCGuideDB.auctionScans`, per realm and faction:
- the scan time;
- complete or partial, and the number of listings;
- per item, the **cheapest buyout seen**:
  - the price per item, plus the full buyout and stack size;
  - how many listings it was seen in;
  - an item link.

**Item variants:** variants are kept apart by item id and random suffix ("of the Bear" vs "of the Monkey"), so they're scored separately. Copies of the same item are merged.

**Bid-only listings** (no buyout) are counted but never priced.

**Neutral auction houses:** the client doesn't say whether you are at a faction or neutral (goblin) auction house, so both share your faction's data set.

**Prices are observations, not values.** The price shown is the lowest buyout in your last scan. It isn't a market value, and the listing may have sold or expired since. With no scan, the tab says **No scan data**.

**Status line:**
- the scan's age;
- complete or partial;
- **stale** after 2 hours.

## The Upgrades tab

**Scoring:** every stored item is scored with the **same evaluator as automatic upgrades** (`Gear/Upgrade.lua`), using:
- your spec profile;
- class, level and red-tooltip usability checks;
- whole-configuration comparison:
  - a two-hander against main hand + off hand;
  - rings and trinkets against both slots;
  - shields and off-hands never against a held two-hander;
- the same percentage rules.

The two can't disagree.

**Shown by default:** only usable gear that is a certain upgrade, or fills an empty slot.
- **Empty slots** show *Empty slot*, never a percentage.
- **Upgrades with no baseline** show *Upgrade - percentage unavailable*.
- **Uncertain items** (use or chance-on-hit effects, set bonuses, unscored equip effects) are hidden unless you tick **Show uncertain**, and are then marked *uncertain*.

**Each row shows:**
- the item icon and link;
- the required level;
- the price (*each* when it was a stack);
- the estimated spec-score change;
- the equipped item(s) it would replace.

**Filters:**
- slot;
- **Max price (g)**;
- **Min upgrade %**.

**Sorting:** sort by upgrade % or by price within each slot group.

**Updating:** changing your equipment or spec profile re-scores the stored items straight away, **without rescanning**.

**Clicking a row** searches the Browse tab for that item, so you see the live listings. Buying is always your own action through the normal auction window, at whatever the price is now.

**Never automatic:** TBCGuide never bids, buys or cancels anything. Bind-on-Equip items are never equipped automatically after you buy them either; automatic upgrades only mark them.

## Client functions used

`QueryAuctionItems`, `CanSendAuctionQuery`, `GetNumAuctionItems`, `GetAuctionItemInfo`, `GetAuctionItemLink`, and `AuctionFrameTab_OnClick` / `PanelTemplates_SetNumTabs` (for the tab). Browsing a result also uses `AuctionFrameBrowse_Search` / `BrowseName`.

`/tbcg debug api` lists which of these the client has. Without them the tab doesn't appear, or the scan says why it can't run.

## Known limits

- **Tab placement:** the tab is added after the auction tabs and any other add-on's tabs (`AuctionFrameTab<n>`, the next free number). An add-on that rebuilds the auction window entirely may hide it.
- **What one scan covers:** a scan only sees gear usable by your character at your level, uncommon or better. Lower-quality upgrades for very low levels aren't listed.
- **Item data:** items the client hasn't loaded yet are shown once their data arrives ("N items still loading").
- **Unscored things:** the same as automatic upgrades (unique-equipped limits, sockets, enchantments, weapon speed).

## In-game checklist

1. **Tab:** open the auction house. The **Upgrades** tab is there; the Browse, Bids and Auctions tabs work as before.
2. **Before a scan:** with no scan yet, it says **No scan data**.
3. **Scan:** press Scan. The status counts pages, the scan finishes as complete, and the list shows upgrades grouped by slot.
4. **Cancel:** start a scan and Cancel. It stops and says *partial*.
5. **Interrupted by a search:** start a scan, then search on the Browse tab. The scan stops with "another auction search was started".
6. **Closing:** close the auction house during a scan. It stops safely; reopen to see the partial data.
7. **Rows:** check that percentages match the bag tooltip and automatic upgrades for the same item, and that empty slots say *Empty slot*.
8. **Filters and sort:** try max price, minimum %, slot and the sort button.
9. **No rescan:** equip an upgrade, or change spec profile. The list updates without a new scan.
10. **Clicking a row:** it opens Browse with that item searched. Nothing is bought.
11. **Turning it off:** turn off *Enable Auctioneer*. The tab disappears and the native window is unaffected.
