# test_input.nim
## Comprehensive test suite for the input module

import unittest
import std/posix
import std/options
import ../src/libterminal/private/common
import ../src/libterminal/private/signals
import ../src/libterminal/private/escape_parser
import ../src/libterminal/raw
import ../src/libterminal/mouse
import ../src/libterminal/input

suite "Event creation":
  test "Key event creation":
    # Basic key event
    let keyEvent = createKeyEvent(KeyEnter)
    check(keyEvent.kind == EvKey)
    check(keyEvent.key.key == KeyEnter)
    check(keyEvent.key.ch == '\0')
    check(keyEvent.key.modifiers == {})
    
    # Key event with character
    let charEvent = createKeyEvent(KeyNone, 'a')
    check(charEvent.kind == EvKey)
    check(charEvent.key.key == KeyNone)
    check(charEvent.key.ch == 'a')
    check(charEvent.key.modifiers == {})
    
    # Key event with modifiers
    let modEvent = createKeyEvent(KeyTab, '\0', {ModShift, ModCtrl})
    check(modEvent.kind == EvKey)
    check(modEvent.key.key == KeyTab)
    check(modEvent.key.modifiers == {ModShift, ModCtrl})
  
  test "Resize event creation":
    let resizeEvent = createResizeEvent(80, 24)
    check(resizeEvent.kind == EvResize)
    check(resizeEvent.resize.width == 80)
    check(resizeEvent.resize.height == 24)
  
  test "Mouse event creation":
    let mouseEvent = createMouseEvent(MousePressed, MouseLeft, 10, 20)
    check(mouseEvent.kind == EvMouse)
    check(mouseEvent.mouse.action == MousePressed)
    check(mouseEvent.mouse.button == MouseLeft)
    check(mouseEvent.mouse.x == 10)
    check(mouseEvent.mouse.y == 20)
    check(mouseEvent.mouse.modifiers == {})
    
    # Mouse event with modifiers
    let modMouseEvent = createMouseEvent(MouseDragged, MouseRight, 15, 25, {ModShift})
    check(modMouseEvent.kind == EvMouse)
    check(modMouseEvent.mouse.action == MouseDragged)
    check(modMouseEvent.mouse.button == MouseRight)
    check(modMouseEvent.mouse.x == 15)
    check(modMouseEvent.mouse.y == 25)
    check(modMouseEvent.mouse.modifiers == {ModShift})

suite "Event queue":
  test "Queue operations":
    # Clear the event queue
    clearEvents()
    
    # Create test events
    let keyEvent = createKeyEvent(KeyEnter)
    let mouseEvent = createMouseEvent(MousePressed, MouseLeft, 10, 20)
    
    # Push events to the queue
    pushEvent(keyEvent)
    pushEvent(mouseEvent)
    
    # Poll events and verify
    let evt1 = pollEvent(0)
    check(evt1.kind == EvKey)
    check(evt1.key.key == KeyEnter)
    
    let evt2 = pollEvent(0)
    check(evt2.kind == EvMouse)
    check(evt2.mouse.action == MousePressed)
    check(evt2.mouse.button == MouseLeft)
    check(evt2.mouse.x == 10)
    check(evt2.mouse.y == 20)
    
    # Queue should be empty now
    let evt3 = pollEvent(0)
    check(evt3.kind == EvNone)
    
    # Test clearing events
    pushEvent(keyEvent)
    clearEvents()
    let evt4 = pollEvent(0)
    check(evt4.kind == EvNone)

