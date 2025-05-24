# enhanced_unicode_example.nim
## Extended Unicode Support Demonstration
## 
## This example showcases the enhanced Unicode handling capabilities of libterminal,
## including proper grapheme cluster handling, accurate width calculations,
## emoji rendering, bidirectional text display, multi-line text wrapping,
## and Unicode-aware cursor positioning.

import libterminal
import std/unicode
import std/strutils
import std/times

proc main() =
  # Initialize the terminal
  withTerminal:
    # Get initial size
    let (width, height) = raw.getTerminalSize()
    
    # Create a buffer
    var buffer = newBuffer(width, height)
    
    # Clear the screen
    clearScreen()
    
    # Title
    let titleStyle = Style(
      fg: ColorCyan,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    buffer.print(2, 1, "Enhanced Unicode Support Demonstration", titleStyle)
    
    # Description
    buffer.print(2, 3, "This example showcases grapheme cluster handling, width calculations, and emoji support.")
    
    # Section 1: Grapheme Clusters
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    buffer.print(2, 5, "1. Grapheme Clusters", sectionStyle)
    
    # Basic character vs grapheme cluster comparison
    buffer.print(4, 7, "Characters vs Grapheme Clusters:")
    
    let combinedText = "e\u0301 a\u0300 i\u0302 o\u0308 u\u0303"  # é à î ö ũ
    
    # Standard print method
    buffer.print(6, 9, "Standard print: " & combinedText)
    
    # Advanced print method with grapheme cluster handling
    buffer.printAdvanced(6, 10, "Advanced print: " & combinedText, Style())
    
    # Display character count vs grapheme count
    let charCount = combinedText.runeLen
    let graphemeCount = unicode_utils.graphemeLength(combinedText)
    
    buffer.print(6, 12, "Character count (runeLen): " & $charCount)
    buffer.print(6, 13, "Grapheme count: " & $graphemeCount)
    
    # Section 2: Width Calculations
    buffer.print(2, 15, "2. Width Calculations", sectionStyle)
    
    # Display width of various characters
    buffer.print(4, 17, "Character Width Examples:")
    
    let characters = [
      "A",      # Latin (width 1)
      "あ",     # Hiragana (width 2)
      "世",     # CJK (width 2)
      "안",     # Hangul (width 2)
      "👍",     # Emoji (width 2)
      "é",      # Latin with accent (width 1)
      "👨‍👩‍👧‍👦",  # Family emoji (width 2, complex grapheme cluster)
      "ﾊﾜｲ",   # Half-width Katakana (width 1 each)
      "日本"    # Full-width (width 2 each)
    ]
    
    # Display character information
    for i, char in characters:
      let charWidth = displayWidth(char)
      let graphemes = unicode_utils.graphemeLength(char)
      buffer.print(6, 19 + i, char & ": Width=" & $charWidth & 
                            ", Graphemes=" & $graphemes & 
                            ", Runes=" & $char.runeLen)
    
    # Section 3: Emoji and complex sequences
    buffer.print(2, 29, "3. Emoji Support", sectionStyle)
    
    let emojiText = "😀 👍 🚀 🌍 🎮 🍕 📱 🐱 🏳️‍🌈 👩‍👩‍👧‍👦"
    buffer.printAdvanced(4, 31, "Basic Emoji: " & emojiText, Style())
    
    # Emoji with skin tone modifiers
    let skinToneEmoji = "👍 👍🏻 👍🏼 👍🏽 👍🏾 👍🏿"
    buffer.printAdvanced(4, 33, "Skin Tones: " & skinToneEmoji, Style())
    
    # Zero-width joiner sequences
    let zwjEmoji = "👨‍👩‍👧‍👦  👩‍🚒  👨‍💻  🏳️‍🌈"
    buffer.printAdvanced(4, 35, "ZWJ Sequences: " & zwjEmoji, Style())
    
    # Section 4: Bidirectional Text Support
    buffer.print(2, 37, "4. Bidirectional Text Support", sectionStyle)
    
    # Test strings with different directions
    let ltrText = "This is left-to-right text in English."
    let rtlText = "هذا نص من اليمين إلى اليسار باللغة العربية."
    let mixedText = "Mixed text: English, العربية, 日本語, עברית"
    
    # Display direction detection results
    buffer.print(4, 39, "Text direction detection:")
    
    let ltrDir = getTextDirection(ltrText)
    buffer.print(6, 40, "LTR Text: " & ltrText)
    buffer.print(8, 41, "-> Detected direction: " & $ltrDir, Style(fg: ColorGreen))
    
    let rtlDir = getTextDirection(rtlText)
    buffer.print(6, 43, "RTL Text: " & rtlText)
    buffer.print(8, 44, "-> Detected direction: " & $rtlDir, Style(fg: ColorGreen))
    
    # Direction-aware printing
    buffer.print(4, 46, "Direction-aware printing:")
    
    # Standard printing (potentially problematic for RTL)
    buffer.print(6, 48, "Standard print:")
    buffer.print(8, 49, ltrText, Style())
    buffer.print(8, 50, rtlText, Style())
    
    # Bidirectional-aware printing
    buffer.print(6, 52, "Direction-aware print:")
    buffer.printBidirectional(buffer, 8, 53, ltrText, Style())
    buffer.printBidirectional(buffer, 8, 54, rtlText, Style())
    
    # Use RGB values for colored Unicode
    let redRGB = RGBColor(r: 255, g: 50, b: 50)
    let greenRGB = RGBColor(r: 50, g: 200, b: 50)
    let blueRGB = RGBColor(r: 50, g: 100, b: 255)
    let purpleRGB = RGBColor(r: 180, g: 50, b: 180)
    let orangeRGB = RGBColor(r: 255, g: 150, b: 50)
    
    # Colorful text with mixed scripts
    buffer.print(4, 56, "Colored multilingual text:")
    buffer.printRGBAdvanced(6, 57, "English", redRGB)
    buffer.printRGBAdvanced(14, 57, "日本語", greenRGB)
    buffer.printRGBAdvanced(22, 57, "한국어", blueRGB)
    buffer.printRGBAdvanced(30, 57, "العربية", purpleRGB)
    buffer.printRGBAdvanced(42, 57, "Emoji→🌈🦄✨", orangeRGB)
    
    # Section 5: Multi-line Text Wrapping
    buffer.print(2, 59, "5. Multi-line Text Wrapping", sectionStyle)
    
    # Text to demonstrate wrapping
    let paragraphText = "This is a longer paragraph of text that will be wrapped " &
                       "based on different wrapping modes. This demonstrates how " &
                       "Unicode-aware line wrapping works with different wrapping " &
                       "policies. This includes handling of 全角文字 (wide characters), " &
                       "grapheme clusters like 👨‍👩‍👧‍👦 (emoji with ZWJ), combining characters " &
                       "like é (e + ◌́), and 서로 다른 스크립트 (mixed scripts)."
    
    # Display wrapping options
    buffer.print(4, 61, "Text wrapping modes:")
    buffer.print(6, 62, "Original text length: " & $paragraphText.len & " bytes, " & 
                       $paragraphText.runeLen & " characters, " & 
                       $unicode_utils.graphemeLength(paragraphText) & " graphemes")
    
    let maxWrapWidth = 60  # Maximum width for wrapped text
    
    # Word wrap (most common)
    buffer.print(6, 64, "WrapWord (wrap at word boundaries):")
    let wordWrapY = 65
    let wordWrapLines = buffer.printMultiLine(buffer, 8, wordWrapY, paragraphText, 
                                            Style(), maxWrapWidth, WrapWord)
    
    # Character wrap (fallback option)
    buffer.print(6, wordWrapY + wordWrapLines + 1, "WrapCharacter (wrap at exact character):") 
    let charWrapY = wordWrapY + wordWrapLines + 2
    let charWrapLines = buffer.printMultiLine(buffer, 8, charWrapY, paragraphText, 
                                             Style(), maxWrapWidth, WrapCharacter)
    
    # No wrap (show raw breaks only)
    buffer.print(6, charWrapY + charWrapLines + 1, "WrapNone (raw newlines only):")
    let noWrapY = charWrapY + charWrapLines + 2
    buffer.printMultiLine(buffer, 8, noWrapY, paragraphText, Style(), maxWrapWidth, WrapNone)
    
    # Section 6: Unicode-aware Cursor Positioning
    let cursorSectionY = noWrapY + 3
    buffer.print(2, cursorSectionY, "6. Unicode-aware Cursor Positioning", sectionStyle)
    
    # Sample text with various Unicode characters
    let cursorText = "Cursor demo: 你好, こんにちは, مرحبا, สวัสดี, 안녕하세요, ñáöç, 👋"
    buffer.print(4, cursorSectionY + 2, "Text with cursor at different logical positions:")
    
    # Show cursor at different logical positions
    let logicalPositions = [0, 8, 13, 16, 21, 24, 29, 33, 39]
    
    for i, pos in logicalPositions:
      let posY = cursorSectionY + 4 + i
      
      if posY >= buffer.height - 8:
        break
        
      # Convert logical position to visual position
      let visualPos = logicalPosToVisual(cursorText, pos)
      
      # Display the text with cursor at current position
      buffer.printTextWithCursor(buffer, 6, posY, cursorText, pos, 
                               Style(), Style(fg: ColorBlack, bg: ColorWhite))
      
      # Show position information
      buffer.print(width - 24, posY, "Logical: " & align($pos, 2) & 
                                   " Visual: " & align($visualPos, 2))
    
    # Animation demo (if terminal supports it)
    let animY = min(buffer.height - 7, cursorSectionY + 14)
    buffer.print(2, animY, "7. Unicode Animation", sectionStyle)
    buffer.print(4, animY + 2, "Press any key to stop animation...")
    
    # Define animation frames (spinner and progress indicator)
    let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    let progressChars = ["▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"]
    
    # Draw buffer initially
    drawBuffer(buffer)
    
    # Animation loop 
    var frame = 0
    var running = true
    var startTime = epochTime()
    
    while running:
      # Check for keypress to exit animation
      if input.pollEventNonBlocking().isSome:
        running = false
        break
      
      # Update spinner
      let spinChar = spinnerFrames[frame mod spinnerFrames.len]
      buffer.printAdvanced(4, animY + 4, spinChar & " Processing...", Style())
      
      # Update progress bar
      let elapsedTime = epochTime() - startTime
      let progress = min(1.0, elapsedTime / 5.0)  # 5 second animation
      let progressWidth = int(40.0 * progress)
      
      var progressBar = "["
      for i in 0..<40:
        if i < progressWidth:
          progressBar.add("█")
        elif i == progressWidth and progressWidth < 40:
          let partialIdx = int((progress * 40.0 - progressWidth.float) * 8.0)
          if partialIdx >= 0 and partialIdx < progressChars.len:
            progressBar.add(progressChars[partialIdx])
          else:
            progressBar.add(" ")
        else:
          progressBar.add(" ")
      progressBar.add("] " & formatFloat(progress * 100, ffDecimal, 0) & "%")
      
      buffer.printAdvanced(4, animY + 5, progressBar, Style())
      
      # Update frame counter
      frame += 1
      
      # Draw buffer with changes
      drawBuffer(buffer)
      
      # Small delay
      sleep(100)
      
      # Exit after 5 seconds
      if elapsedTime > 5.0:
        running = false
    
    # Final message
    buffer.print(4, animY + 6, "Animation complete!", Style(fg: ColorGreen, attrs: {AttrBold}))
    drawBuffer(buffer)
    
    # Wait for keypress before exiting
    discard input.pollEvent()

when isMainModule:
  main()