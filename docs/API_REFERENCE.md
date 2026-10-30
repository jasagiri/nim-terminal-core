# nim-libterminal API Reference

Version: 0.5.0

## Overview

nim-libterminal is a production-ready Nim library for terminal manipulation, offering comprehensive Unicode support, efficient differential drawing, and robust error handling. This library provides both low-level terminal control and high-level widget abstractions.

## Quick Start

```nim
import libterminal

# Simple terminal usage
withTerminal:
  clearScreen()
  hideCursor()
  stdout.setCursorPos(10, 5)
  stdout.write("Hello, Terminal!")
  showCursor()

# With mouse support
withMouseTerminal:
  let event = pollEvent(1000)  # 1 second timeout
  if event.kind == EvMouse:
    echo fmt"Mouse clicked at ({event.mouse.x}, {event.mouse.y})"
```

## Core Modules

### libterminal (Main Module)

The main entry point that exports all essential functionality.

#### Terminal Object

```nim
type Terminal* = object
```

Main terminal object that encapsulates terminal state.

**Methods:**

- `newTerminal*(): Terminal` - Creates a new Terminal object
- `init*(term: var Terminal)` - Initializes terminal in raw mode
- `init*(term: var Terminal, enableMouse: bool)` - Initializes with optional mouse support
- `shutdown*(term: var Terminal)` - Restores terminal to original state
- `enableMouse*(term: var Terminal): bool` - Enables mouse support
- `disableMouse*(term: var Terminal)` - Disables mouse support
- `isRawMode*(term: Terminal): bool` - Returns raw mode status
- `isMouseEnabled*(term: Terminal): bool` - Returns mouse support status
- `getDimensions*(term: Terminal): tuple[width: int, height: int]` - Gets terminal size
- `updateDimensions*(term: var Terminal)` - Updates cached terminal size

#### Convenience Templates

```nim
template withTerminal*(body: untyped)
template withMouseTerminal*(body: untyped)
```

Safe terminal initialization with automatic cleanup.

### raw - Low-Level Terminal Control

#### Types

```nim
type
  TerminalError* = object of CatchableError
  RawModeFlag* = enum
    RawModeDisableOutput
    RawModeNoSignalProcessing
    RawModeNoFlowControl
    RawModeDisableNewline
    RawModeMinimalMode
```

#### Functions

- `enterRawMode*(): bool` - Enters raw mode
- `enterRawMode*(flags: set[RawModeFlag]): bool` - Enters raw mode with specific flags
- `exitRawMode*(): bool` - Exits raw mode
- `isRawModeActive*(): bool` - Checks if raw mode is active
- `getTerminalSize*(): tuple[width: int, height: int]` - Gets current terminal size
- `terminalWidth*(): int` - Gets terminal width
- `terminalHeight*(): int` - Gets terminal height

### input - Input Processing

#### Types

```nim
type
  Key* = enum
    KeyNone, KeyEnter, KeyEscape, KeyBackspace, KeyTab, KeySpace,
    KeyUp, KeyDown, KeyLeft, KeyRight, KeyHome, KeyEnd,
    KeyPageUp, KeyPageDown, KeyInsert, KeyDelete,
    KeyF1, KeyF2, KeyF3, KeyF4, KeyF5, KeyF6,
    KeyF7, KeyF8, KeyF9, KeyF10, KeyF11, KeyF12
  
  KeyModifier* = enum
    ModShift, ModCtrl, ModAlt, ModMeta
  
  KeyEvent* = object
    key*: Key
    ch*: char
    modifiers*: set[KeyModifier]
  
  MouseButton* = enum
    MouseLeft, MouseMiddle, MouseRight, MouseWheelUp, MouseWheelDown
  
  MouseAction* = enum
    MousePressed, MouseReleased, MouseMoved, MouseDragged
  
  MouseEvent* = object
    button*: MouseButton
    action*: MouseAction
    x*, y*: int
    modifiers*: set[KeyModifier]
  
  Event* = object
    case kind*: EventKind
    of EvKey: key*: KeyEvent
    of EvMouse: mouse*: MouseEvent
    of EvResize: width*, height*: int
    of EvNone: discard
```

