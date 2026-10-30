# test_all.nim
## Main test suite for the libterminal library

import unittest
import std/unicode
import ../src/libterminal
import ../src/libterminal/private/common

# Import test modules
import "test_signals"
import "test_escape_parser"
import "test_mouse"
import "test_widgets"
import "test_layout"
import "test_databinding"
import "test_shortcuts"
import "test_unicode_utils"
import "test_color_utils"
import "test_output"
import "test_input"
import "test_raw"

# Extended test modules for better coverage
import "test_common"
import "test_async_driver"
import "test_input_extended"
import "test_widget_base_extended"
import "test_output_extended"

when not defined(noAgents):
  import "test_actors"
  import "test_actor_metrics"
import "test_ninep"
import "test_high_level"

when defined(test):
  import ../src/libterminal/private/test_utils
  # Enable test mode before any tests run
  enableTestMode()

suite "Terminal initialization":
  test "Enter and exit raw mode":
    # This test can only verify that the calls don't throw exceptions
    # since we can't easily verify the terminal state in automated tests
    when defined(test):
      setMockTerminalSize(80, 24)
    check(raw.enterRawMode())
    check(raw.isRawModeEnabled())
    check(raw.exitRawMode())
    check(not raw.isRawModeEnabled())
  
  test "Terminal size":
    # Verify that we can get terminal dimensions
    let (width, height) = raw.getTerminalSize()
    check(width > 0)
    check(height > 0)
  
  test "Raw mode flags":
    # Raw mode setup with custom flags
    check(raw.enterRawMode({RawModeDisableOutput, RawModeNoFlowControl}))
    check(raw.isRawModeEnabled())
    check(raw.exitRawMode())
  
  test "Multiple initializations":
    # Multiple initializations (second one is ignored)
    check(raw.enterRawMode())
    check(not raw.enterRawMode())  # Fails because already in raw mode
    check(raw.exitRawMode())

suite "Buffer operations":
  test "Buffer creation":
    let buffer = newBuffer(80, 24)
    check(buffer.width == 80)
    check(buffer.height == 24)
    check(buffer.cells.len == 80 * 24)
  
  test "Buffer cell access":
    var buffer = newBuffer(80, 24)
    
    # Access within bounds
    let style = Style(
      fg: ColorRed,
      bg: ColorBlue,
      attrs: {AttrBoldAttr}
    )
    let cell = Cell(ch: Rune('X'), style: style)
    
    buffer[10, 5] = cell
    check(buffer[10, 5].ch == Rune('X'))
    check(buffer[10, 5].style.fg == ColorRed)
    check(buffer[10, 5].style.bg == ColorBlue)
    check(AttrBoldAttr in buffer[10, 5].style.attrs)
    
    # Access out of bounds (should not crash)
    buffer[-1, -1] = cell
    buffer[100, 100] = cell
    
    # Verify original cell was not affected
    check(buffer[10, 5].ch == Rune('X'))
  
  test "Buffer clear":
    var buffer = newBuffer(80, 24)
    buffer[10, 5] = Cell(ch: Rune('X'))
    
    buffer.clear()
    
    check(buffer[10, 5].ch == Rune(' '))
  
  test "Buffer resize":
    var buffer = newBuffer(80, 24)
    buffer[10, 5] = Cell(ch: Rune('X'))
    
    buffer.resize(100, 30)
    
    check(buffer.width == 100)
    check(buffer.height == 30)
    check(buffer[10, 5].ch == Rune('X'))  # Original content should be preserved
    
    buffer.resize(5, 5)
    
    check(buffer.width == 5)
    check(buffer.height == 5)
    # Cell at 10,5 is now out of bounds

suite "Text operations":
  test "Print text to buffer":
    var buffer = newBuffer(80, 24)
    
    let style = Style(
      fg: ColorGreen,
      bg: ColorDefault,
      attrs: {AttrBoldAttr}
    )
    
    buffer.print(5, 10, "Hello", style)
    
    check(buffer[5, 10].ch == Rune('H'))
    check(buffer[6, 10].ch == Rune('e'))
    check(buffer[7, 10].ch == Rune('l'))
    check(buffer[8, 10].ch == Rune('l'))
    check(buffer[9, 10].ch == Rune('o'))
    
    for i in 5..9:
      check(buffer[i, 10].style.fg == ColorGreen)
      check(AttrBoldAttr in buffer[i, 10].style.attrs)
  
  test "Print with default style":
    var buffer = newBuffer(80, 24)
    
    buffer.print(5, 10, "Hello")
    
    check(buffer[5, 10].ch == Rune('H'))
    check(buffer[5, 10].style.fg == ColorDefault)
    check(buffer[5, 10].style.bg == ColorDefault)
    check(buffer[5, 10].style.attrs == {})

suite "Input handling":
  test "Event queue":
    # Clear the event queue first
    input.clearEvents()
    
    # Create test events
    let keyEvent = Event(
      kind: EvKey,
      key: KeyEvent(key: KeyEnter)
    )
    
    let mouseEvent = Event(
      kind: EvMouse,
      mouse: MouseEvent(
        action: MousePressed,
        button: MouseLeft,
        x: 10,
        y: 20
      )
    )
    
    # Push events to the queue
    input.pushEvent(keyEvent)
    input.pushEvent(mouseEvent)
    
    # Poll events and verify
    let evt1 = input.pollEvent(0)
    check(evt1.kind == EvKey)
    check(evt1.key.key == KeyEnter)
    
    let evt2 = input.pollEvent(0)
    check(evt2.kind == EvMouse)
    check(evt2.mouse.action == MousePressed)
    check(evt2.mouse.button == MouseLeft)
    check(evt2.mouse.x == 10)
    check(evt2.mouse.y == 20)
    
    # Queue should be empty now
    let evt3 = input.pollEvent(0)
    check(evt3.kind == EvNone)
  
  test "Mouse enable/disable":
    # Application-level mouse control
    var term = newTerminal()
    term.init()
    
    # Enable mouse
    let mouseEnabled = term.enableMouse()
    
    # Mouse support may not be available in some environments
    if mouseEnabled:
      check(term.isMouseEnabled())
      
      # Disable mouse
      term.disableMouse()
      check(not term.isMouseEnabled())
    
    term.shutdown()