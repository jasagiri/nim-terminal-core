# widget_base.nim
## Base widget types and enums
##
## This module contains the base types for the widget system
## to avoid circular dependencies.

import std/tables
# import std/options   # Reserved for future use
# import std/sequtils  # Reserved for future use
# import std/strutils  # Reserved for future use
import std/unicode
# import input         # Reserved for future use
import output
import layout
import private/common

type
  WidgetFlag* = enum
    ## Flags that control widget behavior and rendering
    WidgetFocusable,    ## Widget can receive keyboard focus
    WidgetVisible,      ## Widget is visible
    WidgetEnabled,      ## Widget is enabled (can receive input)
    WidgetHovered,      ## Widget is hovered by mouse
    WidgetFocused,      ## Widget has keyboard focus
    WidgetActive,       ## Widget is active (e.g., button pressed)
    WidgetSelected      ## Widget is selected

  WidgetEventKind* = enum
    ## Types of widget events
    WidgetMouseEnter,   ## Mouse entered widget area
    WidgetMouseLeave,   ## Mouse left widget area
    WidgetMouseMove,    ## Mouse moved within widget
    WidgetMouseDown,    ## Mouse button pressed on widget
    WidgetMouseUp,      ## Mouse button released on widget
    WidgetClick,        ## Mouse clicked (down+up) on widget
    WidgetDoubleClick,  ## Mouse double-clicked on widget
    WidgetKeyDown,      ## Key pressed while widget has focus
    WidgetKeyUp,        ## Key released while widget has focus
    WidgetChar,         ## Character input while widget has focus
    WidgetFocusIn,      ## Widget gained focus
    WidgetFocusOut,     ## Widget lost focus
    WidgetStateChanged, ## Widget state changed
    WidgetResize,       ## Widget was resized
    WidgetCustom        ## Custom widget-specific event
  
  WidgetEvent* = object
    ## Event information for widget events
    case kind*: WidgetEventKind
    of WidgetMouseEnter, WidgetMouseLeave:
      discard
    of WidgetMouseMove, WidgetMouseDown, WidgetMouseUp, WidgetClick, WidgetDoubleClick:
      mouseX*, mouseY*: int     ## Mouse coordinates relative to widget
      button*: MouseButton      ## Mouse button involved (for relevant events)
      modifiers*: set[KeyModifier]  ## Keyboard modifiers during event
    of WidgetKeyDown, WidgetKeyUp:
      key*: KeyEvent            ## Key information
    of WidgetChar:
      ch*: Rune                 ## Character input
    of WidgetFocusIn, WidgetFocusOut:
      discard
    of WidgetStateChanged:
      stateName*: string        ## Name of the state that changed
    of WidgetResize:
      newWidth*, newHeight*: int  ## New dimensions
    of WidgetCustom:
      customKind*: string       ## Custom event identifier
      customData*: pointer      ## Custom data for the event

  WidgetEventHandler* = proc(widget: Widget, event: WidgetEvent): bool {.closure.}
    ## Event handler for widget events
    ## Returns true if the event was handled, false to continue propagation
  
  WidgetState* = ref object of RootObj
    ## Base class for widget-specific state
    dataContext*: pointer  ## Data context for binding
  
  Widget* = ref object of RootObj
    ## Base widget class that all widgets inherit from
    id*: string                             ## Unique widget identifier
    parent*: Widget                         ## Parent widget (nil for root)
    children*: seq[Widget]                  ## Child widgets
    layoutNode*: LayoutNode                 ## Associated layout node
    rect*: Rect                             ## Widget's current rectangle
    flags*: set[WidgetFlag]                 ## Widget state flags
    style*: Style                           ## Widget visual style
    bgStyle*: Style                         ## Background style
    focusStyle*: Style                      ## Style when focused
    disabledStyle*: Style                   ## Style when disabled
    state*: WidgetState                     ## Widget-specific state
    eventHandlers*: Table[WidgetEventKind, seq[WidgetEventHandler]]  ## Event handlers
    tabIndex*: int                          ## Order in focus traversal
    properties*: Table[string, pointer]     ## Bindable properties for data binding

#-----------------------------------------------------------------
# Base Widget Methods
#-----------------------------------------------------------------

proc setFlag*(widget: Widget, flag: WidgetFlag, value: bool = true) =
  ## Set or clear a widget flag
  if value:
    widget.flags.incl(flag)
  else:
    widget.flags.excl(flag)

proc hasFlag*(widget: Widget, flag: WidgetFlag): bool =
  ## Check if a widget has a specific flag
  return flag in widget.flags

proc markDirty*(widget: Widget) =
  ## Mark the widget as needing to be redrawn
  ## This is a convenience method for widgets to trigger redraw
  discard

