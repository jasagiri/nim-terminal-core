# widgets.nim
## Terminal UI widget framework
##
## This module provides a comprehensive set of UI widgets
## for building terminal user interfaces.

import std/tables
# import std/options   # Reserved for future use
# import std/sequtils  # Reserved for future use
# import std/strutils  # Reserved for future use
import std/unicode
import std/algorithm

import output
import layout
# import input         # Reserved for future use
# import mouse         # Reserved for future use
import private/common
import widget_base

export output
export layout
export widget_base

#-----------------------------------------------------------------
# Event Handling
#-----------------------------------------------------------------

proc addEventHandler*(widget: Widget, eventKind: WidgetEventKind, 
                     handler: WidgetEventHandler) =
  ## Add an event handler for the specified event type
  if not widget.eventHandlers.hasKey(eventKind):
    widget.eventHandlers[eventKind] = @[]
  widget.eventHandlers[eventKind].add(handler)

proc removeEventHandler*(widget: Widget, eventKind: WidgetEventKind,
                        handler: WidgetEventHandler) =
  ## Remove an event handler
  if widget.eventHandlers.hasKey(eventKind):
    let idx = widget.eventHandlers[eventKind].find(handler)
    if idx >= 0:
      widget.eventHandlers[eventKind].delete(idx)
      if widget.eventHandlers[eventKind].len == 0:
        widget.eventHandlers.del(eventKind)

proc dispatchEvent*(widget: Widget, event: WidgetEvent): bool =
  ## Dispatch an event to handlers and return whether it was handled
  result = false
  
  # Call handlers for this event type
  if widget.eventHandlers.hasKey(event.kind):
    for handler in widget.eventHandlers[event.kind]:
      result = handler(widget, event)
      if result:
        return true
  
  # If not handled and we have a parent, propagate to parent
  if not result and widget.parent != nil:
    result = widget.parent.dispatchEvent(event)
  
  return result

proc createEvent*(kind: WidgetEventKind): WidgetEvent =
  ## Create a simple event of the specified kind
  result = WidgetEvent(kind: kind)

proc createMouseEvent*(kind: WidgetEventKind, x, y: int, 
                      button: MouseButton, 
                      modifiers: set[KeyModifier] = {}): WidgetEvent =
  ## Create a mouse event
  case kind
  of WidgetMouseMove, WidgetMouseDown, WidgetMouseUp, WidgetClick, WidgetDoubleClick:
    result = WidgetEvent(
      kind: kind,
      mouseX: x,
      mouseY: y,
      button: button,
      modifiers: modifiers
    )
  else:
    result = WidgetEvent(kind: kind)

proc createKeyEvent*(kind: WidgetEventKind, keyEvent: KeyEvent): WidgetEvent =
  ## Create a keyboard event
  case kind
  of WidgetKeyDown, WidgetKeyUp:
    result = WidgetEvent(
      kind: kind,
      key: keyEvent
    )
  else:
    result = WidgetEvent(kind: kind)

proc createCharEvent*(ch: Rune): WidgetEvent =
  ## Create a character input event
  result = WidgetEvent(
    kind: WidgetChar,
    ch: ch
  )

proc createStateEvent*(stateName: string): WidgetEvent =
  ## Create a state change event
  result = WidgetEvent(
    kind: WidgetStateChanged,
    stateName: stateName
  )

proc createResizeEvent*(width, height: int): WidgetEvent =
  ## Create a resize event
  result = WidgetEvent(
    kind: WidgetResize,
    newWidth: width,
    newHeight: height
  )

proc createCustomEvent*(customKind: string, data: pointer = nil): WidgetEvent =
  ## Create a custom event
  result = WidgetEvent(
    kind: WidgetCustom,
    customKind: customKind,
    customData: data
  )

#-----------------------------------------------------------------
# Rendering
#-----------------------------------------------------------------

