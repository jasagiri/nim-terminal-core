import widgets, output, input, unicode, sequtils, strutils, private/common

type
  MenuItemType* = enum
    MenuItemNormal,      # Regular menu item
    MenuItemSeparator,   # Menu separator
    MenuItemSubMenu      # Submenu (contains other menu items)
    
  MenuItem* = ref object
    text*: string
    id*: string
    shortcut*: string
    enabled*: bool
    case itemType*: MenuItemType
    of MenuItemNormal:
      onSelect*: proc() {.closure.}
    of MenuItemSeparator:
      discard
    of MenuItemSubMenu:
      subItems*: seq[MenuItem]
      subMenu*: Widget  # The submenu widget when open

  MenuState* = ref object of WidgetState
    items*: seq[MenuItem]
    activeItem*: int
    isOpen*: bool
    isSubMenu*: bool
    parentMenu*: Widget
    activeSubMenu*: Widget
    onMenuClose*: proc() {.closure.}
    isSingleSelection*: bool  # True for context menu, false for menu bar
    showShortcuts*: bool

proc newMenuItem*(text, id: string, shortcut: string = "", onSelect: proc() {.closure.} = nil): MenuItem =
  result = MenuItem(
    text: text,
    id: id,
    shortcut: shortcut,
    enabled: true,
    itemType: MenuItemNormal,
    onSelect: onSelect
  )

proc newMenuSeparator*(): MenuItem =
  result = MenuItem(
    text: "",
    id: "",
    shortcut: "",
    enabled: false,
    itemType: MenuItemSeparator
  )

proc newSubMenuItem*(text, id: string): MenuItem =
  result = MenuItem(
    text: text,
    id: id,
    shortcut: "",
    enabled: true,
    itemType: MenuItemSubMenu,
    subItems: @[],
    subMenu: nil
  )

proc addItem*(parent: MenuItem, item: MenuItem) =
  if parent.itemType == MenuItemSubMenu:
    parent.subItems.add(item)

proc newMenuState*(isSubMenu: bool = false): MenuState =
  result = MenuState()
  result.items = @[]
  result.activeItem = -1
  result.isOpen = false
  result.isSubMenu = isSubMenu
  result.parentMenu = nil
  result.activeSubMenu = nil
  result.onMenuClose = nil
  result.isSingleSelection = false
  result.showShortcuts = true

proc newMenu*(id: string, isSubMenu: bool = false): Widget =
  result = newWidget(id, 0, 0, 20, 10)
  result.state = newMenuState(isSubMenu)
  
  # Default style
  result.style.fg = ColorDefault
  result.style.bg = ColorDefault
  result.style.focusFg = ColorWhite
  result.style.focusBg = ColorBlue
  result.style.disabledFg = ColorBrightBlack
  result.style.disabledBg = ColorDefault
  
  result.flags.incl(WidgetFocusable)
  if not isSubMenu:
    result.flags.incl(WidgetVisible)

proc getMenuState*(widget: Widget): MenuState =
  return MenuState(widget.state)

proc addItem*(menu: Widget, item: MenuItem) =
  let state = menu.getMenuState()
  state.items.add(item)
  menu.markDirty()

proc removeItem*(menu: Widget, id: string) =
  let state = menu.getMenuState()
  for i, item in state.items:
    if item.id == id:
      state.items.delete(i)
      break
  if state.activeItem >= state.items.len:
    state.activeItem = state.items.len - 1
  menu.markDirty()

proc clearItems*(menu: Widget) =
  let state = menu.getMenuState()
  state.items = @[]
  state.activeItem = -1
  menu.markDirty()

proc findItemById*(menu: Widget, id: string): MenuItem =
  let state = menu.getMenuState()
  for item in state.items:
    if item.id == id:
      return item
    if item.itemType == MenuItemSubMenu:
      # Recursively search in submenus
      for subItem in item.subItems:
        if subItem.id == id:
          return subItem
  return nil

