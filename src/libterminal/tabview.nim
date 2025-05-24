import widgets, output, input, unicode, sequtils, strutils, private/common

type
  TabPosition* = enum
    TabPositionTop,       # Tabs at the top
    TabPositionBottom,    # Tabs at the bottom
    TabPositionLeft,      # Tabs on the left side
    TabPositionRight      # Tabs on the right side
  
  TabItem* = object
    title*: string
    widget*: Widget
    id*: string
    closable*: bool
    enabled*: bool
  
  TabViewState* = ref object of WidgetState
    tabs*: seq[TabItem]
    activeTabIndex*: int
    tabPosition*: TabPosition
    tabWidth*: int        # Fixed width for tabs, or 0 for dynamic sizing
    showTabBar*: bool
    onTabChange*: proc(oldIndex, newIndex: int) {.closure.}
    onTabClose*: proc(index: int): bool {.closure.}  # Return true to allow closing

proc newTabViewState*(): TabViewState =
  result = TabViewState()
  result.tabs = @[]
  result.activeTabIndex = -1
  result.tabPosition = TabPositionTop
  result.tabWidth = 0  # Dynamic size
  result.showTabBar = true
  result.onTabChange = nil
  result.onTabClose = nil

proc newTabView*(id: string): Widget =
  result = newWidget(id, 0, 0, 0, 0)
  result.state = newTabViewState()
  
  # Default style
  result.style.fg = ColorDefault
  result.style.bg = ColorDefault
  result.style.focusFg = ColorWhite
  result.style.focusBg = ColorBlue
  
  # TabView should be visible and focusable
  result.flags.incl(WidgetVisible)
  result.flags.incl(WidgetFocusable)

proc getTabViewState*(widget: Widget): TabViewState =
  return TabViewState(widget.state)

proc getMaxTabWidth(state: TabViewState): int =
  result = 3
  for tab in state.tabs:
    result = max(result, tab.title.len + 2)

proc addTab*(tabView: Widget, title, id: string, widget: Widget, closable: bool = false) =
  let state = tabView.getTabViewState()
  
  # Create a new tab
  let tab = TabItem(
    title: title,
    widget: widget,
    id: id,
    closable: closable,
    enabled: true
  )
  
  # Add to tabs
  state.tabs.add(tab)
  
  # If this is the first tab, make it active
  if state.activeTabIndex == -1:
    state.activeTabIndex = 0
  
  # Add the widget as a child of the tabView
  tabView.addChild(widget)
  
  # Hide all widgets except the active one
  for i, t in state.tabs:
    t.widget.flags.incl(WidgetVisible)
    if i != state.activeTabIndex:
      t.widget.flags.excl(WidgetVisible)
  
  tabView.markDirty()

proc removeTab*(tabView: Widget, index: int) =
  let state = tabView.getTabViewState()
  
  if index < 0 or index >= state.tabs.len:
    return
  
  # Get the tab to remove
  let tab = state.tabs[index]
  
  # Remove widget from children
  discard tabView.removeChild(tab.widget)
  
  # Remove the tab
  state.tabs.delete(index)
  
  # Update active tab index
  if state.tabs.len == 0:
    state.activeTabIndex = -1
  elif state.activeTabIndex == index:
    state.activeTabIndex = min(index, state.tabs.len - 1)
  elif state.activeTabIndex > index:
    state.activeTabIndex = state.activeTabIndex - 1
  
  # Show the new active tab
  if state.activeTabIndex >= 0:
    for i, t in state.tabs:
      if i == state.activeTabIndex:
        t.widget.flags.incl(WidgetVisible)
      else:
        t.widget.flags.excl(WidgetVisible)
  
  tabView.markDirty()

proc removeTabById*(tabView: Widget, id: string) =
  let state = tabView.getTabViewState()
  var index = -1
  for i, tab in state.tabs:
    if tab.id == id:
      index = i
      break
  if index >= 0:
    tabView.removeTab(index)

proc setActiveTab*(tabView: Widget, index: int) =
  let state = tabView.getTabViewState()
  
  if index < 0 or index >= state.tabs.len or index == state.activeTabIndex:
    return
  
  # Call tab change callback if set
  if state.onTabChange != nil:
    state.onTabChange(state.activeTabIndex, index)
  
  let oldIndex = state.activeTabIndex
  state.activeTabIndex = index
  
  # Show the new active tab, hide others
  for i, tab in state.tabs:
    if i == index:
      tab.widget.flags.incl(WidgetVisible)
    else:
      tab.widget.flags.excl(WidgetVisible)
  
  tabView.markDirty()

