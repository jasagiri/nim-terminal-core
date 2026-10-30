# test_high_level.nim
## Tests for high-level async API

import unittest
import std/asyncdispatch
import std/options
import std/tables
import ../src/libterminal/async/driver
import ../src/libterminal/async/event_loop
import ../src/libterminal/high_level/app
import ../src/libterminal/high_level/screen
import ../src/libterminal/high_level/widget
import ../src/libterminal/output

suite "Async Driver":
  test "Driver creation":
    let driver = newAsyncDriver(dkHeadless)
    check driver.kind == dkHeadless
  
  test "Headless driver operations":
    let driver = newAsyncDriver(dkHeadless)
    
    # Read event (should return none in headless)
    let eventOpt = waitFor driver.readEvent()
    check eventOpt.isNone
    
    # Write operations (should not crash)
    waitFor driver.write(0, 0, "test")
    waitFor driver.clear()
    waitFor driver.flush()

suite "Event Loop":
  test "Event loop creation":
    let driver = newAsyncDriver(dkHeadless)
    let loop = newEventLoop(driver)
    
    check loop.driver == driver
    check loop.running == false
    check loop.handlers.len == 0  # tables have .len property
  
  test "Event handler management":
    let driver = newAsyncDriver(dkHeadless)
    let loop = newEventLoop(driver)
    
    var handled = false
    proc handler(event: Event): Future[bool] {.async.} =
      handled = true
      return true
    
    loop.addHandler(ekKey, handler)
    check loop.handlers.len == 1
    check len(loop.handlers[ekKey]) == 1
    
    loop.removeHandler(ekKey, handler)
    check len(loop.handlers[ekKey]) == 0
  
  test "Event dispatching":
    let driver = newAsyncDriver(dkHeadless)
    let loop = newEventLoop(driver)
    
    var keyHandled = false
    proc keyHandler(event: Event): Future[bool] {.async.} =
      if event.kind == ekKey:
        keyHandled = true
        return true
      return false
    
    loop.addHandler(ekKey, keyHandler)
    
    # Dispatch key event
    let keyEvent = Event(kind: ekKey)
    waitFor loop.dispatchEvent(keyEvent)
    check keyHandled == true
  
  test "Custom event posting":
    let driver = newAsyncDriver(dkHeadless)
    let loop = newEventLoop(driver)
    
    let customEvent = Event(kind: ekCustom, data: nil)
    loop.postEvent(customEvent)
    
    waitFor loop.processEvents()
    # Event should be consumed

suite "High-level App":
  test "App creation":
    # Use a custom app that uses headless driver for testing
    var app = App(
      driver: newAsyncDriver(dkHeadless),
      eventLoop: nil,
      screens: initTable[string, Screen](),
      currentScreen: none(Screen),
      running: false,
      title: "Test App"
    )
    app.eventLoop = newEventLoop(app.driver)
    
    check app.title == "Test App"
    check app.screens.len == 0
    check app.currentScreen.isNone
    check app.running == false
  
  test "Screen management":
    # Create app with headless driver
    var app = App(
      driver: newAsyncDriver(dkHeadless),
      eventLoop: nil,
      screens: initTable[string, Screen](),
      currentScreen: none(Screen),
      running: false,
      title: "Test"
    )
    app.eventLoop = newEventLoop(app.driver)
    let screen = newScreen("main")
    
    app.addScreen("main", screen)
    check app.screens.len == 1
    check app.screens.hasKey("main")
    
    app.setScreen("main")
    check app.currentScreen.isSome
    check app.currentScreen.get == screen
    check screen.active == true
  
  test "Default compose":
    var app = App(
      driver: newAsyncDriver(dkHeadless),
      eventLoop: nil,
      screens: initTable[string, Screen](),
      currentScreen: none(Screen),
      running: false,
      title: "Test"
    )
    app.eventLoop = newEventLoop(app.driver)
    let widgets = app.compose()
    check widgets.len == 0

suite "Screen":
  test "Screen creation":
    let screen = newScreen("test")
    check screen.name == "test"
    check screen.widgets.len == 0
    check screen.active == false
    check screen.focusedWidget.isNone
  
  test "Widget management":
    let screen = newScreen("test")
    let widget = newLabel("test")
    
    screen.addWidget(widget)
    check screen.widgets.len == 1
    
    screen.removeWidget(widget)
    check screen.widgets.len == 0
  
  test "Focus management":
    let screen = newScreen("test")
    let widget = newLabel("test")
    
    screen.addWidget(widget)
    screen.setFocus(widget)
    check widget.focused == true
    check screen.focusedWidget.isSome
    check screen.focusedWidget.get == widget

suite "Widgets":
  test "Widget base initialization":
    let widget = Widget()
    widget.id = "test-id"
    widget.styles = @["class1", "class2"]
    widget.visible = true
    
    check widget.id == "test-id"
    check widget.styles == @["class1", "class2"]
    check widget.visible == true
    check widget.focused == false
    check widget.x == 0
    check widget.y == 0
  
  test "Label widget":
    let label = newLabel("Hello World")
    label.id = "greeting"
    check label.text == "Hello World"
    check label.id == "greeting"
    check label.visible == true
  
  test "Button widget":
    let button = newButton("Click Me", nil)
    button.id = "btn1"
    check button.label == "Click Me"
    check button.id == "btn1"
    check button.onClick == nil
    
    var clicked = false
    proc onClick() {.async.} =
      clicked = true
    
    let button2 = newButton("Test", onClick)
    check button2.onClick != nil
  
  test "Widget lifecycle methods":
    var mountCalled = false
    var unmountCalled = false
    
    let widget = newLabel("test")
    
    # Test mount
    waitFor widget.mount(nil)
    check widget.mounted == true
    
    # Test unmount  
    waitFor widget.unmount()
    check widget.mounted == false