proc setActiveItem*(menu: Widget, index: int) =
  let state = menu.getMenuState()
  if index >= -1 and index < state.items.len:
    state.activeItem = index
    menu.markDirty()

proc setSingleSelection*(menu: Widget, isSingleSelection: bool) =
  let state = menu.getMenuState()
  state.isSingleSelection = isSingleSelection
  menu.markDirty()

proc setShowShortcuts*(menu: Widget, showShortcuts: bool) =
  let state = menu.getMenuState()
  state.showShortcuts = showShortcuts
  menu.markDirty()

proc setOnMenuClose*(menu: Widget, callback: proc() {.closure.}) =
  let state = menu.getMenuState()
  state.onMenuClose = callback

proc open*(menu: Widget) =
  let state = menu.getMenuState()
  state.isOpen = true
  state.activeItem = if state.items.len > 0: 0 else: -1
  menu.flags.incl(WidgetVisible)
  menu.markDirty()

proc close*(menu: Widget) =
  let state = menu.getMenuState()
  
  # Close any active submenu first
  if state.activeSubMenu != nil:
    state.activeSubMenu.getMenuState().isOpen = false
    state.activeSubMenu.flags.excl(WidgetVisible)
    state.activeSubMenu = nil
  
  state.isOpen = false
  
  # If it's a submenu, just hide it
  if state.isSubMenu:
    menu.flags.excl(WidgetVisible)
  
  # Call the close callback if it exists
  if state.onMenuClose != nil:
    state.onMenuClose()
  
  menu.markDirty()

proc openSubMenu(menu: Widget, index: int) =
  let state = menu.getMenuState()
  
  # Close any existing submenu
  if state.activeSubMenu != nil:
    state.activeSubMenu.getMenuState().isOpen = false
    state.activeSubMenu.flags.excl(WidgetVisible)
    state.activeSubMenu = nil
  
  # Get the submenu item
  if index < 0 or index >= state.items.len:
    return
  
  let item = state.items[index]
  if item.itemType != MenuItemSubMenu or item.subItems.len == 0:
    return
  
  # Create submenu widget if it doesn't exist
  if item.subMenu == nil:
    let subMenuId = menu.id & "_submenu_" & item.id
    var subMenu = newMenu(subMenuId, true)
    
    # Copy styles from parent
    subMenu.style = menu.style
    
    # Add items to submenu
    for subItem in item.subItems:
      subMenu.addItem(subItem)
    
    # Set parent reference
    subMenu.getMenuState().parentMenu = menu
    
    # Store the submenu widget
    item.subMenu = subMenu
  
  # Position the submenu
  let submenu = item.subMenu
  let menuX = menu.rect.x
  let menuY = menu.rect.y + index
  
  # Position depends on whether this is a top-level menu or submenu
  if state.isSubMenu:
    # Position to the right of the parent menu
    submenu.rect.x = menuX + menu.rect.width
    submenu.rect.y = menuY
  else:
    # Position below the menu item
    submenu.rect.x = menuX
    submenu.rect.y = menuY + 1
  
  # Set submenu size based on content
  let menuItems = submenu.getMenuState().items
  let maxTextLen = if menuItems.len > 0: max(menuItems.mapIt(it.text.len)) else: 0
  let maxShortcutLen = if menuItems.len > 0: max(menuItems.mapIt(it.shortcut.len)) else: 0
  
  let width = maxTextLen + maxShortcutLen + 4  # Add padding
  let height = menuItems.len
  
  submenu.rect.width = max(10, width)
  submenu.rect.height = max(1, height)
  
  # Open the submenu
  submenu.open()
  
  # Set as active submenu
  state.activeSubMenu = submenu

