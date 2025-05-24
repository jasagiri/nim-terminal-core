# test_output.nim
## Comprehensive test suite for the output module

import unittest
import std/unicode
import std/options
import std/strutils
import ../src/libterminal/private/common
import ../src/libterminal/private/color_utils
import ../src/libterminal/private/unicode_utils
import ../src/libterminal/output

suite "Buffer operations":
  test "Buffer creation and properties":
    let buffer = newBuffer(80, 24)
    check(buffer.width == 80)
    check(buffer.height == 24)
    check(buffer.cells.len == 80 * 24)
    check(buffer.dirty == true)
    
  test "Buffer cell access and bounds checking":
    var buffer = newBuffer(80, 24)
    
    # Access within bounds
    let style = Style(
      fg: ColorRed,
      bg: ColorBlue,
      attrs: {AttrBoldAttr}
    )
    let cell = Cell(ch: Rune('X'), style: style, width: 1)
    
    buffer[10, 5] = cell
    check(buffer[10, 5].ch == Rune('X'))
    check(buffer[10, 5].style.fg == ColorRed)
    check(buffer[10, 5].style.bg == ColorBlue)
    check(AttrBoldAttr in buffer[10, 5].style.attrs)
    
    # Access out of bounds (should not crash and return default cell)
    let outOfBounds = buffer[-1, -1]
    check(outOfBounds.ch == Rune(' '))
    check(outOfBounds.style.fg == ColorDefault)
    check(outOfBounds.style.bg == ColorDefault)
    check(outOfBounds.style.attrs == {})
    
    # Writing out of bounds should be safe
    buffer[-1, -1] = cell
    buffer[100, 100] = cell
    
    # Verify original cell was not affected
    check(buffer[10, 5].ch == Rune('X'))
  
  test "Buffer clear operation":
    var buffer = newBuffer(80, 24)
    buffer[10, 5] = Cell(ch: Rune('X'), width: 1)
    buffer[20, 10] = Cell(
      ch: Rune('Y'), 
      style: Style(fg: ColorGreen, bg: ColorBlack, attrs: {AttrBoldAttr}),
      width: 1
    )
    
    buffer.clear()
    
    # Check that cells were reset
    check(buffer[10, 5].ch == Rune(' '))
    check(buffer[10, 5].style.fg == ColorDefault)
    check(buffer[10, 5].style.bg == ColorDefault)
    check(buffer[10, 5].style.attrs == {})
    
    check(buffer[20, 10].ch == Rune(' '))
    check(buffer[20, 10].style.fg == ColorDefault)
    check(buffer[20, 10].style.bg == ColorDefault)
    check(buffer[20, 10].style.attrs == {})
    
    # Check that buffer is marked as dirty
    check(buffer.dirty == true)
  
  test "Buffer resize operation":
    var buffer = newBuffer(80, 24)
    buffer[10, 5] = Cell(ch: Rune('X'), width: 1)
    buffer[70, 20] = Cell(ch: Rune('Y'), width: 1)
    
    # Resize to larger dimensions
    buffer.resize(100, 30)
    
    check(buffer.width == 100)
    check(buffer.height == 30)
    check(buffer.cells.len == 100 * 30)
    check(buffer[10, 5].ch == Rune('X'))  # Content should be preserved
    check(buffer[70, 20].ch == Rune('Y'))  # Content should be preserved
    
    # Resize to smaller dimensions
    buffer.resize(20, 10)
    
    check(buffer.width == 20)
    check(buffer.height == 10)
    check(buffer.cells.len == 20 * 10)
    check(buffer[10, 5].ch == Rune('X'))  # Content within new bounds should be preserved
    
    # Cell at 70,20 is now out of bounds and should not be accessible
    let outCell = buffer[70, 20]
    check(outCell.ch == Rune(' '))  # Default cell is returned for out-of-bounds
    
    # No resize needed
    buffer.resize(20, 10)
    check(buffer.width == 20)
    check(buffer.height == 10)