#### Functions

- `pollEvent*(): Event` - Polls for an input event (non-blocking)
- `pollEvent*(timeout: int): Event` - Polls with timeout in milliseconds
- `pushEvent*(event: Event)` - Pushes an event to the queue (for testing)
- `clearEvents*()` - Clears the event queue
- `enableMouse*(): bool` - Enables mouse tracking
- `disableMouse*()` - Disables mouse tracking
- `createKeyEvent*(key: Key, ch: char = '\0', modifiers: set[KeyModifier] = {}): Event`
- `createMouseEvent*(action: MouseAction, button: MouseButton, x, y: int): Event`
- `createResizeEvent*(width, height: int): Event`

### output - Output and Drawing

#### Types

```nim
type
  Color* = enum
    ColorDefault, ColorBlack, ColorRed, ColorGreen, ColorYellow,
    ColorBlue, ColorMagenta, ColorCyan, ColorWhite
  
  Attribute* = enum
    AttrBold, AttrDim, AttrItalic, AttrUnderline, AttrBlink,
    AttrReverse, AttrStrikethrough
  
  Style* = object
    fg*: Color
    bg*: Color
    attrs*: set[Attribute]
  
  Buffer* = ref object
  
  ColorMode* = enum
    ColorModeNone, ColorModeBasic, ColorMode256, ColorModeTrueColor
```

#### Buffer Operations

- `newBuffer*(width, height: int): Buffer` - Creates a new buffer
- `getCell*(buffer: Buffer, x, y: int): tuple[ch: string, style: Style]`
- `setCell*(buffer: Buffer, x, y: int, ch: string, style: Style)`
- `clear*(buffer: Buffer)` - Clears the buffer
- `resize*(buffer: Buffer, width, height: int)` - Resizes buffer
- `drawBuffer*(buffer: Buffer)` - Draws buffer to terminal with differential updates

#### Text Output

- `print*(buffer: Buffer, x, y: int, text: string, style: Style = defaultStyle())`
- `printAdvanced*(buffer: Buffer, x, y: int, text: string, style: Style, options: PrintOptions)`
- `setCursorPos*(x, y: int)` - Sets cursor position
- `hideCursor*()` - Hides cursor
- `showCursor*()` - Shows cursor
- `clearScreen*()` - Clears entire screen
- `clearLine*()` - Clears current line

#### Color Support

- `setColorMode*(mode: ColorMode)` - Sets color mode
- `getColorMode*(): ColorMode` - Gets current color mode
- `supportsColor*(): bool` - Checks if terminal supports color
- `rgbColor*(r, g, b: int): Color` - Creates RGB color (24-bit)
- `color256*(index: int): Color` - Creates 256-color palette color

### widgets - Widget System

#### Base Widget

```nim
type
  Widget* = ref object of RootObj
    rect*: Rect
    visible*: bool
    enabled*: bool
    focused*: bool
    parent*: Widget
    children*: seq[Widget]
```

**Common Methods:**

- `newWidget*(): Widget` - Creates base widget
- `addChild*(parent, child: Widget)` - Adds child widget
- `removeChild*(parent, child: Widget)` - Removes child widget
- `setRect*(widget: Widget, rect: Rect)` - Sets widget bounds
- `handleEvent*(widget: Widget, event: Event): bool` - Handles input events
- `render*(widget: Widget, buffer: Buffer)` - Renders widget to buffer

#### Specific Widgets

**Label**
```nim
type Label* = ref object of Widget
  text*: string
  textAlign*: TextAlign

proc newLabel*(text: string): Label
```

**Button**
```nim
type Button* = ref object of Widget
  text*: string
  onClick*: proc()

proc newButton*(text: string, onClick: proc() = nil): Button
```

**TextInput**
```nim
type TextInput* = ref object of Widget
  text*: string
  placeholder*: string
  maxLength*: int

proc newTextInput*(placeholder: string = ""): TextInput
```

**ProgressBar**
```nim
type ProgressBar* = ref object of Widget
  value*: float  # 0.0 to 1.0
  showText*: bool

proc newProgressBar*(showText: bool = true): ProgressBar
```