proc calculateMenuSize(menu: Widget) =
  let state = menu.getMenuState()
  
  # For a menu bar (not a submenu and not single selection)
  if not state.isSubMenu and not state.isSingleSelection:
    var totalWidth = 0
    for item in state.items:
      totalWidth += item.text.len + 2  # Add some padding
    
    menu.rect.width = totalWidth
    menu.rect.height = 1
  else:
    # For dropdown or context menu
    let maxTextLen = if state.items.len > 0: max(state.items.mapIt(it.text.len)) else: 0
    let maxShortcutLen = if state.items.len > 0 and state.showShortcuts: 
                           max(state.items.mapIt(it.shortcut.len)) + 2 
                         else: 0
    
    menu.rect.width = maxTextLen + maxShortcutLen + 4  # Add padding
    menu.rect.height = state.items.len
  
  menu.markDirty()

proc renderMenu*(widget: Widget) =
  let state = widget.getMenuState()
  let rect = widget.rect
  
  # Calculate menu size if needed
  if rect.width == 0 or rect.height == 0:
    calculateMenuSize(widget)
  
  # For a menu bar (not a submenu and not single selection)
  if not state.isSubMenu and not state.isSingleSelection:
    # Draw menu bar
    setCursor(rect.x, rect.y)
    
    var currentPos = 0
    for i, item in state.items:
      let padding = 1
      let itemText = " " & item.text & " "
      let itemWidth = itemText.len
      
      # Set style based on active state
      var style: Style
      if i == state.activeItem and state.isOpen:
        style = Style(fg: widget.style.focusFg, bg: widget.style.focusBg)
      elif not item.enabled:
        style = Style(fg: widget.style.disabledFg, bg: widget.style.bg)
      else:
        style = Style(fg: widget.style.fg, bg: widget.style.bg)
      
      setStyle(style)
      setCursor(rect.x + currentPos, rect.y)
      stdout.write(itemText)
      
      currentPos += itemWidth
    
    # If a menu is open, render the submenu
    if state.isOpen and state.activeItem >= 0 and state.activeItem < state.items.len:
      let item = state.items[state.activeItem]
      if item.itemType == MenuItemSubMenu:
        openSubMenu(widget, state.activeItem)
  else:
    # Draw dropdown or context menu
    # First draw background
    var bgStyle = Style(fg: widget.style.fg, bg: widget.style.bg)
    setStyle(bgStyle)
    
    for y in 0..<rect.height:
      setCursor(rect.x, rect.y + y)
      for x in 0..<rect.width:
        stdout.write(" ")
    
    # Draw border
    for y in 0..<rect.height:
      setCursor(rect.x, rect.y + y)
      stdout.write("│")
      setCursor(rect.x + rect.width - 1, rect.y + y)
      stdout.write("│")
    
    for x in 0..<rect.width:
      setCursor(rect.x + x, rect.y)
      stdout.write("─")
      setCursor(rect.x + x, rect.y + rect.height - 1)
      stdout.write("─")
    
    # Draw corners
    setCursor(rect.x, rect.y)
    stdout.write("┌")
    setCursor(rect.x + rect.width - 1, rect.y)
    stdout.write("┐")
    setCursor(rect.x, rect.y + rect.height - 1)
    stdout.write("└")
    setCursor(rect.x + rect.width - 1, rect.y + rect.height - 1)
    stdout.write("┘")
    
    # Draw menu items
    for i, item in state.items:
      let y = rect.y + i
      
      # Skip if out of bounds
      if y < rect.y or y >= rect.y + rect.height:
        continue
      
      var itemStyle: Style
      if i == state.activeItem:
        itemStyle = Style(fg: widget.style.focusFg, bg: widget.style.focusBg)
      elif not item.enabled:
        itemStyle = Style(fg: widget.style.disabledFg, bg: widget.style.bg)
      else:
        itemStyle = Style(fg: widget.style.fg, bg: widget.style.bg)
      
      setStyle(itemStyle)
      
      # Draw menu item based on type
      case item.itemType
      of MenuItemSeparator:
        setCursor(rect.x + 1, y)
        for x in 1..<rect.width-1:
          stdout.write("─")
      of MenuItemNormal, MenuItemSubMenu:
        setCursor(rect.x + 1, y)
        let textWidth = rect.width - 2
        
        var text = " " & item.text
        if state.showShortcuts and item.shortcut.len > 0:
          let padding = textWidth - text.len - item.shortcut.len - 1
          text &= " ".repeat(padding) & item.shortcut
        
        # Ensure text fits within menu width
        let displayText = if text.len <= textWidth: text else: text[0..<textWidth]
        stdout.write(displayText)
        
        # Draw submenu indicator
        if item.itemType == MenuItemSubMenu:
          setCursor(rect.x + rect.width - 2, y)
          stdout.write("▶")
      
      # If this is the active item and it's a submenu, show the submenu
      if i == state.activeItem and state.isOpen and item.itemType == MenuItemSubMenu:
        openSubMenu(widget, i)

