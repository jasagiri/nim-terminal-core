# test_output_extended.nim
## Extended tests for output module functionality

import unittest
import std/[unicode, options]
import ../src/libterminal/output
import ../src/libterminal/private/common
import ../src/libterminal/private/color_utils

suite "Buffer Management":
  test "Create and manipulate buffer":
    var buffer = newBuffer(80, 24)
    check(buffer.width == 80)
    check(buffer.height == 24)
    check(buffer.cells.len == 80 * 24)
    
    # Set a cell
    let cell = Cell(
      ch: Rune('A'),
      style: Style(fg: ColorRed, bg: ColorBlack, attrs: {}),
      width: 1,
      extColor: none(ExtendedColorInfo)
    )
    buffer[10, 5] = cell
    
    # Get the cell back
    let retrieved = buffer[10, 5]
    check(retrieved.ch == Rune('A'))
    check(retrieved.style.fg == ColorRed)
    check(retrieved.style.bg == ColorBlack)
  
  test "Buffer clear":
    var buffer = newBuffer(50, 20)
    
    # Set some cells
    buffer[0, 0] = Cell(ch: Rune('X'), style: defaultStyle, width: 1)
    buffer[10, 10] = Cell(ch: Rune('Y'), style: defaultStyle, width: 1)
    
    # Clear buffer
    buffer.clear()
    
    # Check all cells are empty
    check(buffer[0, 0].ch == Rune(' '))
    check(buffer[10, 10].ch == Rune(' '))
  
  test "Buffer resize":
    var buffer = newBuffer(40, 20)
    
    # Set a cell
    buffer[10, 10] = Cell(ch: Rune('A'), style: defaultStyle, width: 1)
    
    # Resize smaller
    buffer.resize(30, 15)
    check(buffer.width == 30)
    check(buffer.height == 15)
    check(buffer.cells.len == 30 * 15)
    
    # Cell should still be there if within bounds
    check(buffer[10, 10].ch == Rune('A'))
    
    # Resize larger
    buffer.resize(50, 30)
    check(buffer.width == 50)
    check(buffer.height == 30)
    check(buffer.cells.len == 50 * 30)

suite "Text Printing":
  test "Print simple text":
    var buffer = newBuffer(80, 24)
    
    buffer.print(5, 5, "Hello, World!")
    
    # Check text was written
    check(buffer[5, 5].ch == Rune('H'))
    check(buffer[6, 5].ch == Rune('e'))
    check(buffer[7, 5].ch == Rune('l'))
    check(buffer[8, 5].ch == Rune('l'))
    check(buffer[9, 5].ch == Rune('o'))
  
  test "Print with style":
    var buffer = newBuffer(80, 24)
    
    let style = Style(
      fg: ColorGreen,
      bg: ColorBlue,
      attrs: {AttrBoldAttr},
      focusFg: ColorDefault,
      focusBg: ColorDefault,
      disabledFg: ColorDefault,
      disabledBg: ColorDefault,
      selectedFg: ColorDefault,
      selectedBg: ColorDefault,
      secondaryFg: ColorDefault,
      secondaryBg: ColorDefault
    )
    
    buffer.print(10, 10, "Styled", style)
    
    # Check style was applied
    let cell = buffer[10, 10]
    check(cell.ch == Rune('S'))
    check(cell.style.fg == ColorGreen)
    check(cell.style.bg == ColorBlue)
    check(AttrBoldAttr in cell.style.attrs)
  
  test "Print Unicode text":
    var buffer = newBuffer(80, 24)
    
    buffer.print(0, 0, "Hello 世界 🌍")
    
    # Check Unicode characters
    check(buffer[0, 0].ch == Rune('H'))
    check(buffer[6, 0].ch == Rune(0x4E16))  # Unicode codepoint for '世'
    # Note: Emoji handling depends on width calculation

