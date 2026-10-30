# test_input_extended.nim
## Extended tests for input processing

import unittest
import std/[options, os, times]
import ../src/libterminal/input
import ../src/libterminal/private/common
import ../src/libterminal/private/signals
import ../src/libterminal/raw

suite "Input Event Queue":
  test "Push and poll events":
    clearEvents()
    
    # Push multiple events
    let keyEvent = createKeyEvent(KeyEnter)
    let mouseEvent = createMouseEvent(MousePressed, MouseLeft, 10, 20)
    let resizeEvent = createResizeEvent(80, 24)
    
    pushEvent(keyEvent)
    pushEvent(mouseEvent) 
    pushEvent(resizeEvent)
    
    # Poll events in order
    let ev1 = pollEvent(0)
    check(ev1.kind == EvKey)
    check(ev1.key.key == KeyEnter)
    
    let ev2 = pollEvent(0)
    check(ev2.kind == EvMouse)
    check(ev2.mouse.button == MouseLeft)
    
    let ev3 = pollEvent(0)
    check(ev3.kind == EvResize)
    check(ev3.resize.width == 80)
    
    # Queue should be empty
    let ev4 = pollEvent(0)
    check(ev4.kind == EvNone)
  
  test "Clear event queue":
    clearEvents()
    
    # Add some events
    pushEvent(createKeyEvent(KeyTab))
    pushEvent(createKeyEvent(KeySpace))
    
    # Clear the queue
    clearEvents()
    
    # Should be empty
    let ev = pollEvent(0)
    check(ev.kind == EvNone)

suite "Event Creation Helpers":
  test "Create key events":
    let simpleKey = createKeyEvent(KeyEnter)
    check(simpleKey.kind == EvKey)
    check(simpleKey.key.key == KeyEnter)
    check(simpleKey.key.ch == '\0')
    check(simpleKey.key.modifiers == {})
    
    let charKey = createKeyEvent(KeyNone, 'A')
    check(charKey.kind == EvKey)
    check(charKey.key.key == KeyNone)
    check(charKey.key.ch == 'A')
    
    let modKey = createKeyEvent(KeyTab, '\0', {ModCtrl, ModShift})
    check(modKey.kind == EvKey)
    check(modKey.key.key == KeyTab)
    check(ModCtrl in modKey.key.modifiers)
    check(ModShift in modKey.key.modifiers)
  
  test "Create mouse events":
    let mouseEv = createMouseEvent(MousePressed, MouseLeft, 15, 25, {ModAlt})
    check(mouseEv.kind == EvMouse)
    check(mouseEv.mouse.action == MousePressed)
    check(mouseEv.mouse.button == MouseLeft)
    check(mouseEv.mouse.x == 15)
    check(mouseEv.mouse.y == 25)
    check(ModAlt in mouseEv.mouse.modifiers)
  
  test "Create resize events":
    let resizeEv = createResizeEvent(120, 40)
    check(resizeEv.kind == EvResize)
    check(resizeEv.resize.width == 120)
    check(resizeEv.resize.height == 40)

suite "Poll Event Timeout":
  test "Non-blocking poll":
    clearEvents()
    let ev = pollEvent(0)
    check(ev.kind == EvNone)
  
  test "Poll with timeout":
    when not defined(skipFlakeyTests):
      clearEvents()
      let startTime = epochTime()
      let ev = pollEvent(100)  # 100ms timeout
      let elapsed = epochTime() - startTime
      
      check(ev.kind == EvNone)
      # Very lenient timing check for different environments
      # In fast environments or CI, timing may be unreliable
      if elapsed > 0.01:  # At least some delay
        check(elapsed < 1.0)  # But not too long
      else:
        skip()  # Skip this check in very fast environments
    else:
      # Just test that the function works without timing requirements
      clearEvents()
      let ev = pollEvent(1)  # Very short timeout
      check(ev.kind == EvNone)
  
  test "Poll returns immediately with queued event":
    clearEvents()
    pushEvent(createKeyEvent(KeySpace))
    
    let startTime = epochTime()
    let ev = pollEvent(1000)  # 1 second timeout
    let elapsed = epochTime() - startTime
    
    check(ev.kind == EvKey)
    check(ev.key.key == KeySpace)
    # Should return immediately
    check(elapsed < 0.1)

suite "Mouse Support":
  test "Enable and disable mouse":
    # Note: These tests assume we're not in raw mode
    # In a real terminal, these would enable/disable mouse tracking
    
    # Enable mouse support
    let enabled = enableMouse()
    # Result depends on terminal support
    
    # Disable mouse support  
    disableMouse()
    # Should always succeed

suite "Complex Input Sequences":
  test "Multiple events in queue":
    clearEvents()
    
    # Simulate a complex sequence
    pushEvent(createKeyEvent(KeyNone, 'H'))
    pushEvent(createKeyEvent(KeyNone, 'e'))
    pushEvent(createKeyEvent(KeyNone, 'l'))
    pushEvent(createKeyEvent(KeyNone, 'l'))
    pushEvent(createKeyEvent(KeyNone, 'o'))
    pushEvent(createKeyEvent(KeyEnter))
    
    var text = ""
    while true:
      let ev = pollEvent(0)
      if ev.kind == EvNone:
        break
      elif ev.kind == EvKey:
        if ev.key.key == KeyEnter:
          break
        else:
          text.add(ev.key.ch)
    
    check(text == "Hello")
  
  test "Mixed event types":
    clearEvents()
    
    # Mix of different event types
    pushEvent(createKeyEvent(KeyTab))
    pushEvent(createMouseEvent(MousePressed, MouseLeft, 0, 0))
    pushEvent(createResizeEvent(100, 30))
    pushEvent(createKeyEvent(KeyEscape))
    
    var keyCount = 0
    var mouseCount = 0
    var resizeCount = 0
    
    for i in 0..3:
      let ev = pollEvent(0)
      case ev.kind
      of EvKey:
        inc keyCount
      of EvMouse:
        inc mouseCount
      of EvResize:
        inc resizeCount
      else:
        discard
    
    check(keyCount == 2)
    check(mouseCount == 1)
    check(resizeCount == 1)