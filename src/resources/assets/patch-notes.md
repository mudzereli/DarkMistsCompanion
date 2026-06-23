**DMC Patch Notes: 1.5.6**

**Session Timer**: button bar shows session time (M:SS / H:MM:SS), resets on login.
**Affects Ignore List**: click `[»]` on expired affects to auto-hide future expirations.
**Inline Damage Messages**: `showdmg` command with options for color, range or avg toggle.
**Alchemy Formula Parser & Item Viewer**: re-themed (gold-on-deep-purple palette).
**Alchemy Formula Parser heatmap**: fixed material counting for comma/space-separated formats.
**Map**: removed Light Mists exit from Basilica Road; added auction houses in Ofcol, New Ethshar, Elvenhame, Guldoran, Wistolk, and DDA.

**DMC Patch Notes: 1.5.7**

### New Stuff
**Line Formatter**: standalone HTML tool for wrapping text and prepending line prefixes. Under `modules` on the Button Bar.
**Clickables**: vault item numbers in `=== VAULT CONTENTS ===` listings are now clickable — click to `get <number> vault`.

### Updates / Fixes
**Status Bars**: `sb hide`/`sb show`/`sb toggle` now persist properly (no longer auto-reveal on vitals updates).
**ItemTracker**: now uses event-driven and mass-capture detection (triggered by dmapi prompts and listing headers) instead of scanning every line. If you notice any items not being linked where they should, let me know.
**ItemTracker**: loaded all items from the website (now includes damage nouns).
**Clickables**: auctions, quests, and practices now stop rendering on prompt instead of relying on line counters.
**Map**: added wall street around Sudharma and some missing doors.

**DMC Patch Notes: 1.5.8**

**MakeArmor Module**: new `makearmor` command with automated casting, quality checking, rest/recovery, and configurable threshold/sleeper/container. for more info see `dmc help makearmor`
**CMudWrapper `#SHOW`/`#SAY`**: now inline by default. Use `%cr` for newlines. this is to allow more control over echoed output and match CMud functionality.
**Player Window**: vitals now show percentage values when estimated (% prompts), numeric values otherwise. fixes a bug where unknown stat values would keep stacking higher and higher
**Alchemy Formula Parser**: part numbers in the summary bar (1-Part through 5-Part) are now clickable links that filter both the formula table and the material heatmap to show only formulas with that many materials.
**Clickable Items**: fixed pattern offsets and added some additional patterns for clickable items.

**DMC Patch Notes: 1.5.9**

**CMudWrapper**: fixed color bleeding to subsequent lines on Mudlet 4.21 when using `#COLOR`
**Logger**: all framework modules now log on load (DarkMistsMeta, DMAlertWindow, DMClickables, DMSessionTime, DMStatRoller, DMWalker)
**Alchemy Formula Parser**: <code>ea_data.lua</code> import, export, and merge: inherited characters can import their existing trial data, paste new <code>alchemy list</code> output, and export the merged result to their Mudlet home dir for Enchanter Assist to use
**Affects Window**: when browsing ignored affects, display refresh is paused to allow easier scrolling/viewing.
**Clickable Items**: fixed pattern offsets and added some additional patterns for clickable items.

**Future Versions**
- potential way to disable "prac" command or detect lag