CLICKABLE_CONTAINERS_RUNNING = false
table.sort(CLICKABLE_CONTAINERS_DELETE_LINES)
for i = #CLICKABLE_CONTAINERS_DELETE_LINES, 1, -1 do
  local line = CLICKABLE_CONTAINERS_DELETE_LINES[i]
  moveCursor(0,line)
  deleteLine()
end
moveCursor(0,getLineNumber())
disableTrigger("ClickableContainers - Inventory Item")
disableTrigger("ClickableContainers - Cleanup")