proc handleMenuKeyEvent*(widget: Widget, event: KeyEvent): bool =
  let state = widget.getMenuState()
  
  # If a submenu is active, let it handle the key first
  if state.activeSubMenu != nil and state.activeSubMenu.getMenuState().isOpen:
    if handleMenuKeyEvent(state.activeSubMenu, event):
      return true
  
  # Menu closed and not a menu bar, ignore keys
  if not state.isOpen and (state.isSubMenu or state.isSingleSelection):
    return false
  
  case event.key
  of KeyEscape:
    if state.isOpen:
      widget.close()
      return true
  of KeyEnter:
    if state.isOpen and state.activeItem >= 0 and state.activeItem < state.items.len:
      let item = state.items[state.activeItem]
      if item.enabled:
        case item.itemType
        of MenuItemNormal:
          if item.onSelect != nil:
            item.onSelect()
          widget.close()  # Close menu after selection
        of MenuItemSubMenu:
          openSubMenu(widget, state.activeItem)
        of MenuItemSeparator:
          discard
      return true
  of KeyLeft:
    if state.isSubMenu and state.parentMenu != nil:
      # Close this submenu and return to parent
      widget.close()
      return true
    elif not state.isSubMenu and not state.isSingleSelection:
      # In a menu bar, move to previous menu
      let newActive = if state.activeItem <= 0: state.items.len - 1 else: state.activeItem - 1
      widget.setActiveItem(newActive)
      if state.isOpen:
        openSubMenu(widget, newActive)
      return true
  of KeyRight:
    if not state.isSubMenu and not state.isSingleSelection:
      # In a menu bar, move to next menu
      let newActive = if state.activeItem >= state.items.len - 1: 0 else: state.activeItem + 1
      widget.setActiveItem(newActive)
      if state.isOpen:
        openSubMenu(widget, newActive)
      return true
    elif state.isOpen and state.activeItem >= 0 and state.activeItem < state.items.len:
      # Try to open submenu if the active item is a submenu
      let item = state.items[state.activeItem]
      if item.itemType == MenuItemSubMenu and item.enabled:
        openSubMenu(widget, state.activeItem)
        return true
  of KeyDown:
    if not state.isOpen and not state.isSubMenu and not state.isSingleSelection:
      # Open the menu
      widget.open()
      return true
    
    # Move to the next item
    var newActive = state.activeItem
    while true:
      newActive = (newActive + 1) mod state.items.len
      if newActive == state.activeItem or 
         state.items[newActive].itemType != MenuItemSeparator or
         state.items[newActive].enabled:
        break
    
    widget.setActiveItem(newActive)
    return true
  of KeyUp:
    # Move to the previous item
    var newActive = state.activeItem
    while true:
      newActive = if newActive <= 0: state.items.len - 1 else: newActive - 1
      if newActive == state.activeItem or 
         state.items[newActive].itemType != MenuItemSeparator or
         state.items[newActive].enabled:
        break
    
    widget.setActiveItem(newActive)
    return true
  else:
    # Check if any menu item has a matching shortcut
    let key = $event.key
    if key.len == 1:
      for i, item in state.items:
        if item.enabled and item.itemType != MenuItemSeparator:
          # Check if the first letter matches
          if item.text.len > 0 and unicode.toLower($item.text[0]) == unicode.toLower($key[0]):
            widget.setActiveItem(i)
            return true
  
  return false

