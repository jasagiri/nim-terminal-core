# common.nim
## Common types, constants and utilities used throughout the library
##
## This module contains cross-platform definitions and utilities.

# Define ANSI/VT100 control sequences
const
  CSI* = "\e["  ## Control Sequence Introducer

  # Cursor movement
  CursorUp* = proc(n: int): string = CSI & $n & "A"
  CursorDown* = proc(n: int): string = CSI & $n & "B"
  CursorForward* = proc(n: int): string = CSI & $n & "C"
  CursorBackward* = proc(n: int): string = CSI & $n & "D"
  CursorPosition* = proc(row, col: int): string = CSI & $row & ";" & $col & "H"
  CursorSavePosition* = CSI & "s"
  CursorRestorePosition* = CSI & "u"
  CursorHide* = CSI & "?25l"
  CursorShow* = CSI & "?25h"
  
  # Erase functions
  EraseDisplay* = CSI & "2J"
  EraseLine* = CSI & "K"
  
  # Colors - Foreground
  FgBlack* = CSI & "30m"
  FgRed* = CSI & "31m"
  FgGreen* = CSI & "32m"
  FgYellow* = CSI & "33m"
  FgBlue* = CSI & "34m"
  FgMagenta* = CSI & "35m"
  FgCyan* = CSI & "36m"
  FgWhite* = CSI & "37m"
  FgDefault* = CSI & "39m"
  
  # Colors - Background
  BgBlack* = CSI & "40m"
  BgRed* = CSI & "41m"
  BgGreen* = CSI & "42m"
  BgYellow* = CSI & "43m"
  BgBlue* = CSI & "44m"
  BgMagenta* = CSI & "45m"
  BgCyan* = CSI & "46m"
  BgWhite* = CSI & "47m"
  BgDefault* = CSI & "49m"
  
  # Text attributes
  AttrReset* = CSI & "0m"
  AttrBold* = CSI & "1m"
  AttrDim* = CSI & "2m"
  AttrItalic* = CSI & "3m"
  AttrUnderline* = CSI & "4m"
  AttrBlink* = CSI & "5m"
  AttrReverse* = CSI & "7m"
  AttrHidden* = CSI & "8m"
  AttrStrikethrough* = CSI & "9m"

# Input key definitions
type
  Key* = enum
    # Regular keys
    KeyNone,
    KeyTab, KeyEnter, KeyEscape, KeySpace, KeyBackspace, KeyDelete,
    # Arrow keys
    KeyUp, KeyDown, KeyRight, KeyLeft,
    # Function keys
    KeyF1, KeyF2, KeyF3, KeyF4, KeyF5, KeyF6, 
    KeyF7, KeyF8, KeyF9, KeyF10, KeyF11, KeyF12,
    # Navigation keys
    KeyHome, KeyEnd, KeyPageUp, KeyPageDown, KeyInsert,
    # Regular ASCII characters (represented by their ASCII code)
    # Special handling for Ctrl/Alt combinations

  KeyModifier* = enum
    ModNone, ModCtrl, ModAlt, ModShift

  KeyEvent* = object
    key*: Key
    ch*: char  # For regular character input
    modifiers*: set[KeyModifier]

  EventType* = enum
    EvKey, EvMouse, EvResize, EvNone

  MouseButton* = enum
    MouseNone, MouseLeft, MouseMiddle, MouseRight, MouseWheelUp, MouseWheelDown

  MouseAction* = enum
    MousePressed, MouseReleased, MouseDragged, MouseMoved

  MouseEvent* = object
    action*: MouseAction
    button*: MouseButton
    x*, y*: int
    modifiers*: set[KeyModifier]

  ResizeEvent* = object
    width*, height*: int

  Event* = object
    case kind*: EventType
    of EvKey:
      key*: KeyEvent
    of EvMouse:
      mouse*: MouseEvent
    of EvResize:
      resize*: ResizeEvent
    of EvNone:
      discard

  Color* = enum
    # Basic 16 colors
    ColorDefault, ColorBlack, ColorRed, ColorGreen, ColorYellow,
    ColorBlue, ColorMagenta, ColorCyan, ColorWhite,
    ColorBrightBlack, ColorBrightRed, ColorBrightGreen, ColorBrightYellow,
    ColorBrightBlue, ColorBrightMagenta, ColorBrightCyan, ColorBrightWhite

  Attribute* = enum
    AttrNormal, AttrBoldAttr, AttrDimAttr, AttrItalicAttr, AttrUnderlineAttr,
    AttrBlinkAttr, AttrReverseAttr, AttrHiddenAttr, AttrStrikethroughAttr

  Style* = object
    fg*: Color
    bg*: Color
    attrs*: set[Attribute]
    # Additional color states for widgets
    focusFg*: Color
    focusBg*: Color
    disabledFg*: Color
    disabledBg*: Color
    selectedFg*: Color
    selectedBg*: Color
    secondaryFg*: Color
    secondaryBg*: Color