proc setActiveTabById*(tabView: Widget, id: string) =
  let state = tabView.getTabViewState()
  var index = -1
  for i, tab in state.tabs:
    if tab.id == id:
      index = i
      break
  if index >= 0:
    tabView.setActiveTab(index)

proc getActiveTab*(tabView: Widget): int =
  return tabView.getTabViewState().activeTabIndex

proc getActiveTabWidget*(tabView: Widget): Widget =
  let state = tabView.getTabViewState()
  if state.activeTabIndex >= 0 and state.activeTabIndex < state.tabs.len:
    return state.tabs[state.activeTabIndex].widget
  return nil

proc setTabPosition*(tabView: Widget, position: TabPosition) =
  let state = tabView.getTabViewState()
  state.tabPosition = position
  tabView.markDirty()

proc setTabWidth*(tabView: Widget, width: int) =
  let state = tabView.getTabViewState()
  state.tabWidth = max(0, width)
  tabView.markDirty()

proc setShowTabBar*(tabView: Widget, show: bool) =
  let state = tabView.getTabViewState()
  state.showTabBar = show
  tabView.markDirty()

proc setOnTabChange*(tabView: Widget, callback: proc(oldIndex, newIndex: int) {.closure.}) =
  let state = tabView.getTabViewState()
  state.onTabChange = callback

proc setOnTabClose*(tabView: Widget, callback: proc(index: int): bool {.closure.}) =
  let state = tabView.getTabViewState()
  state.onTabClose = callback

proc closeTab*(tabView: Widget, index: int) =
  let state = tabView.getTabViewState()
  
  if index < 0 or index >= state.tabs.len:
    return
  
  if not state.tabs[index].closable:
    return
  
  # Check if closure is allowed by callback
  if state.onTabClose != nil:
    if not state.onTabClose(index):
      return
  
  # Remove the tab
  tabView.removeTab(index)

proc nextTab*(tabView: Widget) =
  let state = tabView.getTabViewState()
  if state.tabs.len <= 1:
    return
  
  let newIndex = (state.activeTabIndex + 1) mod state.tabs.len
  tabView.setActiveTab(newIndex)

proc previousTab*(tabView: Widget) =
  let state = tabView.getTabViewState()
  if state.tabs.len <= 1:
    return
  
  let newIndex = if state.activeTabIndex <= 0: state.tabs.len - 1 else: state.activeTabIndex - 1
  tabView.setActiveTab(newIndex)

proc layoutTabView(tabView: Widget) =
  let state = tabView.getTabViewState()
  let rect = tabView.rect
  
  # Skip if invalid dimensions
  if rect.width <= 0 or rect.height <= 0:
    return
  
  var contentRect = rect
  
  # Adjust content area based on tab position
  if state.showTabBar and state.tabs.len > 0:
    case state.tabPosition
    of TabPositionTop:
      contentRect.y += 1
      contentRect.height -= 1
    of TabPositionBottom:
      contentRect.height -= 1
    of TabPositionLeft:
      var maxTitleLen = 3
      for tab in state.tabs:
        maxTitleLen = max(maxTitleLen, tab.title.len + 2)
      contentRect.x += maxTitleLen
      contentRect.width -= maxTitleLen
    of TabPositionRight:
      var maxTitleLen = 3
      for tab in state.tabs:
        maxTitleLen = max(maxTitleLen, tab.title.len + 2)
      contentRect.width -= maxTitleLen
  
  # Position each tab content widget
  for i, tab in state.tabs:
    tab.widget.rect = contentRect
  
  tabView.markDirty()

