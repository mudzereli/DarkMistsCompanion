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

**ItemTracker**: fixed pattern offsets. Added `"you get"` and `"you drop"` patterns.
**Item Viewer**: added Damage Noun filter and column.
**CMudWrapper `#SHOW`/`#SAY`**: now inline by default. Use `%cr` for newlines, leading spaces preserved.

**Future Versions**
- potential way to disable "prac" command or detect lag