# high_level_app_example.nim
## Example of high-level async app API

import std/asyncdispatch
import ../src/libterminal/high_level/app
import ../src/libterminal/input

type
  HelloApp = ref object of App
    counter: int

proc newHelloApp(): HelloApp =
  result = HelloApp()
  result.counter = 0
  result.init("Hello World App")

method compose(app: HelloApp): seq[Widget] =
  ## Define the app's UI
  result = @[
    newLabel("Welcome to Textual-style Terminal App!", "title"),
    newLabel("Press SPACE to increment counter", "help"),
    newLabel("Counter: " & $app.counter, "counter"),
    newButton("Increment", proc() {.async.} =
      inc app.counter
      # Update counter label
      if app.currentScreen.isSome:
        for widget in app.currentScreen.get.widgets:
          if widget.id == "counter":
            Label(widget).text = "Counter: " & $app.counter
    , "inc_btn"),
    newButton("Quit", proc() {.async.} =
      app.stop()
    , "quit_btn")
  ]
  
  # Position widgets
  if result.len > 0:
    result[0].y = 2
    result[0].x = 10
    result[1].y = 4
    result[1].x = 10
    result[2].y = 6
    result[2].x = 10
    result[3].y = 8
    result[3].x = 10
    result[4].y = 10
    result[4].x = 10

method onMount(app: HelloApp) {.async.} =
  ## Setup key handlers
  app.eventLoop.addHandler(ekKey, proc(event: Event): Future[bool] {.async.} =
    case event.key.kind
    of KeyEventKind.Char:
      case event.key.ch
      of 'q', 'Q':
        app.stop()
        return true
      of ' ':
        # Increment counter
        inc app.counter
        if app.currentScreen.isSome:
          for widget in app.currentScreen.get.widgets:
            if widget.id == "counter":
              Label(widget).text = "Counter: " & $app.counter
          await app.currentScreen.get.render(app.driver)
        return true
      else:
        discard
    of KeyEventKind.Esc:
      app.stop()
      return true
    else:
      discard
    return false
  )

# Run the app
when isMainModule:
  runApp(HelloApp)