suite "Text operations":
  test "Basic text printing":
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

  test "Wide character handling":
    var buffer = newBuffer(80, 24)
    
    # Test with Japanese character (full-width)
    buffer.print(5, 10, "日本語")
    
    check(buffer[5, 10].ch == "日".runeAt(0))
    check(buffer[5, 10].width == 2)
    # The next cell should be empty or have width 0
    check(buffer[6, 10].width == 0)
    
    check(buffer[7, 10].ch == "本".runeAt(0))
    check(buffer[7, 10].width == 2)
    check(buffer[8, 10].width == 0)
    
    check(buffer[9, 10].ch == "語".runeAt(0))
    check(buffer[9, 10].width == 2)
    check(buffer[10, 10].width == 0)
  
  test "Advanced Unicode text with printAdvanced":
    var buffer = newBuffer(80, 24)
    let style = Style(fg: ColorRed, bg: ColorDefault)
    
    # Test with combining characters
    buffer.printAdvanced(5, 10, "é", style)  # e + combining acute accent
    
    # The first cell should contain the base character
    check(buffer[5, 10].ch == toRunes("é")[0])
    check(buffer[5, 10].style.fg == ColorRed)
    
    # Test with emoji
    buffer.printAdvanced(10, 10, "👍", style)
    check(buffer[10, 10].ch == toRunes("👍")[0])
    check(buffer[10, 10].width == 2)  # Emoji is typically width 2
    check(buffer[11, 10].width == 0)  # Next cell should be a placeholder

  test "Multi-line text with line wrapping":
    var buffer = newBuffer(40, 10)
    let style = Style(fg: ColorBlue)
    let longText = "This is a very long text that should be wrapped across multiple lines according to the specified width."
    
    let linesWritten = buffer.printMultiLine(5, 2, longText, style, 20, WrapWord)
    
    # Should have multiple lines
    check(linesWritten > 1)
    
    # Check first line content
    check(buffer[5, 2].ch == Rune('T'))
    check(buffer[5, 2].style.fg == ColorBlue)
    
    # With 20 columns width and word wrapping, we expect a particular pattern
    # but exact wrapping depends on algorithm details, so we'll verify basics
    check(buffer[5, 3].ch != Rune(' '))  # Second line should not start with space

  test "Text with cursor":
    var buffer = newBuffer(80, 24)
    let style = Style(fg: ColorDefault)
    let cursorStyle = Style(fg: ColorWhite, bg: ColorBlue)
    
    buffer.printTextWithCursor(5, 10, "Hello World", 6, style, cursorStyle)
    
    # Character at cursor position should have cursor style
    check(buffer[11, 10].style.fg == ColorWhite)
    check(buffer[11, 10].style.bg == ColorBlue)
    
    # Other characters should have normal style
    check(buffer[5, 10].style.fg == ColorDefault)
    check(buffer[5, 10].style.bg == ColorDefault)

suite "Color handling":
  test "RGB color printing":
    var buffer = newBuffer(80, 24)
    let redColor = RGBColor(r: 255, g: 0, b: 0)
    let blueColor = RGBColor(r: 0, g: 0, b: 255)
    
    buffer.printRGB(5, 10, "Colored", redColor, blueColor, {AttrBoldAttr})
    
    # Check if cells have extended color info
    check(buffer[5, 10].extColor.isSome)
    
    # The internal implementation will depend on current terminal color mode
    # but we can verify the structure is in place correctly
    let extColor = buffer[5, 10].extColor.get
    
    # Ensuring proper color handling based on detected mode
    case extColor.mode
    of ColorRGB:
      check(extColor.rgbFg.r == 255)
      check(extColor.rgbFg.g == 0)
      check(extColor.rgbFg.b == 0)
      check(extColor.rgbBg.r == 0)
      check(extColor.rgbBg.g == 0)
      check(extColor.rgbBg.b == 255)
    of Color256:
      # For 256 color mode, we would check color indices
      discard
    else:
      # For basic colors, we don't need additional checks
      discard
    
    # Verify all characters have the attributes
    for i in 5..(5+6):  # "Colored" has 7 characters (indices 5-11)
      check(AttrBoldAttr in buffer[i, 10].style.attrs)

  test "Color name printing":
    var buffer = newBuffer(80, 24)
    
    buffer.printColorName(5, 10, "Named", Red, Blue)
    
    # Check if cells have extended color info as needed
    if currentColorMode in {ColorRGB, Color256}:
      check(buffer[5, 10].extColor.isSome)
    
    # Basic styling should always be present
    check(buffer[5, 10].style.fg != ColorDefault)
    check(buffer[5, 10].style.bg != ColorDefault)

  test "Advanced RGB with grapheme clusters":
    var buffer = newBuffer(80, 24)
    let redColor = RGBColor(r: 255, g: 0, b: 0)
    let greenColor = RGBColor(r: 0, g: 255, b: 0)
    
    # Test with combining characters and emoji
    buffer.printRGBAdvanced(5, 10, "é👍", redColor, greenColor)
    
    # Verify main properties
    check(buffer[5, 10].extColor.isSome)
    check(buffer[6, 10].extColor.isSome)  # Emoji starting position
    check(buffer[7, 10].width == 0)  # Second cell of emoji
    
    # Character width checks
    check(buffer[5, 10].width == 1)  # 'é' is width 1
    check(buffer[6, 10].width == 2)  # '👍' is width 2