proc renderTabs(tabView: Widget) =
  let state = tabView.getTabViewState()
  let rect = tabView.rect
  
  if not state.showTabBar or state.tabs.len == 0:
    return
  
  case state.tabPosition
  of TabPositionTop:
    # Draw top tab bar
    var xPos = rect.x
    for i, tab in state.tabs:
      # Calculate tab width
      let tabTitle = " " & tab.title & " "
      var tabWidth = if state.tabWidth > 0: state.tabWidth else: tabTitle.len
      
      # Draw tab
      var style: Style
      if i == state.activeTabIndex:
        style = Style(fg: tabView.style.focusFg, bg: tabView.style.focusBg)
      elif not tab.enabled:
        style = Style(fg: tabView.style.disabledFg, bg: tabView.style.bg)
      else:
        style = Style(fg: tabView.style.fg, bg: tabView.style.bg)
      
      setStyle(style)
      
      # Draw tab body
      setCursor(xPos, rect.y)
      stdout.write("╭")
      for x in 1..<tabWidth-1:
        stdout.write("─")
      stdout.write("╮")
      
      # Draw tab title
      setCursor(xPos + 1, rect.y)
      let displayText = if tabTitle.len > tabWidth - 2: 
                          tabTitle[0..<tabWidth-3] & "…" 
                        else: 
                          tabTitle
      stdout.write(displayText)
      
      # Add close button if closable
      if tab.closable:
        setCursor(xPos + tabWidth - 2, rect.y)
        stdout.write("×")
      
      # Move x position for next tab
      xPos += tabWidth
    
    # Fill remaining space
    var style = Style(fg: tabView.style.fg, bg: tabView.style.bg)
    setStyle(style)
    setCursor(xPos, rect.y)
    for x in xPos..<rect.x + rect.width:
      stdout.write("─")
    
    # Draw content separator line
    let separatorStyle = Style(fg: tabView.style.focusFg, bg: tabView.style.bg)
    setStyle(separatorStyle)
    setCursor(rect.x, rect.y + 1)
    for x in 0..<rect.width:
      stdout.write("─")
  
  of TabPositionBottom:
    # Draw bottom tab bar
    var xPos = rect.x
    let yPos = rect.y + rect.height - 1
    
    # Draw content separator line
    var style = Style(fg: tabView.style.focusFg, bg: tabView.style.bg)
    setStyle(style)
    setCursor(rect.x, yPos - 1)
    for x in 0..<rect.width:
      stdout.write("─")
    
    # Draw tabs
    for i, tab in state.tabs:
      # Calculate tab width
      let tabTitle = " " & tab.title & " "
      var tabWidth = if state.tabWidth > 0: state.tabWidth else: tabTitle.len
      
      # Draw tab
      if i == state.activeTabIndex:
        style = Style(fg: tabView.style.focusFg, bg: tabView.style.focusBg)
      elif not tab.enabled:
        style = Style(fg: tabView.style.disabledFg, bg: tabView.style.bg)
      else:
        style = Style(fg: tabView.style.fg, bg: tabView.style.bg)
      
      setStyle(style)
      
      # Draw tab body
      setCursor(xPos, yPos)
      stdout.write("╰")
      for x in 1..<tabWidth-1:
        stdout.write("─")
      stdout.write("╯")
      
      # Draw tab title
      setCursor(xPos + 1, yPos)
      let displayText = if tabTitle.len > tabWidth - 2: 
                          tabTitle[0..<tabWidth-3] & "…" 
                        else: 
                          tabTitle
      stdout.write(displayText)
      
      # Add close button if closable
      if tab.closable:
        setCursor(xPos + tabWidth - 2, yPos)
        stdout.write("×")
      
      # Move x position for next tab
      xPos += tabWidth
    
    # Fill remaining space
    style = Style(fg: tabView.style.fg, bg: tabView.style.bg)
    setStyle(style)
    setCursor(xPos, yPos)
    for x in xPos..<rect.x + rect.width:
      stdout.write("─")
  
  of TabPositionLeft:
    # Draw left tab bar
    let maxTabWidth = getMaxTabWidth(state)
    
    # Draw tabs
    for i, tab in state.tabs:
      let yPos = rect.y + i
      
      # Draw tab
      var style: Style
      if i == state.activeTabIndex:
        style = Style(fg: tabView.style.focusFg, bg: tabView.style.focusBg)
      elif not tab.enabled:
        style = Style(fg: tabView.style.disabledFg, bg: tabView.style.bg)
      else:
        style = Style(fg: tabView.style.fg, bg: tabView.style.bg)
      
      setStyle(style)
      
      # Draw tab title
      setCursor(rect.x, yPos)
      let tabTitle = tab.title & " "
      let displayText = if tabTitle.len > maxTabWidth - 1: 
                          tabTitle[0..<maxTabWidth-2] & "…" 
                        else: 
                          tabTitle & repeat(" ", maxTabWidth - tabTitle.len - 1)
      stdout.write(displayText)
      
      # Add close button if closable
      if tab.closable:
        setCursor(rect.x + maxTabWidth - 2, yPos)
        stdout.write("×")
    
    # Draw content separator line
    let separatorStyle = Style(fg: tabView.style.focusFg, bg: tabView.style.bg)
    setStyle(separatorStyle)
    let x = rect.x + maxTabWidth
    for y in rect.y..<rect.y + rect.height:
      setCursor(x - 1, y)
      stdout.write("│")
  
  of TabPositionRight:
    # Draw right tab bar
    let maxTabWidth = getMaxTabWidth(state)
    let xPos = rect.x + rect.width - maxTabWidth
    
    # Draw content separator line
    var style = Style(fg: tabView.style.focusFg, bg: tabView.style.bg)
    setStyle(style)
    for y in rect.y..<rect.y + rect.height:
      setCursor(xPos - 1, y)
      stdout.write("│")
    
    # Draw tabs
    for i, tab in state.tabs:
      let yPos = rect.y + i
      
      # Draw tab
      if i == state.activeTabIndex:
        style = Style(fg: tabView.style.focusFg, bg: tabView.style.focusBg)
      elif not tab.enabled:
        style = Style(fg: tabView.style.disabledFg, bg: tabView.style.bg)
      else:
        style = Style(fg: tabView.style.fg, bg: tabView.style.bg)
      
      setStyle(style)
      
      # Draw tab title
      setCursor(xPos, yPos)
      let tabTitle = " " & tab.title
      let displayText = if tabTitle.len > maxTabWidth - 1: 
                          tabTitle[0..<maxTabWidth-2] & "…" 
                        else: 
                          " ".repeat(maxTabWidth - tabTitle.len - 1) & tabTitle
      stdout.write(displayText)
      
      # Add close button if closable
      if tab.closable:
        setCursor(xPos + 1, yPos)
        stdout.write("×")

