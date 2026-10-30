# high_level/widget.nim
## High-level widget base class

import std/options
import std/asyncdispatch
import ../private/common
import ../async/driver
import ../output

type
  Widget* = ref object of RootObj
    ## Base widget class
    id*: string
    x*, y*: int
    width*, height*: int
    visible*: bool
    focused*: bool
    parent*: Widget
    children*: seq[Widget]
    app*: pointer  # Avoid circular import
    mounted*: bool
    styles*: seq[string]  # CSS classes
    
  WidgetEventKind* = enum
    wekClick
    wekKeyPress
    wekFocus
    wekBlur
    wekMount
    wekUnmount
    
  WidgetEvent* = object
    kind*: WidgetEventKind
    widget*: Widget
    key*: Option[KeyEvent]
    mouse*: Option[MouseEvent]

method compose*(w: Widget): seq[Widget] {.base.} =
  ## Return child widgets
  @[]

proc render*(w: Widget, driver: AsyncDriver) {.async.} =
  ## Render the widget (proc version for async)
  discard

proc handleKey*(w: Widget, key: KeyEvent): Future[bool] {.async.} =
  ## Handle keyboard input
  return false

proc handleMouse*(w: Widget, mouse: MouseEvent): Future[bool] {.async.} =
  ## Handle mouse input  
  return false

proc onMount*(w: Widget) {.async.} =
  ## Called when widget is added to screen
  discard

proc onUnmount*(w: Widget) {.async.} =
  ## Called when widget is removed
  discard

proc onFocus*(w: Widget) {.async.} =
  ## Called when widget gains focus
  discard

proc onBlur*(w: Widget) {.async.} =
  ## Called when widget loses focus
  discard

# Common widget types
type
  Label* = ref object of Widget
    text*: string
    
  Button* = ref object of Widget
    label*: string
    onClick*: proc() {.async.}
    
  Container* = ref object of Widget
    layout*: string  # "horizontal", "vertical", "grid"
    gap*: int

proc newLabel*(text: string): Label =
  result = Label(text: text, visible: true)

proc newButton*(label: string, onClick: proc() {.async.} = nil): Button =
  result = Button(label: label, onClick: onClick, visible: true)

proc newContainer*(layout = "vertical"): Container =
  result = Container(layout: layout, visible: true)

proc render*(label: Label, driver: AsyncDriver) {.async.} =
  if label.visible:
    await driver.write(label.x, label.y, label.text)

proc render*(button: Button, driver: AsyncDriver) {.async.} =
  if button.visible:
    let style = if button.focused:
      Style(fg: ColorBrightWhite, bg: ColorBlue, attrs: {})
    else:
      defaultStyle
    await driver.write(button.x, button.y, "[" & button.label & "]", style)

proc handleKey*(button: Button, key: KeyEvent): Future[bool] {.async.} =
  if button.onClick != nil and key.key == KeySpace:
    await button.onClick()
    return true
  return false

proc mount*(w: Widget, parent: Widget) {.async.} =
  ## Mount widget to parent
  w.parent = parent
  if parent != nil:
    parent.children.add(w)
  w.mounted = true
  await w.onMount()

proc unmount*(w: Widget) {.async.} =
  ## Remove widget from parent
  if w.parent != nil:
    let idx = w.parent.children.find(w)
    if idx >= 0:
      w.parent.children.delete(idx)
  w.mounted = false
  await w.onUnmount()
  w.parent = nil

proc focus*(w: Widget) {.async.} =
  ## Give focus to widget
  if not w.focused:
    w.focused = true
    await w.onFocus()

proc blur*(w: Widget) {.async.} =
  ## Remove focus from widget
  if w.focused:
    w.focused = false
    await w.onBlur()