proc isVisible*(widget: Widget): bool = widget.hasFlag(WidgetVisible)
proc isEnabled*(widget: Widget): bool = widget.hasFlag(WidgetEnabled)
proc isFocused*(widget: Widget): bool = widget.hasFlag(WidgetFocused)
proc isHovered*(widget: Widget): bool = widget.hasFlag(WidgetHovered)
proc isActive*(widget: Widget): bool = widget.hasFlag(WidgetActive)
proc isSelected*(widget: Widget): bool = widget.hasFlag(WidgetSelected)
proc canFocus*(widget: Widget): bool = widget.hasFlag(WidgetFocusable)

proc setVisible*(widget: Widget, visible: bool = true) =
  ## Set widget visibility
  widget.setFlag(WidgetVisible, visible)

proc setEnabled*(widget: Widget, enabled: bool = true) =
  ## Set widget enabled state
  widget.setFlag(WidgetEnabled, enabled)

proc setFocused*(widget: Widget, focused: bool = true) =
  ## Set widget focus
  let wasFocused = widget.isFocused
  
  if focused != wasFocused:
    widget.setFlag(WidgetFocused, focused)

proc setHovered*(widget: Widget, hovered: bool = true) =
  ## Set widget hover state
  let wasHovered = widget.isHovered
  
  if hovered != wasHovered:
    widget.setFlag(WidgetHovered, hovered)

proc setActive*(widget: Widget, active: bool = true) =
  ## Set widget active state (e.g., button being pressed)
  widget.setFlag(WidgetActive, active)

proc setSelected*(widget: Widget, selected: bool = true) =
  ## Set widget selection state
  widget.setFlag(WidgetSelected, selected)

proc addChild*(widget: Widget, child: Widget) =
  ## Add a child widget
  child.parent = widget
  widget.children.add(child)

proc removeChild*(widget: Widget, child: Widget): bool =
  ## Remove a child widget, returns true if found and removed
  let idx = widget.children.find(child)
  if idx >= 0:
    widget.children.delete(idx)
    child.parent = nil
    return true
  return false

proc clearChildren*(widget: Widget) =
  ## Remove all child widgets
  for child in widget.children:
    child.parent = nil
  widget.children.setLen(0)

proc findChildById*(widget: Widget, id: string): Widget =
  ## Find a child widget by ID (recursive)
  if widget.id == id:
    return widget
    
  for child in widget.children:
    let found = child.findChildById(id)
    if found != nil:
      return found
      
  return nil

proc getCurrentStyle*(widget: Widget): Style =
  ## Get the appropriate style based on widget state
  if not widget.isEnabled:
    result = widget.disabledStyle
  elif widget.isFocused:
    result = widget.focusStyle
  else:
    result = widget.style

proc newWidget*(id: string, x, y, width, height: int): Widget =
  ## Create a new base widget
  result = Widget(
    id: id,
    rect: Rect(x: x, y: y, width: width, height: height),
    flags: {WidgetVisible, WidgetEnabled},
    children: @[],
    eventHandlers: initTable[WidgetEventKind, seq[WidgetEventHandler]](),
    tabIndex: 0,
    properties: initTable[string, pointer]()
  )
  
  # Create default styles
  result.style = Style(fg: ColorWhite, bg: ColorBlack, attrs: {})
  result.bgStyle = Style(fg: ColorWhite, bg: ColorBlack, attrs: {})
  result.focusStyle = Style(fg: ColorWhite, bg: ColorBlue, attrs: {})
  result.disabledStyle = Style(fg: ColorBrightBlack, bg: ColorBlack, attrs: {})

proc initWidget*(widget: Widget, id: string, x, y, width, height: int) =
  ## Initialize an existing widget
  widget.id = id
  widget.rect = Rect(x: x, y: y, width: width, height: height)
  widget.flags = {WidgetVisible, WidgetEnabled}
  widget.children = @[]
  widget.eventHandlers = initTable[WidgetEventKind, seq[WidgetEventHandler]]()
  widget.tabIndex = 0
  widget.properties = initTable[string, pointer]()
  
  # Create default styles
  widget.style = Style(fg: ColorWhite, bg: ColorBlack, attrs: {})
  widget.bgStyle = Style(fg: ColorWhite, bg: ColorBlack, attrs: {})
  widget.focusStyle = Style(fg: ColorWhite, bg: ColorBlue, attrs: {})
  widget.disabledStyle = Style(fg: ColorBrightBlack, bg: ColorBlack, attrs: {})

#-----------------------------------------------------------------
# Base Methods
#-----------------------------------------------------------------

method render*(widget: Widget) {.base.} =
  ## Base render method for widgets without buffer
  ## Override this in derived widgets
  discard

method handleEvent*(widget: Widget, event: WidgetEvent): bool {.base.} =
  ## Base event handler for widget events
  ## Override this in derived widgets
  return false