### layout - Layout System

#### Types

```nim
type
  LayoutDirection* = enum
    LayoutHorizontal, LayoutVertical
  
  SizeConstraint* = object
    min*, max*, preferred*: int
  
  LayoutNode* = ref object
    direction*: LayoutDirection
    constraints*: SizeConstraint
    children*: seq[LayoutNode]
```

#### Functions

- `newLayoutNode*(direction: LayoutDirection): LayoutNode`
- `addChild*(node: LayoutNode, child: LayoutNode)`
- `calculateLayout*(node: LayoutNode, availableRect: Rect)`

### Unicode Support

#### Functions

- `displayWidth*(text: string): int` - Gets display width accounting for wide characters
- `graphemeLength*(text: string): int` - Gets number of grapheme clusters
- `splitIntoGraphemeClusters*(text: string): seq[string]`
- `getTextDirection*(text: string): TextDirection` - Detects text direction (LTR/RTL)
- `splitLines*(text: string, maxWidth: int, mode: LineWrapMode): seq[string]`
- `isWordBoundary*(text: string, pos: int): bool`
- `visualPosToLogical*(text: string, visualPos: int): int`
- `logicalPosToVisual*(text: string, logicalPos: int): int`

## Error Handling

### Error Types

```nim
type
  LibTerminalError* = object of CatchableError
    component*: string
    errorCode*: TerminalErrorCode
    recoverable*: bool
  
  TerminalErrorCode* = enum
    TecUnknown, TecRawModeFailure, TecTerminalNotSupported,
    TecMouseNotSupported, TecInvalidTerminalSize,
    TecSignalHandlingFailure, TecBufferOverflow,
    TecInvalidInput, TecResourceExhausted,
    TecPermissionDenied, TecConfigurationError
```

### Result Types

```nim
type TerminalResult*[T] = object
  case success*: bool
  of true: value*: T
  of false: error*: ref LibTerminalError

proc ok*[T](value: T): TerminalResult[T]
proc err*[T](error: ref LibTerminalError): TerminalResult[T]
proc isOk*[T](result: TerminalResult[T]): bool
proc get*[T](result: TerminalResult[T]): T  # Raises on error
proc getOr*[T](result: TerminalResult[T], default: T): T
```

### Safe Execution

```nim
template withErrorHandling*(body: untyped): untyped
```

Automatically handles errors with appropriate recovery strategies.

## Logging

### Configuration

```nim
proc initTerminalLogging*(level: Level = lvlInfo, logFile: string = ""): LibTerminalLogger
```

### Logging Functions

```nim
proc logDebug*(msg: string, component: string = "TERMINAL")
proc logInfo*(msg: string, component: string = "TERMINAL")
proc logWarn*(msg: string, component: string = "TERMINAL")
proc logError*(msg: string, component: string = "TERMINAL")
proc logFatal*(msg: string, component: string = "TERMINAL")
```

### Specialized Logging

```nim
proc logRawModeChange*(entering: bool, success: bool)
proc logMouseEvent*(enabled: bool, success: bool)
proc logTerminalSize*(width, height: int)
proc logSignalReceived*(signalName: string)
proc logPerformanceMetric*(operation: string, duration: float)
```

## Configuration

### Configuration Object

```nim
type TerminalConfig* = ref object
  # Core settings
  enableLogging*: bool
  logLevel*: string
  logFile*: string
  
  # Terminal behavior
  rawModeFlags*: set[RawModeFlag]
  mouseSupport*: bool
  unicodeSupport*: bool
  colorSupport*: ColorSupportLevel
  
  # Performance settings
  bufferSize*: int
  maxBufferHistory*: int
  enableDifferentialUpdates*: bool
  refreshRate*: int
  
  # Error handling
  retryAttempts*: int
  retryDelay*: int
  enableRecovery*: bool
```

### Configuration Functions

```nim
proc getConfig*(): TerminalConfig
proc loadFromEnv*(config: TerminalConfig)
proc loadFromFile*(config: TerminalConfig, filename: string): bool
proc applyConfig*(config: TerminalConfig): bool
proc enableFeature*(feature: string, enabled: bool = true)
proc isFeatureEnabled*(feature: string): bool
```

