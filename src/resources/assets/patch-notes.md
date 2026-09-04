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

**Alchemy Formula Parser**: <code>ea_data.lua</code> import, export, and merge: inherited characters can import their existing trial data, paste new <code>alchemy list</code> output, and export the merged result to their Mudlet home dir for Enchanter Assist to use
**Clickable Items**: includes some items that were reworked for haste and Sudharma items that were rebalanced.
**Line Formatter**: "Remove newlines" button, auto-strip leading whitespace per line, and collapse double spaces on format. These options are useful if you are copying an old description to make edits to it.
**Map**: add updated room link in Magic Forest
**Clickable Items**: added some additional patterns for clickable items.
**Affects Window**: when browsing ignored affects, display refresh is paused to allow easier scrolling/viewing.
**CMudWrapper**: fixed color bleeding to subsequent lines on Mudlet 4.21 when using `#COLOR`
**Logger**: all framework modules now log on load (DarkMistsMeta, DMAlertWindow, DMClickables, DMSessionTime, DMStatRoller, DMWalker)
**Damage Events**: `dmapi.player.combat.damage.outgoing` and `dmapi.player.combat.damage.incoming` and `dmapi.player.combat.damage.other` - new DMAPI events for tracking combat damage. DMC ShowDMG now uses these events, but other than that there should be no visual changes.

**DMC Patch Notes: 1.5.10**

**SkillUps**: skill improvement notifications now show an underlined clickable skill name that opens a scrollable `DMAlertWindow` with the full history, including a `[Reset]` button in the window body. Window auto-sizes to fit content.
**CMudWrapper**: `#<num> {cmd1|cmd2|...}` now properly strips braces and splits on the command separator, so `#10 {camo|vis}` repeats the sequence of both commands 10 times instead of sending the raw text
**Walker**: walk now stops automatically on disconnect (`sysDisconnectionEvent`) to avoid trying to navigate without a connection.
**Map**: fixed layout of Ioio area
**Clickable Items**: updated clickable items

**DMC Patch Notes: 1.5.11**

**SkillUps**: fixed display overflow in skill improvement history when the time since last skillup exceeds one hour.
**Enchanter Assist**: trial data and assistant info now displayed in an alert window.
**Map**: added Sunpaw Hollow.
**Map**: added The Sundered Vale.
**Map**: added The Fractured Herd.
**Map**: adjusted shop coloring in Sudharma - shops now properly color as points of interest.
**ItemTracker**: mobs looting corpses now trigger item link detection (e.g. `<mob> gets <item> from the corpse of <someone>`).
**ItemTracker**: updated items from the website.
**Item Viewer**: scoring and stat weight input polish.
**DarkMistsCore**: refactored startup flow for improved initialization reliability.
**TabFrame/TabWindow**: refactored components for cleaner layout handling and separation of concerns.
**Affects Window**: upgraded to a proper tab panel with a fixed header (live age display plus refresh/clear/ignore controls).
**Alert Window**: now a movable window - drag by the title bar, closes via the [X]; keeps the retro styling.
**DMAPI**: centralized all line-matching patterns into a single `DMPatterns` module for easier maintenance.

**DMC Patch Notes: 1.6.0**

**Settings Panel**: added settings window (available from the Button Bar and `dmc settings`) to expose many settings which were previously command based or unavailable. no more digging through help for a bunch of commands! :)
**Chat History**: Channel Filters added to header - single-letter buttons (A/S/Y/T/G/O/N/H) for All, Say, Yell, Tell, Group, OOC, Newbie, and House. Click to show or hide each channel.
**Walker**: `walk list` had some formatting enhancements and now opens in a moveable alert window.
**Enchanter Assist**: weapon-only formulas now open an alert window when it stops
**Alchemy Material List**: added a material checklist which filters the material list based on remaining needed essences `Modules > Enchant Assist > EA Tools > Alchemy Mat List`
**DMAPI**: fix some bugs with player state (would sometimes get stuck at `standing`)
**Affects Window**: reordered the header buttons.
**Walker**: walk status messages now adapt correctly to light/dark mode.
**Stat Roller**: general code clean-up
**Alert Window**: styling updates.

**DMC Patch Notes: 1.6.1**

**CMudWrapper**: Lua can now read your saved CMud variables with `CMudWrapper.getVariable(name, fallback)`.
**CMudWrapper**: new `#IMPORT` loads ready-made CMud script packs shipped with DMC - `#IMPORT {name}` to load one, `#IMPORT LIST` to browse what's available. `currently available script packs: colorauras, eyeshields, warpaints, and targeting`
**CMudWrapper**: `#CLASS {name} {remove}` now deletes a class along with all its triggers and aliases, so removing an imported pack is one step.
**Settings Panel**: CMud output colors are customizable per element (commands, names, classes) - or leave them on the theme and reset any time.
**Settings Panel**: status-bar colors get a full picker with live preview and individual R/G/B/A channels.
**Status Bars**: use a movable, resizable container that remembers its position; the old "Moveable" setting was removed.
**Player Window**: shows the clan account's gold balance.

**Future Versions**
- add a help system that pops up in a separate window with real working links and pages
- minimap startup performance improvements
- backwards compatibility testing No newline at end of file