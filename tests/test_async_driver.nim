# test_async_driver.nim
## Tests for async driver functionality

import unittest
import std/[asyncdispatch, options]
import ../src/libterminal/async/driver as asyncdriver
import ../src/libterminal/private/common
import ../src/libterminal/output

suite "Async Driver Creation":
  test "Create headless driver":
    let driver = newAsyncDriver(dkHeadless)
    check(driver != nil)
    check(driver.kind == dkHeadless)
  
  test "Create platform-specific driver":
    when defined(windows):
      let driver = newAsyncDriver(dkWindows)
      check(driver.kind == dkWindows)
    else:
      let driver = newAsyncDriver(dkLinux)
      check(driver.kind == dkLinux)

suite "Async Driver Operations":
  test "Write text":
    proc testWrite() {.async.} =
      let driver = newAsyncDriver(dkHeadless)
      let style = Style(
        fg: ColorRed,
        bg: ColorDefault,
        attrs: {},
        focusFg: ColorDefault,
        focusBg: ColorDefault,
        disabledFg: ColorDefault,
        disabledBg: ColorDefault,
        selectedFg: ColorDefault,
        selectedBg: ColorDefault,
        secondaryFg: ColorDefault,
        secondaryBg: ColorDefault
      )
      await driver.write(5, 10, "Hello", style)
      # Headless driver should handle this without error
    
    waitFor testWrite()
  
  test "Clear screen":
    proc testClear() {.async.} =
      let driver = newAsyncDriver(dkHeadless)
      await driver.clear()
      # Headless driver should handle this without error
    
    waitFor testClear()
  
  test "Flush output":
    proc testFlush() {.async.} =
      let driver = newAsyncDriver(dkHeadless)
      await driver.flush()
      # Headless driver should handle this without error
    
    waitFor testFlush()

suite "Async Driver Event Reading":
  test "Read event from headless driver":
    proc testReadEvent() {.async.} =
      let driver = newAsyncDriver(dkHeadless)
      
      # Headless driver returns None by default
      let event = await driver.readEvent()
      check(event.isNone)
    
    waitFor testReadEvent()
  
  test "Convert key event":
    proc testKeyEvent() {.async.} =
      let driver = newAsyncDriver(dkHeadless)
      
      # Test the event conversion functionality
      # Create a sample key event
      let keyEvent = asyncdriver.Event(
        kind: ekKey,
        key: KeyEvent(
          key: KeyEnter,
          ch: '\0',
          modifiers: {ModCtrl}
        )
      )
      
      # Check that event structure is correct
      check(keyEvent.kind == ekKey)
      check(keyEvent.key.key == KeyEnter)
      check(keyEvent.key.ch == '\0')
      check(ModCtrl in keyEvent.key.modifiers)
    
    waitFor testKeyEvent()
  
  test "Convert mouse event":
    proc testMouseEvent() {.async.} =
      let driver = newAsyncDriver(dkHeadless)
      
      # Test mouse event structure
      let mouseEvent = asyncdriver.Event(
        kind: ekMouse,
        mouse: MouseEvent(
          x: 10,
          y: 20,
          button: MouseLeft,
          action: MousePressed,
          modifiers: {}
        )
      )
      
      check(mouseEvent.kind == ekMouse)
      check(mouseEvent.mouse.x == 10)
      check(mouseEvent.mouse.y == 20)
      check(mouseEvent.mouse.button == MouseLeft)
      check(mouseEvent.mouse.action == MousePressed)
    
    waitFor testMouseEvent()
  
  test "Convert resize event":
    proc testResizeEvent() {.async.} =
      let driver = newAsyncDriver(dkHeadless)
      
      # Test resize event structure
      let resizeEvent = asyncdriver.Event(
        kind: ekResize,
        width: 100,
        height: 40
      )
      
      check(resizeEvent.kind == ekResize)
      check(resizeEvent.width == 100)
      check(resizeEvent.height == 40)
    
    waitFor testResizeEvent()

suite "Async Driver Error Handling":
  test "Handle invalid operations":
    proc testInvalidOps() {.async.} =
      let driver = newAsyncDriver(dkHeadless)
      
      # Create a default style
      let style = Style(
        fg: ColorDefault,
        bg: ColorDefault,
        attrs: {},
        focusFg: ColorDefault,
        focusBg: ColorDefault,
        disabledFg: ColorDefault,
        disabledBg: ColorDefault,
        selectedFg: ColorDefault,
        selectedBg: ColorDefault,
        secondaryFg: ColorDefault,
        secondaryBg: ColorDefault
      )
      
      # Write at invalid position (should not crash)
      await driver.write(-1, -1, "Test", style)
      await driver.write(1000, 1000, "Test", style)
      
      # Empty string
      await driver.write(0, 0, "", style)
      
      # Multiple clears
      await driver.clear()
      await driver.clear()
      
      # Multiple flushes
      await driver.flush()
      await driver.flush()
    
    waitFor testInvalidOps()