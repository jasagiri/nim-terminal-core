# interactive_unicode_demo.nim
## Interactive Unicode Demo
## 
## An interactive application to explore and demonstrate
## the Unicode handling capabilities of the library.

import libterminal
import std/unicode
import std/strutils
import std/sequtils
import std/tables
import std/strformat

type
  MenuItem = object
    title: string
    description: string
    action: proc(buffer: var Buffer)

  DemoState = object
    selectedIndex: int
    items: seq[MenuItem]
    running: bool
    messages: seq[string]

# Helper to add a message to the message log
proc addMessage(state: var DemoState, msg: string) =
  state.messages.add(msg)
  if state.messages.len > 10:
    state.messages.delete(0)

# Check if terminal supports RGB colors
proc detectRGBSupport(): bool =
  # Basic check based on COLORTERM environment variable
  when defined(posix):
    let colorterm = getEnv("COLORTERM", "")
    return "truecolor" in colorterm or "24bit" in colorterm
  else:
    return false

#--------------------------------------
# Demo functions
#--------------------------------------

proc demoBasicInfo(buffer: var Buffer) =
  # Clear the content area
  let defaultStyle = Style(fg: ColorDefault, bg: ColorDefault)
  for y in 5..<30:
    for x in 30..<buffer.width:
      buffer[x, y] = Cell(ch: ' '.Rune, style: defaultStyle, width: 1)
  
  # Display basic Unicode information
  buffer.print(32, 6, "Basic Unicode Information", Style(fg: ColorCyan, attrs: {AttrBold}))
  buffer.print(32, 8, "Terminal Dimensions: " & $buffer.width & "×" & $buffer.height)
  
  # Color support
  let colorMode = case currentColorMode
    of ColorBasic: "Basic (8 colors)"
    of ColorBright: "Bright (16 colors)"
    of Color256: "256 colors"
    of ColorRGB: "RGB (16 million colors)"
  
  buffer.print(32, 9, "Color Support: " & colorMode)
  
  # Unicode support information
  buffer.print(32, 11, "Unicode Support Information:")
  buffer.print(32, 12, "• Grapheme cluster awareness: Yes")
  buffer.print(32, 13, "• Emoji support: Yes")
  buffer.print(32, 14, "• Bidirectional text: Yes")
  buffer.print(32, 15, "• CJK character support: Yes")
  buffer.print(32, 16, "• Combining character support: Yes")
  
  # Sample of different scripts
  buffer.print(32, 18, "Sample Scripts:", Style(fg: ColorYellow))
  buffer.printAdvanced(32, 19, "Latin: Hello World", defaultStyle)
  buffer.printAdvanced(32, 20, "CJK: 你好世界 こんにちは 안녕하세요", defaultStyle)
  buffer.printAdvanced(32, 21, "Cyrillic: Привет мир", defaultStyle)
  buffer.printAdvanced(32, 22, "Arabic: مرحبا بالعالم", defaultStyle)
  buffer.printAdvanced(32, 23, "Greek: Γειά σου Κόσμε", defaultStyle)
  buffer.printAdvanced(32, 24, "Emoji: 👋 🌍 🚀 💻 🎉", defaultStyle)