## Environment Variables

The library supports configuration via environment variables:

- `LIBTERMINAL_ENABLE_LOGGING`: Enable/disable logging
- `LIBTERMINAL_LOG_LEVEL`: Set log level (DEBUG, INFO, WARN, ERROR, FATAL)
- `LIBTERMINAL_LOG_FILE`: Log file path
- `LIBTERMINAL_MOUSE_SUPPORT`: Enable/disable mouse support
- `LIBTERMINAL_UNICODE_SUPPORT`: Enable/disable Unicode support
- `LIBTERMINAL_COLOR_SUPPORT`: Color support level (none, basic, 256, truecolor)
- `LIBTERMINAL_BUFFER_SIZE`: Buffer size in bytes
- `LIBTERMINAL_REFRESH_RATE`: Screen refresh rate in Hz
- `LIBTERMINAL_RETRY_ATTEMPTS`: Number of retry attempts for failed operations
- `LIBTERMINAL_RETRY_DELAY`: Delay between retries in milliseconds

## Examples

### Basic Terminal App

```nim
import libterminal

proc main() =
  var term = newTerminal()
  try:
    term.init(enableMouse = true)
    
    let (width, height) = term.getDimensions()
    var buffer = newBuffer(width, height)
    
    buffer.print(width div 2 - 5, height div 2, "Hello World!",
                Style(fg: ColorGreen, bg: ColorDefault, attrs: {AttrBold}))
    
    buffer.drawBuffer()
    
    while true:
      let event = pollEvent(1000)
      case event.kind
      of EvKey:
        if event.key.key == KeyEscape:
          break
      of EvMouse:
        buffer.print(event.mouse.x, event.mouse.y, "•",
                    Style(fg: ColorRed, bg: ColorDefault))
        buffer.drawBuffer()
      else:
        discard
        
  finally:
    term.shutdown()

when isMainModule:
  main()
```

### Widget-Based App

```nim
import libterminal

proc createUI(): Widget =
  let root = newWidget()
  root.setRect(Rect(x: 0, y: 0, width: 80, height: 24))
  
  let title = newLabel("My Application")
  title.setRect(Rect(x: 30, y: 2, width: 20, height: 1))
  root.addChild(title)
  
  let button = newButton("Click Me", proc() = echo "Button clicked!")
  button.setRect(Rect(x: 35, y: 10, width: 10, height: 3))
  root.addChild(button)
  
  let input = newTextInput("Enter text...")
  input.setRect(Rect(x: 20, y: 15, width: 40, height: 1))
  root.addChild(input)
  
  return root

proc main() =
  withMouseTerminal:
    let ui = createUI()
    let (width, height) = terminalSize()
    var buffer = newBuffer(width, height)
    
    while true:
      # Clear and render
      buffer.clear()
      ui.render(buffer)
      buffer.drawBuffer()
      
      # Handle events
      let event = pollEvent(16)  # ~60 FPS
      if event.kind != EvNone:
        if ui.handleEvent(event):
          continue
        if event.kind == EvKey and event.key.key == KeyEscape:
          break

when isMainModule:
  main()
```

## Performance Tips

1. **Use Differential Updates**: Enable `enableDifferentialUpdates` for efficient screen updates
2. **Buffer Management**: Reuse buffers instead of creating new ones each frame
3. **Event Batching**: Process multiple events in a single frame for better responsiveness
4. **Unicode Optimization**: Cache grapheme cluster calculations for frequently displayed text
5. **Color Mode**: Use appropriate color mode for the target terminal
6. **Logging**: Disable debug logging in production builds

## Thread Safety

nim-libterminal is **not thread-safe**. All operations should be performed from a single thread. If you need to communicate with the terminal from multiple threads, use message passing to coordinate access.

## Platform Support

- **Linux**: Full support with all features
- **macOS**: Full support with all features  
- **Windows**: Basic support (some advanced features may be limited)
- **WASI**: Limited support for headless operations

## Version History

- **0.5.0**: Production release with enhanced error handling, logging, and configuration
- **0.1.0**: Initial development release