suite "Escape sequence parsing":
  test "Basic escape sequence to key event":
    # Prepare an escape sequence for the Up arrow key
    var escBuffer: array[3, char]
    escBuffer[0] = '\e'
    escBuffer[1] = '['
    escBuffer[2] = 'A'
    
    let evt = parseEscapeSequence(escBuffer, 3)
    check(evt.kind == EvKey)
    check(evt.key.key == KeyUp)
  
  test "Function keys":
    # F1 key
    var f1Buffer: array[3, char]
    f1Buffer[0] = '\e'
    f1Buffer[1] = '['
    f1Buffer[2] = 'P'  # or could be O depending on terminal
    
    let f1Event = parseEscapeSequence(f1Buffer, 3)
    check(f1Event.kind == EvKey)
    check(f1Event.key.key == KeyF1)
    
    # F5 key
    var f5Buffer: array[5, char]
    f5Buffer[0] = '\e'
    f5Buffer[1] = '['
    f5Buffer[2] = '1'
    f5Buffer[3] = '5'
    f5Buffer[4] = '~'
    
    let f5Event = parseEscapeSequence(f5Buffer, 5)
    check(f5Event.kind == EvKey)
    check(f5Event.key.key == KeyF5)
  
  test "Mouse escape sequence to mouse event":
    # SGR format mouse click at position (10,10)
    var mouseBuffer: array[11, char]
    mouseBuffer[0] = '\e'
    mouseBuffer[1] = '['
    mouseBuffer[2] = '<'
    mouseBuffer[3] = '0'
    mouseBuffer[4] = ';'
    mouseBuffer[5] = '1'
    mouseBuffer[6] = '0'
    mouseBuffer[7] = ';'
    mouseBuffer[8] = '1'
    mouseBuffer[9] = '0'
    mouseBuffer[10] = 'M'
    
    let mouseEvent = parseEscapeSequence(mouseBuffer, 11)
    check(mouseEvent.kind == EvMouse)
    check(mouseEvent.mouse.action == MousePressed)
    check(mouseEvent.mouse.button == MouseLeft)
    check(mouseEvent.mouse.x == 9)  # 0-based in the event (10-1)
    check(mouseEvent.mouse.y == 9)  # 0-based in the event (10-1)
  
  test "Invalid or empty escape sequence":
    # Just an escape character
    var escChar: array[1, char]
    escChar[0] = '\e'
    
    let escEvent = parseEscapeSequence(escChar, 1)
    check(escEvent.kind == EvKey)
    check(escEvent.key.key == KeyEscape)
    
    # Invalid sequence
    var invalidBuffer: array[3, char]
    invalidBuffer[0] = '\e'
    invalidBuffer[1] = '?'
    invalidBuffer[2] = '?'
    
    let invalidEvent = parseEscapeSequence(invalidBuffer, 3)
    check(invalidEvent.kind == EvNone)

suite "Signal handling":
  # These tests are more difficult to test directly since they interact
  # with the OS signal handling. We'll test the helper functions.

  test "Signal event detection":
    # Reset signal state
    clearSignalEvents()
    
    # No signal should be detected
    let noEvent = checkSignalEvents()
    check(noEvent.isNone)
    
    # We can't easily trigger real signals in a test, but we can simulate
    # the signal event detection by manually setting the signal flag
    setSignalFlag(SigWinch)
    
    # Now a resize event should be detected
    let resizeEvent = checkSignalEvents()
    check(resizeEvent.isSome)
    let evt = resizeEvent.get()
    check(evt.kind == EvResize)
    
    # After processing, flag should be cleared
    let afterEvent = checkSignalEvents()
    check(afterEvent.isNone)

suite "Mouse handling":
  test "Mouse mode detection":
    # Default state
    let initialState = isMouseEnabled()
    
    # Enable mouse mode if supported
    let enableResult = enableMouse()
    
    # If mouse mode can be enabled, check that it worked
    if enableResult:
      check(isMouseEnabled())
      disableMouse()
      check(not isMouseEnabled())
    else:
      # If mouse mode couldn't be enabled, that's fine for tests
      # as some environments don't support it
      check(not isMouseEnabled())

suite "Key processing":
  # These tests are limited since we can't easily simulate actual keyboard input
  # without changing the code structure, but we can test some aspects

  test "ASCII key handling":
    # Convert character to key event (simulation, not using real input)
    let aEvent = createKeyEvent(KeyNone, 'a')
    check(aEvent.kind == EvKey)
    check(aEvent.key.ch == 'a')
    check(aEvent.key.key == KeyNone)
    
    # Special keys
    let enterEvent = createKeyEvent(KeyEnter)
    check(enterEvent.kind == EvKey)
    check(enterEvent.key.key == KeyEnter)
    
    let escEvent = createKeyEvent(KeyEscape)
    check(escEvent.kind == EvKey)
    check(escEvent.key.key == KeyEscape)
  
  test "Control key handling":
    # Ctrl+A (simulated)
    let ctrlAEvent = createKeyEvent(KeyNone, 'A', {ModCtrl})
    check(ctrlAEvent.kind == EvKey)
    check(ctrlAEvent.key.ch == 'A')
    check(ctrlAEvent.key.modifiers == {ModCtrl})
    
    # Ctrl+C (handled via signal)
    let ctrlCEvent = createKeyEvent(KeyNone, char(3), {ModCtrl})
    check(ctrlCEvent.kind == EvKey)
    check(ctrlCEvent.key.modifiers == {ModCtrl})
    check(ord(ctrlCEvent.key.ch) == 3)  # ASCII ETX (End of Text)

suite "Event handling":
  test "Input functions interface check":
    # Ensure the functions exist and have the right signature
    # This doesn't test actual functionality, just structure
    
    # Check readInput function exists
    when not compiles(readInput()):
      check(false)  # Should never happen if function exists
    
    # Check pollEvent function exists
    when not compiles(pollEvent(0)):
      check(false)
    
    # Check clearEvents and pushEvent exist
    when not compiles(clearEvents()):
      check(false)
    
    when not compiles(pushEvent(Event(kind: EvNone))):
      check(false)
    
    check(true)  # If we got here, functions exist with correct signatures