proc demoWidthCalculator(buffer: var Buffer) =
  # Clear the content area
  let defaultStyle = Style(fg: ColorDefault, bg: ColorDefault)
  for y in 5..<30:
    for x in 30..<buffer.width:
      buffer[x, y] = Cell(ch: ' '.Rune, style: defaultStyle, width: 1)
  
  # Display width calculator info
  buffer.print(32, 6, "Unicode Width Calculator", Style(fg: ColorCyan, attrs: {AttrBold}))
  buffer.print(32, 8, "Enter text in the terminal to see width calculations.")
  buffer.print(32, 9, "Press Escape to return to the menu.")
  
  # Display input area
  buffer.print(32, 11, "Input: ", Style(fg: ColorGreen))
  drawBuffer(buffer)
  
  # Create input buffer
  var input = ""
  var running = true
  
  # Process input
  while running:
    # Read a key
    let event = input.pollEvent()
    
    if event.kind == KeyPress:
      if event.key == KeyEscape:
        running = false
      elif event.key == KeyBackspace and input.len > 0:
        # Handle backspace
        let lastCharLen = if input.len >= 4: 4 else: 1
        input = input[0 ..< ^lastCharLen]
      else:
        # Add the character to input
        if event.ch != '\0':
          input.add(event.ch)
    
    # Clear previous results
    for y in 12..<20:
      for x in 32..<buffer.width:
        buffer[x, y] = Cell(ch: ' '.Rune, style: defaultStyle, width: 1)
    
    # Display current input text
    buffer.print(39, 11, " ".repeat(40), defaultStyle)  # Clear the input line
    buffer.printAdvanced(39, 11, input, Style(fg: ColorWhite, attrs: {AttrBold}))
    
    # Display width calculations
    if input.len > 0:
      let byteLen = input.len
      let runeLen = input.runeLen
      let graphemeLen = unicode_utils.graphemeLength(input)
      let displayLen = displayWidth(input)
      
      buffer.print(32, 13, "Byte length: " & $byteLen)
      buffer.print(32, 14, "Rune (code point) count: " & $runeLen)
      buffer.print(32, 15, "Grapheme cluster count: " & $graphemeLen)
      buffer.print(32, 16, "Display width: " & $displayLen)
      
      # Visualization
      buffer.print(32, 18, "Width Visualization:")
      
      # Draw box showing the visual width
      var widthBar = "["
      for i in 1..min(displayLen, 40):
        widthBar.add("=")
      widthBar.add("]")
      buffer.print(32, 19, widthBar)
    
    # Update the display
    drawBuffer(buffer)

proc demoEmojiExplorer(buffer: var Buffer) =
  # Clear the content area
  let defaultStyle = Style(fg: ColorDefault, bg: ColorDefault)
  for y in 5..<30:
    for x in 30..<buffer.width:
      buffer[x, y] = Cell(ch: ' '.Rune, style: defaultStyle, width: 1)
  
  # Emoji categories and samples
  let emojiCategories = {
    "Faces": "😀 😁 😂 🤣 😃 😄 😅 😆 😉 😊 🙂 🙃",
    "People": "👶 👧 🧒 👦 👩 🧑 👨 👵 🧓 👴 👲 👳‍♀️",
    "Gestures": "👍 👎 👊 ✊ 🤛 🤜 👏 🙌 👐 🤲 🤝 🙏",
    "Animals": "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮",
    "Food": "🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒",
    "Travel": "🚗 🚕 🚙 🚌 🚎 🏎 🚓 🚑 🚒 🚐 🚚 🚛",
    "Activities": "⚽️ 🏀 🏈 ⚾️ 🥎 🎾 🏐 🏉 🥏 🎱 🪀 🏓",
    "Objects": "⌚️ 📱 💻 ⌨️ 🖥 🖱 🖨 🖲 🕹 🗜 💽 💾",
    "Symbols": "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕",
    "Flags": "🏳️ 🏴 🏁 🚩 🏳️‍🌈 🏳️‍⚧️ 🇺🇸 🇬🇧 🇨🇦 🇯🇵 🇰🇷 🇫🇷"
  }.toTable
  
  let categoryNames = toSeq(emojiCategories.keys)
  
  # Display emoji explorer info
  buffer.print(32, 6, "Emoji Explorer", Style(fg: ColorCyan, attrs: {AttrBold}))
  buffer.print(32, 8, "Use up/down arrows to navigate categories. Press Escape to return.")
  
  var selectedCategory = 0
  var running = true
  
  while running:
    # Clear previous results
    for y in 10..<30:
      for x in 32..<buffer.width:
        buffer[x, y] = Cell(ch: ' '.Rune, style: defaultStyle, width: 1)
    
    # Display categories
    for i, category in categoryNames:
      let style = if i == selectedCategory: 
                    Style(fg: ColorWhite, bg: ColorBlue, attrs: {AttrBold})
                  else:
                    Style(fg: ColorDefault, bg: ColorDefault)
                    
      buffer.print(32, 10 + i, category, style)
    
    # Display emojis for selected category
    let categoryEmojis = emojiCategories[categoryNames[selectedCategory]]
    buffer.print(50, 10, "Category: " & categoryNames[selectedCategory], 
                 Style(fg: ColorYellow, attrs: {AttrBold}))
    
    buffer.printAdvanced(50, 12, categoryEmojis, defaultStyle)
    
    # Display information about emoji display
    buffer.print(50, 14, "Information:", Style(fg: ColorGreen))
    buffer.print(50, 15, "• Each emoji typically has a display width of 2")
    buffer.print(50, 16, "• Some emoji sequences use zero-width joiners (ZWJ)")
    buffer.print(50, 17, "• Skin tone modifiers change appearance without affecting width")
    buffer.print(50, 18, "• Emoji presentation can be text or graphical based on context")
    
    # Update the display
    drawBuffer(buffer)
    
    # Process input
    let event = input.pollEvent()
    
    if event.kind == KeyPress:
      if event.key == KeyEscape:
        running = false
      elif event.key == KeyUp:
        selectedCategory = max(0, selectedCategory - 1)
      elif event.key == KeyDown:
        selectedCategory = min(categoryNames.len - 1, selectedCategory + 1)

