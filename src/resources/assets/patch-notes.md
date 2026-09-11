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

**DMC Patch Notes: 1.6.2**
*Tab Frame improvements and Destinations (walk command) enhancements*

**Destinations**: `walk list` now opens a dockable Destinations tab. Click a destination to walk there, and narrow the list with its filter box - by name, room name, or area - which applies as you type. If UI is disabled then it falls back to moveable alert.
  - **add / del buttons**: the panel header has `add` and `del` beside the filter box. They act on whatever is in the box: `add` saves it as a destination at your current room and `del` deletes any destination matching that name, with the same rules and messages as `walk add` / `walk rem`. The list refreshes straight away.
**Tab Frame**: tab styling updated to match panel header palette.
**Tab Frame**: tab header font is sizeable: **Settings -> Appearance -> Tab font size**
**Tab Frame**: undocked tabs now have a smaller outer-frame profile
**DMAPI**: API reference page now documents the referenceable state objects - `dmapi.player`, `dmapi.world`, `dmapi.core`, and `dmapi.settings` - with every field and its meaning, so you can see what's available to read without digging through the source.
**Item Tracker**: item names now link on give lines in either direction.


**Future Versions**
- disconnect / reconnect may lead to a path where default GUI is shown - creating confusion
- add a help system that pops up in a separate window with real working links and pages
- tab layout saves are debounced, so reloading the UI right after undocking/docking a tab can restore the previous arrangement - the container right-click "Save" only writes that window's geometry and does not record the tab as undocked