proc handleMenuMouseEvent*(widget: Widget, event: MouseEvent): bool =
  let state = widget.getMenuState()
  
  # If a submenu is active, let it handle the mouse first
  if state.activeSubMenu != nil and state.activeSubMenu.getMenuState().isOpen:
    # Check if the mouse is within the submenu
    let subRect = state.activeSubMenu.rect
    if event.x >= subRect.x and event.x < subRect.x + subRect.width and
       event.y >= subRect.y and event.y < subRect.y + subRect.height:
      if handleMenuMouseEvent(state.activeSubMenu, event):
        return true
    elif event.action == MousePressed:
      # If clicked outside the submenu, close it
      state.activeSubMenu.getMenuState().isOpen = false
      state.activeSubMenu.flags.excl(WidgetVisible)
      state.activeSubMenu = nil
      widget.markDirty()
      return true
  
  # Menu closed and not a menu bar, ignore mouse
  if not state.isOpen and (state.isSubMenu or state.isSingleSelection):
    return false
  
  # Check if the mouse is within the menu
  if event.x < widget.rect.x or event.x >= widget.rect.x + widget.rect.width or
     event.y < widget.rect.y or event.y >= widget.rect.y + widget.rect.height:
    if event.action == MousePressed:
      # If clicked outside the menu, close it
      widget.close()
      return true
    return false
  
  # For menu bar
  if not state.isSubMenu and not state.isSingleSelection:
    var currentPos = widget.rect.x
    for i, item in state.items:
      let itemWidth = item.text.len + 2  # Add padding
      
      if event.x >= currentPos and event.x < currentPos + itemWidth:
        if event.action == MousePressed:
          widget.setActiveItem(i)
          if not state.isOpen:
            widget.open()
          elif i != state.activeItem or state.activeSubMenu == nil:
            openSubMenu(widget, i)
          return true
        elif event.action == MouseMoved:
          if state.isOpen and i != state.activeItem:
            widget.setActiveItem(i)
            openSubMenu(widget, i)
          return true
      
      currentPos += itemWidth
  else:
    # For dropdown or context menu
    let relativeY = event.y - widget.rect.y
    
    if relativeY >= 0 and relativeY < state.items.len:
      let item = state.items[relativeY]
      
      if event.action == MouseMoved:
        if relativeY != state.activeItem:
          widget.setActiveItem(relativeY)
          if item.itemType == MenuItemSubMenu and item.enabled:
            openSubMenu(widget, relativeY)
        return true
      elif event.action == MousePressed and item.enabled:
        widget.setActiveItem(relativeY)
        
        case item.itemType
        of MenuItemNormal:
          if item.onSelect != nil:
            item.onSelect()
          widget.close()
        of MenuItemSubMenu:
          openSubMenu(widget, relativeY)
        of MenuItemSeparator:
          discard
        
        return true
  
  return false

# Helper function to create a context menu
proc createContextMenu*(id: string, items: seq[MenuItem]): Widget =
  result = newMenu(id)
  result.setSingleSelection(true)
  
  for item in items:
    result.addItem(item)
  
  # Hide the menu initially
  result.flags.excl(WidgetVisible)

# Register menu widget handlers
proc registerMenuWidget*() =
  # TODO: Implement widget registration system
  # registerWidgetRenderer("menu", renderMenu)
  # registerWidgetKeyHandler("menu", handleMenuKeyEvent)
  # registerWidgetMouseHandler("menu", handleMenuMouseEvent)
  discard

# Auto-register when module is imported
registerMenuWidget()