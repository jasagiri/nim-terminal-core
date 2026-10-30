# test_common.nim
## Tests for common types and constants

import unittest
import ../src/libterminal/private/common

suite "Common types and constants":
  test "ANSI control sequences":
    check(CSI == "\e[")
    
  test "Cursor movement sequences":
    check(CursorUp(5) == "\e[5A")
    check(CursorDown(3) == "\e[3B")
    check(CursorForward(2) == "\e[2C")
    check(CursorBackward(1) == "\e[1D")
    check(CursorPosition(10, 20) == "\e[10;20H")
    
  test "Cursor visibility":
    check(CursorShow == "\e[?25h")
    check(CursorHide == "\e[?25l")
    check(CursorSavePosition == "\e[s")
    check(CursorRestorePosition == "\e[u")
    
  test "Clear sequences":
    check(EraseDisplay == "\e[2J")
    check(EraseLine == "\e[K")
    
  test "Foreground colors":
    check(FgBlack == "\e[30m")
    check(FgRed == "\e[31m")
    check(FgGreen == "\e[32m")
    check(FgYellow == "\e[33m")
    check(FgBlue == "\e[34m")
    check(FgMagenta == "\e[35m")
    check(FgCyan == "\e[36m")
    check(FgWhite == "\e[37m")
    check(FgDefault == "\e[39m")
    
  test "Background colors":
    check(BgBlack == "\e[40m")
    check(BgRed == "\e[41m")
    check(BgGreen == "\e[42m")
    check(BgYellow == "\e[43m")
    check(BgBlue == "\e[44m")
    check(BgMagenta == "\e[45m")
    check(BgCyan == "\e[46m")
    check(BgWhite == "\e[47m")
    check(BgDefault == "\e[49m")
    
  test "Text attributes":
    check(AttrReset == "\e[0m")
    check(AttrBold == "\e[1m")
    check(AttrDim == "\e[2m")
    check(AttrItalic == "\e[3m")
    check(AttrUnderline == "\e[4m")
    check(AttrBlink == "\e[5m")
    check(AttrReverse == "\e[7m")
    check(AttrHidden == "\e[8m")
    check(AttrStrikethrough == "\e[9m")

suite "Key types":
  test "Key enum values":
    check(ord(KeyNone) == 0)
    check(ord(KeyTab) > ord(KeyNone))
    check(ord(KeyEnter) > ord(KeyNone))
    check(ord(KeyEscape) > ord(KeyNone))
    
  test "KeyModifier enum":
    check(ModNone in {ModNone, ModCtrl, ModAlt, ModShift})
    check(ModCtrl in {ModNone, ModCtrl, ModAlt, ModShift})
    check(ModAlt in {ModNone, ModCtrl, ModAlt, ModShift})
    check(ModShift in {ModNone, ModCtrl, ModAlt, ModShift})
    
  test "KeyEvent construction":
    let simpleKey = KeyEvent(key: KeyEnter, ch: '\0', modifiers: {})
    check(simpleKey.key == KeyEnter)
    check(simpleKey.ch == '\0')
    check(simpleKey.modifiers == {})
    
    let charKey = KeyEvent(key: KeyNone, ch: 'a', modifiers: {})
    check(charKey.key == KeyNone)
    check(charKey.ch == 'a')
    
    let modKey = KeyEvent(key: KeyTab, ch: '\0', modifiers: {ModShift})
    check(modKey.key == KeyTab)
    check(ModShift in modKey.modifiers)

suite "Mouse types":
  test "MouseButton enum":
    check(ord(MouseNone) == 0)
    check(ord(MouseLeft) > ord(MouseNone))
    check(ord(MouseMiddle) > ord(MouseNone))
    check(ord(MouseRight) > ord(MouseNone))
    
  test "MouseAction enum":
    check(MousePressed in {MousePressed, MouseReleased, MouseDragged, MouseMoved})
    check(MouseReleased in {MousePressed, MouseReleased, MouseDragged, MouseMoved})
    check(MouseMoved in {MousePressed, MouseReleased, MouseDragged, MouseMoved})
    
  test "MouseEvent construction":
    let event = MouseEvent(
      button: MouseLeft,
      action: MousePressed,
      x: 10,
      y: 20,
      modifiers: {ModShift}
    )
    check(event.button == MouseLeft)
    check(event.action == MousePressed)
    check(event.x == 10)
    check(event.y == 20)
    check(ModShift in event.modifiers)

suite "Event types":
  test "Event variant construction":
    # Key event
    let keyEv = Event(kind: EvKey, key: KeyEvent(key: KeyEnter, ch: '\0', modifiers: {}))
    check(keyEv.kind == EvKey)
    check(keyEv.key.key == KeyEnter)
    
    # Mouse event
    let mouseEv = Event(
      kind: EvMouse,
      mouse: MouseEvent(button: MouseLeft, action: MousePressed, x: 5, y: 10, modifiers: {})
    )
    check(mouseEv.kind == EvMouse)
    check(mouseEv.mouse.button == MouseLeft)
    
    # Resize event
    let resizeEv = Event(kind: EvResize, resize: ResizeEvent(width: 80, height: 24))
    check(resizeEv.kind == EvResize)
    check(resizeEv.resize.width == 80)
    check(resizeEv.resize.height == 24)

suite "Color and style types":
  test "Basic colors":
    check(ord(ColorDefault) == 0)
    check(ord(ColorBlack) > ord(ColorDefault))
    check(ord(ColorRed) > ord(ColorDefault))
    check(ord(ColorGreen) > ord(ColorDefault))
    check(ord(ColorYellow) > ord(ColorDefault))
    check(ord(ColorBlue) > ord(ColorDefault))
    check(ord(ColorMagenta) > ord(ColorDefault))
    check(ord(ColorCyan) > ord(ColorDefault))
    check(ord(ColorWhite) > ord(ColorDefault))
    
  test "Style attributes":
    check(AttrNormal in {AttrNormal, AttrBoldAttr, AttrUnderlineAttr, AttrReverseAttr})
    check(AttrBoldAttr in {AttrNormal, AttrBoldAttr, AttrUnderlineAttr, AttrReverseAttr})
    check(AttrUnderlineAttr in {AttrNormal, AttrBoldAttr, AttrUnderlineAttr, AttrReverseAttr})
    
  test "Style construction":
    let style = Style(
      fg: ColorWhite,
      bg: ColorBlack,
      attrs: {AttrBoldAttr, AttrUnderlineAttr},
      focusFg: ColorDefault,
      focusBg: ColorDefault,
      disabledFg: ColorDefault,
      disabledBg: ColorDefault,
      selectedFg: ColorDefault,
      selectedBg: ColorDefault,
      secondaryFg: ColorDefault,
      secondaryBg: ColorDefault
    )
    check(style.fg == ColorWhite)
    check(style.bg == ColorBlack)
    check(AttrBoldAttr in style.attrs)
    check(AttrUnderlineAttr in style.attrs)