proc renderTabView*(widget: Widget) =
  let state = widget.getTabViewState()
  let rect = widget.rect
  
  # Skip if invalid dimensions
  if rect.width <= 0 or rect.height <= 0:
    return
  
  # Layout the tab view
  layoutTabView(widget)
  
  # Clear the entire area with background color
  var style = Style(fg: widget.style.fg, bg: widget.style.bg)
  setStyle(style)
  
  for y in 0..<rect.height:
    setCursor(rect.x, rect.y + y)
    for x in 0..<rect.width:
      stdout.write(" ")
  
  # Render the tabs
  renderTabs(widget)
  
  # The active tab's content will be rendered by the widget manager

proc getTabAt(tabView: Widget, x, y: int): int =
  let state = tabView.getTabViewState()
  let rect = tabView.rect
  
  if not state.showTabBar or state.tabs.len == 0:
    return -1
  
  case state.tabPosition
  of TabPositionTop:
    if y != rect.y:
      return -1
    
    var xPos = rect.x
    for i, tab in state.tabs:
      let tabWidth = if state.tabWidth > 0: state.tabWidth else: tab.title.len + 2
      if x >= xPos and x < xPos + tabWidth:
        return i
      xPos += tabWidth
  
  of TabPositionBottom:
    if y != rect.y + rect.height - 1:
      return -1
    
    var xPos = rect.x
    for i, tab in state.tabs:
      let tabWidth = if state.tabWidth > 0: state.tabWidth else: tab.title.len + 2
      if x >= xPos and x < xPos + tabWidth:
        return i
      xPos += tabWidth
  
  of TabPositionLeft:
    if x < rect.x or x >= rect.x + getMaxTabWidth(state):
      return -1
    
    let relY = y - rect.y
    if relY >= 0 and relY < state.tabs.len:
      return relY
  
  of TabPositionRight:
    let maxTabWidth = getMaxTabWidth(state)
    if x < rect.x + rect.width - maxTabWidth or x >= rect.x + rect.width:
      return -1
    
    let relY = y - rect.y
    if relY >= 0 and relY < state.tabs.len:
      return relY
  
  return -1

