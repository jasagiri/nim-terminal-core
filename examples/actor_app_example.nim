# actor_app_example.nim
## Example of actor-based terminal app

import std/asyncdispatch
import std/options
import ../src/libterminal/actors/app_actor
import ../src/libterminal/actors/widget_actor

# Custom actor for handling counter logic
type
  CounterActor = ref object of Actor
    count: int
    display: Option[ActorRef]  # Label to update

proc newCounterActor(): CounterActor =
  CounterActor(count: 0, display: none(ActorRef))

method handleInfo*(counter: CounterActor, msg: Message) {.async.} =
  case msg.info
  of "increment":
    inc counter.count
    if counter.display.isSome:
      # Update display label
      counter.display.get.info("Counter: " & $counter.count)
  of "decrement":
    dec counter.count
    if counter.display.isSome:
      counter.display.get.info("Counter: " & $counter.count)
  else:
    discard

# Run the app
runActorApp:
  # Create main app and screen
  let appRef = app  # The app actor reference
  let mainScreen = spawn(ScreenActor, some(appRef))
  
  # Register screen
  appRef.castMessage(RegisterScreen(name: "main", screen: mainScreen))
  
  # Create UI builder
  let ui = newUIBuilder(mainScreen)
  
  # Create counter actor
  let counter = spawn(CounterActor, some(mainScreen))
  
  # Build UI
  let titleLabel = ui.label("Actor-based Terminal Application", 10, 2)
  let helpLabel = ui.label("Press +/- to change counter, Q to quit", 10, 4)
  let counterLabel = ui.label("Counter: 0", 10, 6)
  
  # Connect counter to display
  CounterActor(counter).display = some(counterLabel)
  
  # Create buttons
  let incButton = ui.button("Increment (+)", 10, 8)
  let decButton = ui.button("Decrement (-)", 30, 8)
  let quitButton = ui.button("Quit (Q)", 10, 10)
  
  # Add widgets to screen
  let screen = ScreenActor(mainScreen)
  screen.addChild(titleLabel)
  screen.addChild(helpLabel)
  screen.addChild(counterLabel)
  screen.addChild(incButton)
  screen.addChild(decButton)
  screen.addChild(quitButton)
  
  # Setup keyboard handling
  let eventHandler = proc(event: Event): Future[bool] {.async.} =
    if event.kind == ekKey:
      case event.key.kind
      of KeyEventKind.Char:
        case event.key.ch
        of '+':
          counter.info("increment")
          await mainScreen.castMessage(RenderRequest(driver: AppActor(app).driver))
          return true
        of '-':
          counter.info("decrement")
          await mainScreen.castMessage(RenderRequest(driver: AppActor(app).driver))
          return true
        of 'q', 'Q':
          appRef.castMessage(StopApp())
          return true
        else:
          discard
      else:
        discard
    return false
  
  AppActor(app).eventLoop.addHandler(ekKey, eventHandler)
  
  # Switch to main screen
  appRef.castMessage(SwitchScreen(name: "main"))