proc demoColoredText(buffer: var Buffer) =
  # Clear the content area
  let defaultStyle = Style(fg: ColorDefault, bg: ColorDefault)
  for y in 5..<30:
    for x in 30..<buffer.width:
      buffer[x, y] = Cell(ch: ' '.Rune, style: defaultStyle, width: 1)
  
  # Display info
  buffer.print(32, 6, "Colored Unicode Text Demo", Style(fg: ColorCyan, attrs: {AttrBold}))
  buffer.print(32, 8, "This demonstrates colored text with various Unicode scripts.")
  buffer.print(32, 9, "Press Escape to return to the menu.")
  
  # Gradient colored text in different scripts
  
  # Latin - Rainbow gradient
  let latinText = "The quick brown fox jumps over the lazy dog"
  for i, char in toRunes(latinText):
    let progress = i.float / latinText.runeLen.float
    let r = uint8(sin(progress * 3.14159 * 2) * 127 + 128)
    let g = uint8(sin(progress * 3.14159 * 2 + 2) * 127 + 128)
    let b = uint8(sin(progress * 3.14159 * 2 + 4) * 127 + 128)
    let x = 32 + displayWidth(latinText[0..<i])
    buffer.printRGBAdvanced(x, 11, $char, RGBColor(r: r, g: g, b: b))
  
  # Japanese - Red to blue gradient
  let japaneseText = "こんにちは世界、これは日本語のテストです"
  for i, char in toRunes(japaneseText):
    let progress = i.float / japaneseText.runeLen.float
    let r = uint8(255 * (1.0 - progress))
    let b = uint8(255 * progress)
    let x = 32 + displayWidth(japaneseText[0..<i])
    buffer.printRGBAdvanced(x, 13, $char, RGBColor(r: r, g: 0, b: b))
  
  # Arabic - Green to yellow gradient
  let arabicText = "مرحبا بالعالم، هذا اختبار للغة العربية"
  for i, char in toRunes(arabicText):
    let progress = i.float / arabicText.runeLen.float
    let g = uint8(128 + 127 * (1.0 - progress))
    let r = uint8(255 * progress)
    let x = 32 + displayWidth(arabicText[0..<i])
    buffer.printRGBAdvanced(x, 15, $char, RGBColor(r: r, g: g, b: 0))
  
  # Emoji with purple background
  let emojiText = "🌈 🦄 ✨ 🚀 🌟 💫 🔮 🧙‍♂️ 🧝‍♀️ 🧚‍♂️"
  let purpleBg = RGBColor(r: 75, g: 0, b: 130)
  buffer.printRGBAdvanced(32, 17, emojiText, 
                      RGBColor(r: 255, g: 255, b: 255), purpleBg)
  
  # Mixed text with fancy border
  buffer.print(32, 19, "┌" & "─".repeat(50) & "┐")
  buffer.print(32, 20, "│" & " ".repeat(50) & "│")
  buffer.print(32, 21, "│" & " ".repeat(50) & "│")
  buffer.print(32, 22, "└" & "─".repeat(50) & "┘")
  
  let mixedText = "✨ Mixed 混合 مختلط Script 스크립트 Example ✨"
  
  # Calculate center position
  let textWidth = displayWidth(mixedText)
  let startX = 32 + (50 - textWidth) div 2
  
  let goldColor = RGBColor(r: 255, g: 215, b: 0)
  buffer.printRGBAdvanced(startX, 21, mixedText, goldColor)
  
  # Draw a color chart
  buffer.print(32, 24, "Color Mode Support:")
  
  # Display color samples based on terminal support
  case currentColorMode
  of ColorBasic, ColorBright:
    buffer.print(32, 25, "Basic Color Mode (8-16 colors)")
    for i in 0..7:
      buffer.print(32 + i*6, 26, "■", Style(fg: Color(i)))
    if currentColorMode == ColorBright:
      for i in 8..15:
        buffer.print(32 + (i-8)*6, 27, "■", Style(fg: Color(i)))
  
  of Color256:
    buffer.print(32, 25, "256 Color Mode")
    for i in 0..15:
      buffer.print(32 + i*2, 26, "■")
      set256Foreground(i)
    buffer.print(32, 27, "Plus 240 additional colors (not shown)")
  
  of ColorRGB:
    buffer.print(32, 25, "RGB True Color Mode (16.7M colors)")
    for i in 0..24:
      let progress = i.float / 24.0
      let r = uint8(255 * progress)
      let g = uint8(255 * (1.0 - progress))
      let b = uint8(255 * sin(progress * 3.14159))
      buffer.printRGB(32 + i*2, 26, "■", RGBColor(r: r, g: g, b: b))
  
  # Wait for escape key
  var running = true
  while running:
    drawBuffer(buffer)
    let event = input.pollEvent()
    if event.kind == KeyPress and event.key == KeyEscape:
      running = false