method render*(widget: Widget, buffer: var Buffer) {.base.} =
  ## Render the widget to the provided buffer
  ## This is the base method that should be overridden by widgets
  if not widget.isVisible():
    return
    
  # Draw widget background
  let contentRect = widget.rect
  for y in contentRect.y..<(contentRect.y + contentRect.height):
    for x in contentRect.x..<(contentRect.x + contentRect.width):
      if x >= 0 and x < buffer.width and y >= 0 and y < buffer.height:
        buffer.print(x, y, " ", widget.bgStyle)
  
  # Render children
  for child in widget.children:
    child.render(buffer)

method handleEvent*(widget: Widget, event: Event): bool {.base.} =
  ## Process libterminal input events and convert to widget events
  ## Returns true if the event was handled
  result = false
  
  case event.kind
  of EvMouse:
    # Check if the mouse event is within our bounds
    let mouseEvent = event.mouse
    let relX = mouseEvent.x - widget.rect.x
    let relY = mouseEvent.y - widget.rect.y
    
    if relX >= 0 and relX < widget.rect.width and 
       relY >= 0 and relY < widget.rect.height:
      # Mouse is in our area, create appropriate widget event
      var widgetEvent: WidgetEvent
      case mouseEvent.action
      of MouseMoved:
        widgetEvent = createMouseEvent(WidgetMouseMove, relX, relY, mouseEvent.button, mouseEvent.modifiers)
        widget.setHovered(true)
      of MousePressed:
        widgetEvent = createMouseEvent(WidgetMouseDown, relX, relY, mouseEvent.button, mouseEvent.modifiers)
        widget.setActive(true)
      of MouseReleased:
        widgetEvent = createMouseEvent(WidgetMouseUp, relX, relY, mouseEvent.button, mouseEvent.modifiers)
        if widget.isActive():
          # If we were active and now released, it's a click
          let clickEvent = createMouseEvent(WidgetClick, relX, relY, mouseEvent.button, mouseEvent.modifiers)
          discard widget.dispatchEvent(clickEvent)
        widget.setActive(false)
      of MouseDragged:
        widgetEvent = createMouseEvent(WidgetMouseMove, relX, relY, mouseEvent.button, mouseEvent.modifiers)
      
      # Dispatch the event
      result = widget.dispatchEvent(widgetEvent)
      
      # If not handled, check children in reverse order (top to bottom)
      if not result:
        for i in countdown(widget.children.high, 0):
          result = widget.children[i].handleEvent(event)
          if result:
            break
    else:
      # Mouse moved outside our area
      if widget.isHovered():
        widget.setHovered(false)
      
      # Check if mouse is in any of our children
      for i in countdown(widget.children.high, 0):
        result = widget.children[i].handleEvent(event)
        if result:
          break
  
  of EvKey:
    # Only process key events if we have focus
    if widget.isFocused():
      let keyEvent = event.key
      
      # Create appropriate widget event
      var widgetEvent = createKeyEvent(WidgetKeyDown, keyEvent)
      result = widget.dispatchEvent(widgetEvent)
      
      # If it was a character input and not handled as a key, send char event
      if not result and keyEvent.ch != '\0':
        let charEvent = createCharEvent(keyEvent.ch.Rune)
        result = widget.dispatchEvent(charEvent)
    
    # If not handled and we have children, pass to focused child
    if not result:
      for child in widget.children:
        if child.isFocused():
          result = child.handleEvent(event)
          break
  
  of EvResize:
    # Create a resize event
    let resizeEvent = createResizeEvent(event.resize.width, event.resize.height)
    result = widget.dispatchEvent(resizeEvent)
    
    # Pass to all children
    for child in widget.children:
      discard child.handleEvent(event)
  
  of EvNone:
    discard

method update*(widget: Widget, deltaTime: float) {.base.} =
  ## Update widget state over time (animations, etc.)
  ## deltaTime is the time in seconds since the last update
  for child in widget.children:
    child.update(deltaTime)

#-----------------------------------------------------------------
# Focus Management
#-----------------------------------------------------------------

