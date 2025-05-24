# unicode_test.nim
## A minimal example to test the Unicode enhancements

import std/unicode
import std/strutils

# Import the libterminal module to use the exported Unicode functionality
import "../src/libterminal"

proc main() =
  # Initialize terminal in raw mode
  withTerminal:
    # Create a buffer for drawing
    var buffer = newBuffer(80, 24)
    
    # Clear screen and hide cursor
    clearScreen()
    hideCursor()
    
    # Define test strings
    let text1 = "ASCII: Hello, World!"
    let text2 = "CJK: 你好，世界！"
    let text3 = "Arabic: مرحبا بالعالم!"
    let text4 = "Emoji: 👨‍👩‍👧‍👦 👍 🎉"
    let text5 = "Combined: é ñ ö ç"
    
    # Header with library info
    buffer.print(2, 0, "Nim Terminal Library - Unicode Test", Style(fg: fgGreen, bg: bgBlack, attrs: {attBold}))
    
    # Text Direction Tests
    buffer.print(2, 2, "Text Direction Tests:", Style(fg: fgYellow, bg: bgBlack, attrs: {attBold}))
    buffer.print(4, 3, text1 & " -> Direction: " & $getTextDirection(text1))
    buffer.print(4, 4, text2 & " -> Direction: " & $getTextDirection(text2))
    buffer.print(4, 5, text3 & " -> Direction: " & $getTextDirection(text3))
    buffer.print(4, 6, text4 & " -> Direction: " & $getTextDirection(text4))
    buffer.print(4, 7, text5 & " -> Direction: " & $getTextDirection(text5))
    
    # Grapheme Cluster Tests
    buffer.print(2, 9, "Grapheme Cluster Tests:", Style(fg: fgYellow, bg: bgBlack, attrs: {attBold}))
    buffer.print(4, 10, text1 & " -> Graphemes: " & $graphemeLength(text1) & ", Runes: " & $text1.runeLen)
    buffer.print(4, 11, text4 & " -> Graphemes: " & $graphemeLength(text4) & ", Runes: " & $text4.runeLen)
    
    # Display Width Tests
    buffer.print(2, 13, "Display Width Tests:", Style(fg: fgYellow, bg: bgBlack, attrs: {attBold}))
    buffer.print(4, 14, text1 & " -> Width: " & $displayWidth(text1))
    buffer.print(4, 15, text2 & " -> Width: " & $displayWidth(text2))
    buffer.print(4, 16, text4 & " -> Width: " & $displayWidth(text4))
    
    # Text Wrapping Tests
    buffer.print(2, 18, "Multi-line Text with Wrapping:", Style(fg: fgYellow, bg: bgBlack, attrs: {attBold}))
    
    let longText = "This is a longer paragraph of text that will be wrapped " &
                  "based on different wrapping modes. This demonstrates how " &
                  "Unicode-aware line wrapping works, including 全角文字 (wide characters) " &
                  "and emoji like 👨‍👩‍👧‍👦 👍 🎉."
    
    # Display wrapped text
    let lines = buffer.printMultiLine(4, 19, longText, 
                            Style(fg: fgWhite, bg: bgBlack, attrs: {}),
                            60, WrapWord)
    
    # Bidirectional text test
    buffer.print(2, 19 + lines + 1, "Bidirectional Text:", Style(fg: fgYellow, bg: bgBlack, attrs: {attBold}))
    let bidiText = "English and عربي mixed together"
    buffer.printBidirectional(4, 19 + lines + 2, bidiText, Style(fg: fgCyan))
    
    # Cursor style test
    buffer.print(2, 19 + lines + 4, "Cursor Styles:", Style(fg: fgYellow, bg: bgBlack, attrs: {attBold}))
    buffer.print(4, 19 + lines + 5, "Testing cursor positioning with Unicode text:")
    
    # Show text with cursor at different positions
    let cursorText = "Hello 你好 مرحبا 👨‍👩‍👧‍👦"
    let cursorStyle = Style(fg: fgBlack, bg: fgWhite, attrs: {})
    let textStyle = Style(fg: fgWhite, bg: bgBlack, attrs: {})
    buffer.printTextWithCursor(4, 19 + lines + 6, cursorText, 6, textStyle, cursorStyle)
    
    # Draw the buffer and show information
    buffer.drawBuffer()
    setCursor(0, 22)
    
    # Set a custom cursor style
    setCursorStyle("bar")
    
    # Wait for keyboard input before exiting
    buffer.print(2, 23, "Press any key to exit...", Style(fg: fgRed))
    buffer.drawBuffer()
    
    # Read a key to exit
    discard readKey()
    
    # Restore cursor
    setCursorStyle("block")
    showCursor()
    clearScreen()
  
when isMainModule:
  main()