proc demoBidirectionalText(buffer: var Buffer) =
  # Clear the content area
  let defaultStyle = Style(fg: ColorDefault, bg: ColorDefault)
  for y in 5..<30:
    for x in 30..<buffer.width:
      buffer[x, y] = Cell(ch: ' '.Rune, style: defaultStyle, width: 1)
  
  # Display info
  buffer.print(32, 6, "Bidirectional Text Demonstration", Style(fg: ColorCyan, attrs: {AttrBold}))
  buffer.print(32, 8, "This demonstrates how right-to-left scripts are handled.")
  buffer.print(32, 9, "Press Escape to return to the menu.")
  
  # RTL Languages examples
  buffer.print(32, 11, "Arabic Text:")
  buffer.printAdvanced(32, 12, "مرحبا بالعالم (Hello World in Arabic)", defaultStyle)
  
  buffer.print(32, 14, "Hebrew Text:")
  buffer.printAdvanced(32, 15, "שלום עולם (Hello World in Hebrew)", defaultStyle)
  
  # Mixed direction text
  buffer.print(32, 17, "Mixed RTL/LTR Text:")
  buffer.printAdvanced(32, 18, "English text with العربية and more English", defaultStyle)
  buffer.printAdvanced(32, 19, "English text with עברית and more English", defaultStyle)
  
  # Complex mixed example
  buffer.print(32, 21, "Complex Bidirectional Example:")
  let complexBidi = "Latin -> العربية <- עברית -> 日本語 <- English -> 한국어"
  buffer.printAdvanced(32, 22, complexBidi, defaultStyle)
  
  # Text with numbers
  buffer.print(32, 24, "Numbers in RTL context:")
  buffer.printAdvanced(32, 25, "Arabic: رقم 12345 ونص", defaultStyle)
  buffer.printAdvanced(32, 26, "Hebrew: מספר 67890 וטקסט", defaultStyle)
  
  # Wait for escape key
  var running = true
  while running:
    drawBuffer(buffer)
    let event = input.pollEvent()
    if event.kind == KeyPress and event.key == KeyEscape:
      running = false

