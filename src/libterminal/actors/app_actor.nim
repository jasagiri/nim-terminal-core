# actors/app_actor.nim
## Actor-based application framework

import std/asyncdispatch
import std/options
import std/tables
import actor
import widget_actor
import ../async/driver
import ../async/event_loop
import ../raw
import ../output

type
  AppActor* = ref object of Supervisor
    ## Main application actor
    driver*: AsyncDriver
    eventLoop*: EventLoop
    title*: string
    running*: bool
    screens*: Table[string, ActorRef]
    currentScreen*: Option[string]
    
  ScreenActor* = ref object of ContainerActor
    ## Screen is a container that manages a set of widgets
    name*: string
    app*: ActorRef

  # App-specific messages
  StartApp* = object
  StopApp* = object
  SwitchScreen* = object
    name*: string
  RegisterScreen* = object
    name*: string
    screen*: ActorRef

proc newAppActor*(title = "Actor-based Terminal App"): AppActor =
  result = AppActor()
  # Initialize supervisor fields
  result.strategy = ssOneForOne
  result.restartStrategy = RestartStrategy(maxRestarts: 5, withinSeconds: 60)
  # Initialize app fields
  result.title = title
  result.driver = newAsyncDriver()
  result.eventLoop = newEventLoop(result.driver)
  result.screens = initTable[string, ActorRef]()
  result.running = false

proc newScreenActor*(name: string): ScreenActor =
  result = ScreenActor(name: name)
  result.childWidgets = @[]
  result.visible = true

method init*(app: AppActor) {.async.} =
  ## Initialize the app
  # Enter raw mode
  enterRawMode()
  
  # Setup event handlers
  app.eventLoop.addHandler(ekKey, proc(event: Event): Future[bool] {.async.} =
    # Forward to current screen
    if app.currentScreen.isSome and app.currentScreen.get in app.screens:
      app.screens[app.currentScreen.get].castMessage(KeyInput(key: event.key))
    return false
  )
  
  app.running = true

method terminate*(app: AppActor, reason: string) {.async.} =
  ## Cleanup when app stops
  app.running = false
  app.eventLoop.stop()
  discard exitRawMode()
  await procCall terminate(Actor(app), reason)

proc start*(app: AppActor) {.async.}  # Forward declaration
proc switchScreen*(app: AppActor, name: string) {.async.}  # Forward declaration
proc runEventLoop*(app: AppActor) {.async.}  # Forward declaration
proc renderCurrentScreen*(app: AppActor) {.async.}  # Forward declaration

method handleCast*(app: AppActor, msg: Message) {.async.} =
  if msg.castPayload == nil:
    return
    
  # Handle app messages
  try:
    let startMsg = cast[ptr StartApp](msg.castPayload)[]
    await app.start()
    return
  except:
    discard
    
  try:
    let stopMsg = cast[ptr StopApp](msg.castPayload)[]
    app.self.send(Message(kind: mkTerminate, termReason: "User requested stop"))
    return
  except:
    discard
    
  try:
    let switchMsg = cast[ptr SwitchScreen](msg.castPayload)[]
    await app.switchScreen(switchMsg.name)
    return
  except:
    discard
    
  try:
    let regMsg = cast[ptr RegisterScreen](msg.castPayload)[]
    app.screens[regMsg.name] = regMsg.screen
    return
  except:
    discard

proc start*(app: AppActor) {.async.} =
  ## Start the application
  clearScreen()
  
  # Start event loop in background
  asyncCheck app.runEventLoop()
  
  # Initial render
  await app.renderCurrentScreen()

proc runEventLoop*(app: AppActor) {.async.} =
  ## Run the event loop
  while app.running:
    let eventOpt = await app.driver.readEvent()
    if eventOpt.isSome:
      await app.eventLoop.dispatchEvent(eventOpt.get)
    await sleepAsync(1)

proc switchScreen*(app: AppActor, name: string) {.async.} =
  ## Switch to a different screen
  if name in app.screens:
    app.currentScreen = some(name)
    await app.renderCurrentScreen()

proc renderCurrentScreen*(app: AppActor) {.async.} =
  ## Render the current screen
  if app.currentScreen.isSome and app.currentScreen.get in app.screens:
    await app.driver.clear()
    app.screens[app.currentScreen.get].castMessage(RenderRequest(driver: app.driver))
    await app.driver.flush()

# Builder pattern for creating UI
type
  UIBuilder* = object
    ## Helper for building actor-based UIs
    supervisor*: ActorRef
    
proc newUIBuilder*(supervisor: ActorRef): UIBuilder =
  UIBuilder(supervisor: supervisor)

proc label*(builder: UIBuilder, text: string, x, y: int): ActorRef =
  ## Create a label actor
  let labelActor = newLabelActor(text)
  labelActor.x = x
  labelActor.y = y
  let actorRef = spawn(LabelActor, some(builder.supervisor))
  actorRef.castMessage(UpdatePosition(x: x, y: y))
  return actorRef

proc button*(builder: UIBuilder, label: string, x, y: int, 
             onClick: proc() {.async.} = nil): ActorRef =
  ## Create a button actor
  let actorRef = spawn(ButtonActor, some(builder.supervisor))
  actorRef.castMessage(UpdatePosition(x: x, y: y))
  
  # Note: Can't directly set onClick through ActorRef
  # Would need to send a message to configure it
  
  return actorRef

proc container*(builder: UIBuilder, x, y: int): ActorRef =
  ## Create a container actor
  let actor = spawn(ContainerActor, some(builder.supervisor))
  actor.castMessage(UpdatePosition(x: x, y: y))
  return actor

# Template for running actor-based apps
template runActorApp*(setup: untyped) =
  proc main() {.async.} =
    let app = spawn(AppActor)
    
    # User setup
    setup
    
    # Start app
    app.castMessage(StartApp())
    
    # Wait for completion
    while AppActor(app).running:
      await sleepAsync(100)
  
  waitFor main()