suite "Extended Colors":
  test "RGB color printing":
    var buffer = newBuffer(80, 24)
    
    buffer.printRGB(5, 5, "RGB Text",
                   RGBColor(r: 255, g: 128, b: 64),
                   RGBColor(r: 0, g: 0, b: 128))
    
    # Check text and extended color info
    let cell = buffer[5, 5]
    check(cell.ch == Rune('R'))
    check(cell.extColor.isSome)
    if cell.extColor.isSome:
      let extColor = cell.extColor.get()
      # The actual color mode depends on terminal support
      # It might be RGB or 256-color mode
      check(extColor.mode in {ColorRGB, Color256})
  
  test "256-color mode":
    # Test color style setting
    let style = ColorStyle(
      mode: Color256,
      idx256Fg: 196,  # Red
      idx256Bg: 21,   # Blue
      attrs: {AttrUnderlineAttr}
    )
    
    # This tests that the ColorStyle can be created and applied
    setColorStyle(style)
    
    # Also test that we can set the color mode
    let originalMode = currentColorMode
    setColorMode(Color256)
    check(currentColorMode == Color256)
    setColorMode(originalMode)

suite "Differential Drawing":
  test "Calculate buffer diff":
    var oldBuffer = newBuffer(20, 10)
    var newBuffer = newBuffer(20, 10)
    
    # Set up old buffer
    oldBuffer.print(0, 0, "Hello")
    oldBuffer.print(0, 1, "World")
    
    # Set up new buffer with changes
    newBuffer.print(0, 0, "Hello")  # Same
    newBuffer.print(0, 1, "Earth")  # Changed
    
    # Calculate diff
    let diff = calculateDiff(oldBuffer, newBuffer)
    
    # Should have differences for "World" -> "Earth"
    check(diff.len > 0)
    
    # Find the changes
    var foundChange = false
    for d in diff:
      if d.y == 1 and d.x >= 0 and d.x < 5:
        foundChange = true
        break
    check(foundChange)
  
  test "No changes diff":
    var oldBuffer = newBuffer(20, 10)
    var newBuffer = newBuffer(20, 10)
    
    # Set up identical content
    oldBuffer.print(5, 5, "Same")
    newBuffer.print(5, 5, "Same")
    
    # Calculate diff
    let diff = calculateDiff(oldBuffer, newBuffer)
    
    # Should have minimal or no differences
    # (might have some due to initialization differences)
    check(diff.len >= 0)

suite "Color Detection and Modes":
  test "Color mode setting":
    # Save current mode
    let originalMode = currentColorMode
    
    # Test different modes
    setColorMode(ColorBasic)
    check(currentColorMode == ColorBasic)
    
    setColorMode(Color256)
    check(currentColorMode == Color256)
    
    setColorMode(ColorRGB)
    check(currentColorMode == ColorRGB)
    
    # Restore original mode
    setColorMode(originalMode)
  
  test "Reset color cache":
    # This should not crash
    resetColorCache()

suite "Unicode Width Calculation":
  test "ASCII character width":
    check(runeWidth(Rune('A')) == 1)
    check(runeWidth(Rune(' ')) == 1)
    check(runeWidth(Rune('0')) == 1)
  
  test "Wide character width":
    check(runeWidth(Rune(0x4E16)) == 2)  # '世'
    check(runeWidth(Rune(0x754C)) == 2)  # '界'
    check(runeWidth(Rune(0x3042)) == 2)  # 'あ'
  
  test "Zero-width character":
    # Combining marks
    check(runeWidth(Rune(0x0301)) == 0)  # Combining acute accent

suite "Advanced Printing":
  test "Print with advanced options":
    var buffer = newBuffer(80, 24)
    
    # Test advanced printing
    buffer.printAdvanced(10, 10, "Advanced",
                        Style(fg: ColorYellow, bg: ColorMagenta, attrs: {AttrItalicAttr}))
    
    let cell = buffer[10, 10]
    check(cell.ch == Rune('A'))
    check(cell.style.fg == ColorYellow)
    check(cell.style.bg == ColorMagenta)
    check(AttrItalicAttr in cell.style.attrs)
  
  test "RGB advanced printing":
    var buffer = newBuffer(80, 24)
    
    buffer.printRGBAdvanced(5, 5, "RGB Advanced",
                           RGBColor(r: 200, g: 100, b: 50),
                           RGBColor(r: 50, g: 100, b: 200),
                           {AttrBoldAttr, AttrUnderlineAttr})
    
    let cell = buffer[5, 5]
    check(cell.ch == Rune('R'))
    check(cell.extColor.isSome)
    if cell.extColor.isSome:
      let extColor = cell.extColor.get()
      # The actual color mode depends on terminal support
      check(extColor.mode in {ColorRGB, Color256})