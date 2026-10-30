# high_level/app.nim  
## High-level application framework inspired by Textual

import std/asyncdispatch
import std/tables
import std/options
import ../async/event_loop
import ../raw
import ../output
import screen
import widget

export screen, widget

type
  App* = ref object of RootObj
    ## Main application object
    eventLoop*: EventLoop
    driver*: AsyncDriver
    screens*: Table[string, Screen]
    currentScreen*: Option[Screen]
    running*: bool
    title*: string
    
proc newApp*(title = "Terminal App"): App =
  ## Create a new application
  let driver = newAsyncDriver()
  result = App(
    driver: driver,
    eventLoop: newEventLoop(driver),
    screens: initTable[string, Screen](),
    currentScreen: none(Screen),
    running: false,
    title: title
  )

proc addScreen*(app: App, name: string, screen: Screen) =
  ## Add a named screen to the app
  app.screens[name] = screen
  screen.app = cast[pointer](app)

proc setScreen*(app: App, name: string) =
  ## Switch to a named screen
  if name in app.screens:
    # Deactivate current screen
    if app.currentScreen.isSome:
      app.currentScreen.get.active = false
    
    # Activate new screen
    let screen = app.screens[name]
    screen.active = true
    app.currentScreen = some(screen)
    
    # Trigger mount/unmount events
    # TODO: Implement widget lifecycle events

method compose*(app: App): seq[Widget] {.base.} =
  ## Override to define app's default widgets
  @[]

proc onMount*(app: App) {.async.} =
  ## Called when app starts
  discard

proc onUnmount*(app: App) {.async.} =
  ## Called when app stops
  discard

proc setup*(app: App) {.async.} =
  ## Setup the application
  # Enter raw mode
  discard enterRawMode()
  
  # Setup event handlers
  app.eventLoop.addHandler(ekKey, proc(event: Event): Future[bool] {.async.} =
    if app.currentScreen.isSome:
      return await app.currentScreen.get.handleKeyEvent(event.key)
    return false
  )
  
  # Call mount
  await app.onMount()
  
  # Create default screen if none set
  if app.currentScreen.isNone and app.screens.len == 0:
    let mainScreen = newScreen("main")
    mainScreen.widgets = app.compose()
    app.addScreen("main", mainScreen)
    app.setScreen("main")

proc run*(app: App) {.async.} =
  ## Run the application
  app.running = true
  
  # Setup
  await app.setup()
  
  # Clear screen
  clearScreen()
  
  # Initial render
  if app.currentScreen.isSome:
    await app.currentScreen.get.render(app.driver)
  
  # Run event loop
  await app.eventLoop.run()
  
  # Cleanup
  await app.onUnmount()
  discard exitRawMode()

proc stop*(app: App) =
  ## Stop the application
  app.running = false
  app.eventLoop.stop()

# Convenience template for running apps
template runApp*(appType: typedesc) =
  ## Run an app of the given type
  proc main() {.async.} =
    let app = appType.new()
    await app.run()
  
  waitFor main()