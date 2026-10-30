# actors/widget_actor.nim
## Actor-based widget system

import std/options
import std/asyncdispatch
import actor
import ../output
import ../input
import ../async/driver
import ../private/common

export actor

type
  WidgetActor* = ref object of Actor
    ## Base widget actor
    x*, y*: int
    width*, height*: int
    visible*: bool
    focused*: bool
    parent*: Option[ActorRef]
    style*: Style
    
  # Message types for widgets
  RenderRequest* = object
    driver*: AsyncDriver
    
  UpdatePosition* = object
    x*, y*: int
    
  UpdateSize* = object  
    width*, height*: int
    
  UpdateStyle* = object
    style*: Style
    
  KeyInput* = object
    key*: KeyEvent
    
  MouseInput* = object
    mouse*: MouseEvent
    
  FocusChange* = object
    focused*: bool

method render*(widget: WidgetActor, driver: AsyncDriver) {.async, base.} =
  ## Base render method - subclasses should override
  discard

method handleCast*(widget: WidgetActor, msg: Message) {.async.} =
  ## Handle widget messages
  if msg.castPayload == nil:
    return
    
  # Try each message type
  try:
    let renderReq = cast[ptr RenderRequest](msg.castPayload)[]
    await widget.render(renderReq.driver)
    return
  except:
    discard
    
  try:
    let posUpdate = cast[ptr UpdatePosition](msg.castPayload)[]
    widget.x = posUpdate.x
    widget.y = posUpdate.y
    return
  except:
    discard
    
  try:
    let sizeUpdate = cast[ptr UpdateSize](msg.castPayload)[]
    widget.width = sizeUpdate.width
    widget.height = sizeUpdate.height
    return
  except:
    discard

# Specific widget actors
type
  LabelActor* = ref object of WidgetActor
    text*: string
    
  ButtonActor* = ref object of WidgetActor
    label*: string
    onClick*: Option[ActorRef]
    
  ContainerActor* = ref object of WidgetActor
    childWidgets*: seq[ActorRef]

proc newLabelActor*(text: string): LabelActor =
  result = LabelActor(text: text)
  result.visible = true

proc newButtonActor*(label: string, onClick: Option[ActorRef] = none(ActorRef)): ButtonActor =
  result = ButtonActor(label: label, onClick: onClick)
  result.visible = true

proc newContainerActor*(): ContainerActor =
  result = ContainerActor(childWidgets: @[])
  result.visible = true

method render*(label: LabelActor, driver: AsyncDriver) {.async.} =
  if label.visible:
    await driver.write(label.x, label.y, label.text, label.style)

method render*(button: ButtonActor, driver: AsyncDriver) {.async.} =
  if button.visible:
    let text = "[ " & button.label & " ]"
    let style = if button.focused:
      Style(fg: ColorBrightWhite, bg: ColorBlue, attrs: {})
    else:
      button.style
    await driver.write(button.x, button.y, text, style)

method handleCast*(button: ButtonActor, msg: Message) {.async.} =
  await procCall handleCast(WidgetActor(button), msg)
  
  if msg.castPayload != nil:
    try:
      let keyInput = cast[ptr KeyInput](msg.castPayload)[]
      if button.focused and keyInput.key.key == KeySpace:
        # Send click message to onClick handler
        if button.onClick.isSome:
          button.onClick.get.info("clicked")
    except:
      discard

method render*(container: ContainerActor, driver: AsyncDriver) {.async.} =
  if container.visible:
    # Render all child widgets
    for child in container.childWidgets:
      child.castMessage(RenderRequest(driver: driver))

method handleCast*(container: ContainerActor, msg: Message) {.async.} =
  await procCall handleCast(WidgetActor(container), msg)
  
  # Forward some messages to children
  if msg.castPayload != nil:
    try:
      let renderReq = cast[ptr RenderRequest](msg.castPayload)[]
      await container.render(renderReq.driver)
    except:
      discard

# Helper to add child widgets
proc addChild*(container: ContainerActor, child: ActorRef) =
  container.children.add(child)