#--------------------------------------
# Main application
#--------------------------------------

proc drawMenu(buffer: var Buffer, state: DemoState) =
  # Clear the buffer
  buffer.clear()
  
  # Draw title
  let titleStyle = Style(fg: ColorMagenta, bg: ColorDefault, attrs: {AttrBold})
  buffer.print(2, 1, "Interactive Unicode Demo", titleStyle)
  
  # Draw menu
  buffer.print(2, 3, "Select a demo:", Style(fg: ColorYellow, attrs: {AttrBold}))
  
  for i, item in state.items:
    let style = if i == state.selectedIndex: 
                  Style(fg: ColorWhite, bg: ColorBlue, attrs: {AttrBold})
                else:
                  Style(fg: ColorDefault, bg: ColorDefault)
                  
    buffer.print(2, 5 + i, fmt"{i+1}. {item.title}", style)
    buffer.print(4, 6 + i, item.description, Style(fg: ColorDefault, bg: ColorDefault))
  
  # Draw bottom instructions
  buffer.print(2, buffer.height - 3, "Controls: ↑/↓ to navigate, Enter to select, Q to quit", 
               Style(fg: ColorGreen))
  
  # Draw message log
  let msgY = buffer.height - 6
  buffer.print(2, msgY, "Log:", Style(fg: ColorYellow))
  
  for i, msg in state.messages:
    if i < 4:  # Show up to 4 messages
      buffer.print(7, msgY + i, msg)

proc main() =
  # Initialize the terminal
  withTerminal:
    # Get initial size
    let (width, height) = raw.getTerminalSize()
    
    # Create a buffer
    var buffer = newBuffer(width, height)
    
    # Create application state
    var state = DemoState(
      selectedIndex: 0,
      running: true,
      messages: @["Application started. Select a demo to begin."]
    )
    
    # Define menu items
    state.items = @[
      MenuItem(
        title: "Unicode Information",
        description: "Basic information about Unicode support",
        action: demoBasicInfo
      ),
      MenuItem(
        title: "Width Calculator",
        description: "Analyze width of different Unicode characters",
        action: demoWidthCalculator
      ),
      MenuItem(
        title: "Emoji Explorer",
        description: "Explore various emoji categories",
        action: demoEmojiExplorer
      ),
      MenuItem(
        title: "Colored Unicode Text",
        description: "Showcase of colored Unicode text in different scripts",
        action: demoColoredText
      ),
      MenuItem(
        title: "Bidirectional Text",
        description: "Demonstration of RTL languages and mixed direction text",
        action: demoBidirectionalText
      )
    ]
    
    # Main application loop
    while state.running:
      # Draw the menu
      drawMenu(buffer, state)
      
      # Update the terminal display
      drawBuffer(buffer)
      
      # Process input
      let event = input.pollEvent()
      
      if event.kind == KeyPress:
        case event.key
        of KeyUp:
          state.selectedIndex = max(0, state.selectedIndex - 1)
          state.addMessage("Selected menu item " & $(state.selectedIndex + 1))
        of KeyDown:
          state.selectedIndex = min(state.items.high, state.selectedIndex + 1)
          state.addMessage("Selected menu item " & $(state.selectedIndex + 1))
        of KeyReturn:
          let selectedItem = state.items[state.selectedIndex]
          state.addMessage("Running demo: " & selectedItem.title)
          # Run the selected demo
          selectedItem.action(buffer)
          # Return to menu
          state.addMessage("Returned from demo: " & selectedItem.title)
        of KeyQ:
          state.running = false
        else:
          discard

when isMainModule:
  main()