suite "Differential drawing":
  test "Calculate diff - no change":
    var buffer1 = newBuffer(10, 5)
    var buffer2 = newBuffer(10, 5)
    
    let diffs = calculateDiff(buffer1, buffer2)
    
    # No differences should be found
    check(diffs.len == 0)
  
  test "Calculate diff - character change":
    var buffer1 = newBuffer(10, 5)
    var buffer2 = newBuffer(10, 5)
    
    # Change a character in buffer2
    buffer2[3, 2] = Cell(ch: Rune('X'), width: 1)
    
    let diffs = calculateDiff(buffer1, buffer2)
    
    # Should have exactly one difference
    check(diffs.len == 1)
    check(diffs[0].op == DiffChar)
    check(diffs[0].x == 3)
    check(diffs[0].y == 2)
    check(diffs[0].cell.ch == Rune('X'))
  
  test "Calculate diff - color change":
    var buffer1 = newBuffer(10, 5)
    var buffer2 = newBuffer(10, 5)
    
    # Change foreground color in buffer2
    buffer2[3, 2] = Cell(
      ch: Rune(' '),
      style: Style(fg: ColorRed, bg: ColorDefault, attrs: {}),
      width: 1
    )
    
    let diffs = calculateDiff(buffer1, buffer2)
    
    # Should have exactly one difference related to foreground color
    check(diffs.len == 1)
    check(diffs[0].op == DiffFg)
    check(diffs[0].x == 3)
    check(diffs[0].y == 2)
    check(diffs[0].cell.style.fg == ColorRed)
  
  test "Calculate diff - size change":
    var buffer1 = newBuffer(10, 5)
    var buffer2 = newBuffer(20, 10)  # Different size
    
    let diffs = calculateDiff(buffer1, buffer2)
    
    # Should generate diffs for the entire buffer2
    check(diffs.len == 20 * 10)
    check(diffs[0].op == DiffAll)
  
  test "Calculate diff - multiple changes":
    var buffer1 = newBuffer(10, 5)
    var buffer2 = newBuffer(10, 5)
    
    # Make multiple changes to buffer2
    buffer2[1, 1] = Cell(ch: Rune('A'), width: 1)
    buffer2[2, 2] = Cell(
      ch: Rune('B'),
      style: Style(fg: ColorGreen, bg: ColorDefault, attrs: {}),
      width: 1
    )
    buffer2[3, 3] = Cell(
      ch: Rune(' '),
      style: Style(fg: ColorDefault, bg: ColorBlue, attrs: {}),
      width: 1
    )
    
    let diffs = calculateDiff(buffer1, buffer2)
    
    # Should have exactly three differences
    check(diffs.len == 3)
    
    # Find and verify each diff
    var foundChar, foundFg, foundBg: bool
    
    for diff in diffs:
      case diff.op
      of DiffChar:
        check(diff.cell.ch == Rune('A'))
        check(diff.x == 1)
        check(diff.y == 1)
        foundChar = true
      of DiffAll:
        check(diff.cell.ch == Rune('B'))
        check(diff.x == 2)
        check(diff.y == 2)
        check(diff.cell.style.fg == ColorGreen)
        foundFg = true
      of DiffBg:
        check(diff.x == 3)
        check(diff.y == 3)
        check(diff.cell.style.bg == ColorBlue)
        foundBg = true
      else:
        check(false)  # Should not get other diff types
    
    check(foundChar)
    check(foundFg)
    check(foundBg)

