# typing_effect_example.nim
## Unicode Typing Effect Demo
## 
## This example demonstrates a realistic typing effect that correctly
## handles complex Unicode characters including grapheme clusters,
## emojis, and multi-width characters.

import libterminal
import std/unicode
import std/strutils
import std/times
import std/random

proc main() =
  # Initialize
  randomize()
  
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
    buffer.print(2, 1, "Unicode Typing Effect Demo", titleStyle)
    
    # Instructions
    buffer.print(2, 3, "Press any key to cycle through typing demos. ESC to exit.", Style(fg: ColorYellow))
    
    # Define the text samples to type out
    let samples = [
      "English: The quick brown fox jumps over the lazy dog.",
      "Japanese: こんにちは世界、これは日本語のテストです。",
      "Arabic: مرحبا بالعالم، هذا اختبار للغة العربية.",
      "Mixed: Hello 你好 안녕하세요 नमस्ते こんにちは 👋",
      "Emoji: 😀 🚀 🌍 🎮 🍕 📱 🐱 👨‍👩‍👧‍👦 🌈",
      "Combined Letters: e\u0301 a\u0300 i\u0302 o\u0308 u\u0303 Z\u0302 C\u0327",
      "Math Symbols: ∫ ∑ ∏ √ ∞ ∆ ∇ ∂ ∀ ∃ ∄ ∴ ∵ ∼",
      "Fullwidth: ＨＥＬＬＯ　ＷＯＲＬＤ！",
      "RTL with English: مرحبا Hello كيف حالك Good العالم"
    ]
    
    # Draw buffer initially
    drawBuffer(buffer)
    
    var sampleIndex = 0
    var running = true
    
    while running:
      # Get the current sample
      let currentSample = samples[sampleIndex]
      
      # Display sample info
      let infoStyle = Style(fg: ColorGreen, attrs: {})
      buffer.clear()
      buffer.print(2, 1, "Unicode Typing Effect Demo", titleStyle)
      buffer.print(2, 3, "Press any key to cycle through typing demos. ESC to exit.", Style(fg: ColorYellow))
      buffer.print(2, 5, "Sample " & $(sampleIndex + 1) & "/" & $samples.len & ":", infoStyle)
      drawBuffer(buffer)
      
      # Split the current sample into grapheme clusters for proper typing effect
      let clusters = unicode_utils.splitIntoGraphemeClusters(currentSample)
      
      # Typewriter effect
      var displayString = ""
      var posY = 7
      
      for i, cluster in clusters:
        # Combine the codepoints in this cluster to form a proper string
        var clusterStr = ""
        for r in cluster.codePoints:
          clusterStr.add(toUTF8(r))
        
        # Add this cluster to our display string
        displayString.add(clusterStr)
        
        # Print the current typed string
        buffer.printAdvanced(4, posY, displayString, Style())
        
        # Apply cursor effect
        buffer.print(4 + displayWidth(displayString), posY, "▌", Style(fg: ColorWhite, attrs: {AttrBlink}))
        
        # Draw updated buffer
        drawBuffer(buffer)
        
        # Random delay to simulate typing
        let delay = rand(40..120)
        sleep(delay)
        
        # Clear the cursor for next update
        buffer.print(4 + displayWidth(displayString), posY, " ", Style())
      
      # Show a blinking cursor at the end
      buffer.print(4 + displayWidth(displayString), posY, "▌", Style(fg: ColorWhite, attrs: {AttrBlink}))
      drawBuffer(buffer)
      
      # Wait for keypress before continuing to next sample
      let ev = input.pollEvent()
      
      # Check for ESC key to exit
      if ev.kind == KeyPress and ev.key == KeyEscape:
        running = false
      else:
        # Move to next sample
        sampleIndex = (sampleIndex + 1) mod samples.len
    
    # Clear screen on exit
    clearScreen()

when isMainModule:
  main()