proc getNextFocusable*(widget: Widget, direction: int = 1): Widget =
  ## Find the next focusable widget in the focus order
  ## direction: 1 for forward, -1 for backward
  var allWidgets: seq[Widget] = @[]
  
  # Collect all focusable widgets
  proc collectFocusable(w: Widget) =
    if w.canFocus() and w.isVisible() and w.isEnabled():
      allWidgets.add(w)
    for child in w.children:
      collectFocusable(child)
  
  # Start with the root widget
  var root = widget
  while root.parent != nil:
    root = root.parent
  
  collectFocusable(root)
  
  # Sort by tab index
  allWidgets.sort(proc(a, b: Widget): int = a.tabIndex - b.tabIndex)
  
  # Find the current widget's position
  let currentIdx = allWidgets.find(widget)
  if currentIdx < 0 or allWidgets.len <= 1:
    return nil
  
  # Find the next focusable widget
  let nextIdx = (currentIdx + direction + allWidgets.len) mod allWidgets.len
  return allWidgets[nextIdx]

proc moveFocus*(widget: Widget, direction: int = 1): bool =
  ## Move focus to the next focusable widget
  ## Returns true if focus was moved
  let next = widget.getNextFocusable(direction)
  if next != nil:
    widget.setFocused(false)
    next.setFocused(true)
    return true
  return false

#-----------------------------------------------------------------
# Widget Manager
#-----------------------------------------------------------------

type
  PreEventHandler* = proc(event: Event): bool {.closure.}

  WidgetManager* = ref object
    ## Manages the widget hierarchy and focus
    rootWidget*: Widget
    focusedWidget*: Widget
    hoveredWidget*: Widget
    buffer*: Buffer
    lastUpdateTime*: float
    preEventHandlers*: seq[PreEventHandler]  ## Handlers that get called before events reach widgets

proc newWidgetManager*(buffer: Buffer): WidgetManager =
  ## Create a new widget manager
  result = WidgetManager(
    buffer: buffer,
    lastUpdateTime: 0.0,
    preEventHandlers: @[]
  )
  
  # Create a root widget that spans the entire buffer
  result.rootWidget = newWidget("root", 0, 0, buffer.width, buffer.height)

proc render*(manager: WidgetManager) =
  ## Render all widgets
  if manager.rootWidget != nil:
    manager.rootWidget.render(manager.buffer)

proc handleEvent*(manager: WidgetManager, event: Event): bool =
  ## Process an input event
  ## First checks pre-event handlers, then passes to focused widget
  
  # Try pre-event handlers first
  for handler in manager.preEventHandlers:
    if handler(event):
      return true
  
  # If not handled by pre-event handlers, pass to root widget
  if manager.rootWidget != nil:
    return manager.rootWidget.handleEvent(event)
  
  return false

proc update*(manager: WidgetManager, currentTime: float) =
  ## Update widget state
  let deltaTime = currentTime - manager.lastUpdateTime
  manager.lastUpdateTime = currentTime
  
  if manager.rootWidget != nil:
    manager.rootWidget.update(deltaTime)

proc setFocus*(manager: WidgetManager, widget: Widget) =
  ## Set focus to a specific widget
  if manager.focusedWidget != nil:
    manager.focusedWidget.setFocused(false)
  
  if widget != nil and widget.canFocus():
    widget.setFocused(true)
    manager.focusedWidget = widget
  else:
    manager.focusedWidget = nil

proc findWidget*(manager: WidgetManager, id: string): Widget =
  ## Find a widget by ID
  if manager.rootWidget != nil:
    return manager.rootWidget.findChildById(id)
  return nil

proc addWidget*(manager: WidgetManager, widget: Widget) =
  ## Add a top-level widget
  if manager.rootWidget != nil:
    manager.rootWidget.addChild(widget)

proc removeWidget*(manager: WidgetManager, widget: Widget): bool =
  ## Remove a top-level widget
  if manager.rootWidget != nil:
    return manager.rootWidget.removeChild(widget)
  return false