suite "Unicode text handling":
  test "Unicode character width":
    # ASCII - width 1
    check(output.runeWidth(Rune('a')) == 1)
    
    # East Asian character - width 2
    check(output.runeWidth("日".runeAt(0)) == 2)
    
    # Combining character - width 0
    check(output.runeWidth(Rune(0x0301)) == 0)
    
    # Emoji - width 2
    check(output.runeWidth("👍".runeAt(0)) == 2)
  
  test "Bidirectional text":
    var buffer = newBuffer(80, 24)
    let style = Style()
    
    # Test LTR text
    buffer.printBidirectional(10, 5, "Hello", style)
    check(buffer[10, 5].ch == Rune('H'))
    
    # The actual rendering of RTL text is complex and depends on the implementation
    # We can only test basic structure aspects
    buffer.printBidirectional(20, 5, "שלום", style)  # Hebrew "shalom"
    
    # Check text direction detection
    check(getTextDirection("Hello") == LeftToRight)
    check(getTextDirection("שלום") == RightToLeft)
    check(getTextDirection("Hello שלום") == LeftToRight)  # First strong character is LTR
    check(getTextDirection("שלום Hello") == RightToLeft)  # First strong character is RTL
  
  test "Multi-line text wrapping":
    let longText = "This is a very long line of text that should wrap to multiple lines when constrained by width"
    
    # Test different wrap modes
    let lines1 = splitLines(longText, 20, WrapNone)
    check(lines1.len == 1)  # With WrapNone, only explicit newlines cause line breaks
    
    let lines2 = splitLines(longText, 20, WrapCharacter)
    check(lines2.len > 1)  # Should break into multiple lines
    check(lines2[0].len <= 20)  # Each line should be at most 20 characters
    
    let lines3 = splitLines(longText, 20, WrapWord)
    check(lines3.len > 1)  # Should break into multiple lines
    check(lines3[0].len <= 20)  # Each line should be at most 20 characters
    
    # With word wrapping, lines shouldn't break in the middle of words
    # except where a single word is longer than maxWidth
    for line in lines3:
      if line.len < 20:  # Full-length lines may end with a complete word
        check(not line.endsWith(" "))
  
  test "Logical to visual position conversion":
    # ASCII only - positions match
    let text1 = "Hello"
    check(logicalPosToVisual(text1, 3) == 3)
    
    # With full-width characters
    let text2 = "Hello日本語"
    check(logicalPosToVisual(text2, 5) == 5)  # After "Hello"
    
    # Position in the middle of a multibyte character
    # Behavior depends on the exact implementation, but should be safe
    discard logicalPosToVisual(text2, 6)
    
    # Visual to logical conversion
    check(visualPosToLogical(text1, 3) <= 3)  # Should be at or before position 3
    check(visualPosToLogical(text2, 7) <= 8)  # Should be a valid string index

  test "Grapheme clusters":
    let text = "é👨‍👩‍👧‍👦"  # Combining accent and a family emoji (multiple code points)
    
    let clusters = splitIntoGraphemeClusters(text)
    
    # Should have at least 2 clusters (the é and the emoji family)
    check(clusters.len >= 2)
    
    # First cluster should be 'é' which is one base character + combining mark
    check(clusters[0].width == 1)
    
    # Second should be the family emoji
    check(clusters[1].width == 2)
    
    # Check grapheme length
    check(graphemeLength(text) == clusters.len)
    
    # Display width should be the sum of cluster widths
    var totalWidth = 0
    for cluster in clusters:
      totalWidth += cluster.width
    check(displayWidth(text) == totalWidth)