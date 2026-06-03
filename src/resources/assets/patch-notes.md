# DarkMistsCompanion Patch Notes

---

## 2026-06-03

### Added
- **Session Timer** — a `⏱ M:SS` / `⏱ H:MM:SS` display on the button bar that tracks time logged in to the current world session. Resets on login/reconnect and clears on disconnect. Hover for "Session timer" tooltip.
- **Affects Ignore List** — expired affects in the Affects window now show an `[»]` Ignore link. Clicking it adds the spell name to an auto-remove set so future expirations of that affect disappear silently without cluttering the list.
- **Inline Damage Messages** — damage verb matching with estimated damage ranges appended to combat output. Configurable color (`damageMessageColor`) and mode: `avg` (average only) or `range` (min–max range with average). Verb table covers all damage tiers from misses up to UNGODLY.

### Changed
- Button bar now places the session timer label after the last menu item (instead of right-anchored) so it stays visible and isn't hidden behind the map window.
