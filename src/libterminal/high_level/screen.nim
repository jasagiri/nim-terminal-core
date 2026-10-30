# high_level/screen.nim
## Screen management for high-level apps

import std/options
import std/asyncdispatch
import widget
import ../async/driver
import ../private/common

type
  Screen* = ref object
    ## A screen contains widgets and manages rendering
    name*: string
    widgets*: seq[Widget]
    active*: bool
    app* {.cursor.}: pointer  # Avoid circular reference
    focusedWidget*: Option[Widget]

proc newScreen*(name: string): Screen =
  ## Create a new screen
  result = Screen(
    name: name,
    widgets: @[],
    active: false,
    app: nil,
    focusedWidget: none(Widget)
  )

proc addWidget*(screen: Screen, widget: Widget) =
  ## Add a widget to the screen
  screen.widgets.add(widget)
  # widget.parent = screen  # Could set parent if needed

proc removeWidget*(screen: Screen, widget: Widget) =
  ## Remove a widget from the screen
  let idx = screen.widgets.find(widget)
  if idx >= 0:
    screen.widgets.del(idx)
    # widget.parent = nil

proc handleKeyEvent*(screen: Screen, key: KeyEvent): Future[bool] {.async.} =
  ## Handle keyboard input
  # First try focused widget
  if screen.focusedWidget.isSome:
    let handled = await screen.focusedWidget.get.handleKey(key)
    if handled:
      return true
  
  # Then try all widgets in reverse order (top to bottom)
  for i in countdown(screen.widgets.high, 0):
    let handled = await screen.widgets[i].handleKey(key)
    if handled:
      return true
  
  return false

proc render*(screen: Screen, driver: AsyncDriver) {.async.} =
  ## Render the screen
  # Clear first
  await driver.clear()
  
  # Render each widget
  for widget in screen.widgets:
    if widget.visible:
      await widget.render(driver)
  
  # Flush output
  await driver.flush()

proc setFocus*(screen: Screen, widget: Widget) =
  ## Set keyboard focus to a widget
  # Unfocus current
  if screen.focusedWidget.isSome:
    screen.focusedWidget.get.focused = false
  
  # Focus new
  widget.focused = true
  screen.focusedWidget = some(widget)