proc isCloseButtonAt(tabView: Widget, x, y: int): bool =
  let state = tabView.getTabViewState()
  let rect = tabView.rect
  
  let tabIndex = tabView.getTabAt(x, y)
  if tabIndex < 0 or tabIndex >= state.tabs.len:
    return false
  
  if not state.tabs[tabIndex].closable:
    return false
  
  case state.tabPosition
  of TabPositionTop:
    let tabWidth = if state.tabWidth > 0: state.tabWidth else: state.tabs[tabIndex].title.len + 2
    var xPos = rect.x
    for i in 0..<tabIndex:
      let tabW = if state.tabWidth > 0: state.tabWidth else: state.tabs[i].title.len + 2
      xPos += tabW
    return x == xPos + tabWidth - 2 and y == rect.y
  
  of TabPositionBottom:
    let tabWidth = if state.tabWidth > 0: state.tabWidth else: state.tabs[tabIndex].title.len + 2
    var xPos = rect.x
    for i in 0..<tabIndex:
      let tabW = if state.tabWidth > 0: state.tabWidth else: state.tabs[i].title.len + 2
      xPos += tabW
    return x == xPos + tabWidth - 2 and y == rect.y + rect.height - 1
  
  of TabPositionLeft:
    let maxTabWidth = getMaxTabWidth(state)
    return x == rect.x + maxTabWidth - 2 and y == rect.y + tabIndex
  
  of TabPositionRight:
    let maxTabWidth = getMaxTabWidth(state)
    return x == rect.x + rect.width - maxTabWidth + 1 and y == rect.y + tabIndex

proc handleTabViewKeyEvent*(widget: Widget, event: KeyEvent): bool =
  let state = widget.getTabViewState()
  
  # If we have an active tab, let it handle the key first
  if state.activeTabIndex >= 0 and state.activeTabIndex < state.tabs.len:
    let activeWidget = state.tabs[state.activeTabIndex].widget
    # TODO: Implement widget key event handling
    # if activeWidget.handleKeyEvent(event):
    #   return true
  
  # Handle tab navigation keys
  case event.key
  of KeyTab:
    if ModShift in event.modifiers:
      widget.previousTab()
    else:
      widget.nextTab()
    return true
  else:
    discard
  
  return false

proc handleTabViewMouseEvent*(widget: Widget, event: MouseEvent): bool =
  let state = widget.getTabViewState()
  
  # Check if the mouse event is on a tab
  if event.action == MousePressed and event.button == MouseLeft:
    let tabIndex = widget.getTabAt(event.x, event.y)
    
    if tabIndex >= 0 and tabIndex < state.tabs.len:
      # Check if click is on close button
      if widget.isCloseButtonAt(event.x, event.y):
        widget.closeTab(tabIndex)
      else:
        # Select the tab
        widget.setActiveTab(tabIndex)
      return true
  
  # If we have an active tab, let it handle the mouse event
  if state.activeTabIndex >= 0 and state.activeTabIndex < state.tabs.len:
    let activeWidget = state.tabs[state.activeTabIndex].widget
    
    # Calculate content area
    var contentRect = widget.rect
    if state.showTabBar and state.tabs.len > 0:
      case state.tabPosition
      of TabPositionTop:
        contentRect.y += 1
        contentRect.height -= 1
      of TabPositionBottom:
        contentRect.height -= 1
      of TabPositionLeft:
        contentRect.x += getMaxTabWidth(state)
        contentRect.width -= getMaxTabWidth(state)
      of TabPositionRight:
        contentRect.width -= getMaxTabWidth(state)
    
    # Check if event is in content area
    if event.x >= contentRect.x and event.x < contentRect.x + contentRect.width and
       event.y >= contentRect.y and event.y < contentRect.y + contentRect.height:
      if handleTabViewMouseEvent(activeWidget, event):
        return true
  
  return false

# Register tabview widget handlers
proc registerTabViewWidget*() =
  # registerWidgetRenderer("tabview", renderTabView)
  # registerWidgetKeyHandler("tabview", handleTabViewKeyEvent)
  # registerWidgetMouseHandler("tabview", handleTabViewMouseEvent)
  discard

# Auto-register when module is imported
registerTabViewWidget()