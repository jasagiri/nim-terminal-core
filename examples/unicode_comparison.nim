# unicode_comparison.nim
## Unicode Handling Comparison Demo
## 
## This example compares basic Unicode handling methods to
## libterminal's enhanced Unicode support, highlighting the differences
## and advantages of proper grapheme cluster support.

import libterminal
import std/unicode
import std/strutils
import std/times
import std/algorithm
import std/tables

type
  ComparisonMode = enum
    Width, Display, Editing, Alignment, Emoji, Boundary

  ExampleData = object
    title: string
    description: string
    text: string
    explanation: string

# Test cases for different Unicode scenarios
let examples = {
  Width: ExampleData(
    title: "Character Width Comparison",
    description: "Comparing width calculation between basic and enhanced methods",
    text: "Hello 你好 こんにちは 안녕하세요 مرحبا שלום नमस्ते 👋",
    explanation: "Basic methods count by code points; enhanced methods account for full-width characters and grapheme clusters."
  ),
  
  Display: ExampleData(
    title: "Text Display Comparison",
    description: "Comparing display methods for complex Unicode text",
    text: "A̰͛ m̛̂azi̤̎n͗̿g u̯̓n͒᷈i᷊cod᷊e̽̆ ♥️ with é, ñ, ö, ç and emojis 🚀🌍👩‍👩‍👧‍👦",
    explanation: "Basic methods may break combining characters; enhanced methods preserve grapheme clusters."
  ),
  
  Editing: ExampleData(
    title: "Text Editing Comparison",
    description: "Comparing cursor movement and editing in Unicode text",
    text: "Café 你好 👨‍👩‍👧‍👦 แฟนซี",
    explanation: "Basic methods move by code points; enhanced methods move by grapheme clusters."
  ),
  
  Alignment: ExampleData(
    title: "Text Alignment Comparison",
    description: "Comparing text alignment with mixed scripts",
    text: "English|日本語|العربية|한국어|हिन्दी",
    explanation: "Basic alignment uses character counts; enhanced alignment uses visual width."
  ),
  
  Emoji: ExampleData(
    title: "Emoji Handling Comparison",
    description: "Comparing emoji sequence handling",
    text: "Basic: 👍 👨‍👩‍👧‍👦 🏳️‍🌈 👩‍🔬 🇯🇵 👍🏽",
    explanation: "Basic methods split emoji sequences; enhanced methods preserve them as single grapheme clusters."
  ),
  
  Boundary: ExampleData(
    title: "Text Boundary Comparison",
    description: "Comparing text boundary detection (word wrapping, etc.)",
    text: "This is a long text with words, numbers (123), emoji 😊, and CJK characters 你好世界 that needs to be wrapped correctly.",
    explanation: "Basic methods wrap at any character; enhanced methods respect grapheme clusters and character classes."
  )
}.toTable

# Simulate basic Unicode handling
proc handleBasic(text: string, mode: ComparisonMode): seq[(string, int)] =
  result = @[]
  
  case mode
  of Width:
    # Basic width calculation (each rune is 1 unit)
    for i, r in text.toRunes:
      result.add(($r, 1))
  
  of Display:
    # Basic display (character by character)
    for i, r in text.toRunes:
      result.add(($r, 1))
  
  of Editing:
    # Basic editing (character by character)
    for i, r in text.toRunes:
      result.add(($r, 1))
  
  of Alignment:
    # Basic alignment (split by |, each part aligned to same width)
    let parts = text.split('|')
    let maxLen = parts.mapIt(it.runeLen).max
    
    for part in parts:
      let padding = ' '.repeat(maxLen - part.runeLen)
      result.add((part & padding, part.runeLen))
  
  of Emoji:
    # Basic emoji handling (split by code point)
    for i, r in text.toRunes:
      result.add(($r, 1))
  
  of Boundary:
    # Basic boundary detection (fixed width)
    let width = 40
    var current = ""
    var currentWidth = 0
    
    for r in text.toRunes:
      let rStr = $r
      
      if currentWidth + 1 > width:
        result.add((current, currentWidth))
        current = rStr
        currentWidth = 1
      else:
        current.add(rStr)
        currentWidth += 1
    
    if current.len > 0:
      result.add((current, currentWidth))

# Simulate enhanced Unicode handling
proc handleEnhanced(text: string, mode: ComparisonMode): seq[(string, int)] =
  result = @[]
  
  case mode
  of Width:
    # Enhanced width calculation
    let clusters = unicode_utils.splitIntoGraphemeClusters(text)
    for cluster in clusters:
      var clusterStr = ""
      for r in cluster.codePoints:
        clusterStr.add(toUTF8(r))
      result.add((clusterStr, cluster.width))
  
  of Display:
    # Enhanced display (preserve grapheme clusters)
    let clusters = unicode_utils.splitIntoGraphemeClusters(text)
    for cluster in clusters:
      var clusterStr = ""
      for r in cluster.codePoints:
        clusterStr.add(toUTF8(r))
      result.add((clusterStr, cluster.width))
  
  of Editing:
    # Enhanced editing (by grapheme cluster)
    let clusters = unicode_utils.splitIntoGraphemeClusters(text)
    for cluster in clusters:
      var clusterStr = ""
      for r in cluster.codePoints:
        clusterStr.add(toUTF8(r))
      result.add((clusterStr, cluster.width))
  
  of Alignment:
    # Enhanced alignment (using proper width calculation)
    let parts = text.split('|')
    let maxWidth = parts.mapIt(displayWidth(it)).max
    
    for part in parts:
      let partWidth = displayWidth(part)
      let padding = ' '.repeat(maxWidth - partWidth)
      result.add((part & padding, partWidth))
  
  of Emoji:
    # Enhanced emoji handling (preserves sequences)
    let clusters = unicode_utils.splitIntoGraphemeClusters(text)
    for cluster in clusters:
      var clusterStr = ""
      for r in cluster.codePoints:
        clusterStr.add(toUTF8(r))
      
      # Check if this is an emoji (simplified)
      let isEmoji = cluster.isEmoji or (cluster.width == 2 and clusterStr.runeLen == 1)
      
      result.add((clusterStr, cluster.width))
  
  of Boundary:
    # Enhanced boundary detection (respects width and grapheme clusters)
    let width = 40
    var current = ""
    var currentWidth = 0
    
    let clusters = unicode_utils.splitIntoGraphemeClusters(text)
    for cluster in clusters:
      var clusterStr = ""
      for r in cluster.codePoints:
        clusterStr.add(toUTF8(r))
      
      if currentWidth + cluster.width > width:
        result.add((current, currentWidth))
        current = clusterStr
        currentWidth = cluster.width
      else:
        current.add(clusterStr)
        currentWidth += cluster.width
    
    if current.len > 0:
      result.add((current, currentWidth))

# Draw the comparison for a mode
proc drawComparison(buffer: var Buffer, mode: ComparisonMode, startY: int) =
  let example = examples[mode]
  let titleStyle = Style(fg: ColorCyan, bg: ColorDefault, attrs: {AttrBold})
  let subtitleStyle = Style(fg: ColorYellow, bg: ColorDefault)
  let textStyle = Style(fg: ColorWhite, bg: ColorDefault)
  let highlightStyle = Style(fg: ColorRed, bg: ColorDefault, attrs: {AttrBold})
  
  # Draw title and description
  buffer.print(2, startY, example.title, titleStyle)
  buffer.print(4, startY + 1, example.description, subtitleStyle)
  
  # Draw the original text
  buffer.print(2, startY + 3, "Original: ", textStyle)
  buffer.printAdvanced(12, startY + 3, example.text, textStyle)
  
  # Process with basic and enhanced methods
  let basicResults = handleBasic(example.text, mode)
  let enhancedResults = handleEnhanced(example.text, mode)
  
  # Draw basic handling results
  buffer.print(2, startY + 5, "Basic:", titleStyle)
  
  var yPos = startY + 6
  var xPos = 4
  
  for (text, width) in basicResults:
    buffer.printAdvanced(xPos, yPos, text, textStyle)
    
    # Special handling for different modes
    case mode
    of Width:
      buffer.print(xPos + text.len, yPos, "(" & $width & ")", Style(fg: ColorGreen))
      xPos += text.len + 3
    of Alignment:
      buffer.print(xPos + text.len, yPos, "| ", textStyle)
      yPos += 1
      xPos = 4
    of Boundary:
      yPos += 1
      xPos = 4
    else:
      xPos += width
    
    # Wrap if needed
    if xPos > buffer.width - 10 and mode != Alignment and mode != Boundary:
      yPos += 1
      xPos = 4
  
  # Draw enhanced handling results
  buffer.print(2, yPos + 2, "Enhanced:", titleStyle)
  
  yPos += 3
  xPos = 4
  
  for (text, width) in enhancedResults:
    buffer.printAdvanced(xPos, yPos, text, textStyle)
    
    # Special handling for different modes
    case mode
    of Width:
      buffer.print(xPos + displayWidth(text), yPos, "(" & $width & ")", Style(fg: ColorGreen))
      xPos += displayWidth(text) + 3
    of Alignment:
      buffer.print(xPos + displayWidth(text), yPos, "| ", textStyle)
      yPos += 1
      xPos = 4
    of Boundary:
      yPos += 1
      xPos = 4
    else:
      xPos += width
    
    # Wrap if needed
    if xPos > buffer.width - 10 and mode != Alignment and mode != Boundary:
      yPos += 1
      xPos = 4
  
  # Draw explanation
  buffer.print(2, yPos + 2, "Explanation:", subtitleStyle)
  buffer.print(4, yPos + 3, example.explanation, textStyle)
  
  # Draw differences highlight
  let differences = case mode
    of Width: "CJK characters, emoji, and combining marks have different widths."
    of Display: "Combining characters are kept with their base character in enhanced mode."
    of Editing: "Cursor movements treat grapheme clusters as single units in enhanced mode."
    of Alignment: "Enhanced alignment respects the visual width, not character count."
    of Emoji: "Emoji sequences with skin tones and ZWJ are preserved in enhanced mode."
    of Boundary: "Enhanced text wrapping respects grapheme boundaries and character width."
  
  buffer.print(4, yPos + 5, "Key difference: ", highlightStyle)
  buffer.print(19, yPos + 5, differences, textStyle)

proc main() =
  withTerminal:
    # Get initial size
    let (width, height) = raw.getTerminalSize()
    
    # Create a buffer
    var buffer = newBuffer(width, height)
    
    # Clear screen
    clearScreen()
    
    # Title
    let titleStyle = Style(
      fg: ColorMagenta,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    buffer.print(2, 1, "Unicode Handling Comparison", titleStyle)
    buffer.print(2, 2, "Basic vs Enhanced Unicode Support", Style(fg: ColorYellow))
    
    # Track current mode and scroll position
    var currentMode = Width
    var scrollY = 0
    var running = true
    
    while running:
      # Clear buffer
      buffer.clear()
      
      # Redraw title
      buffer.print(2, 1, "Unicode Handling Comparison", titleStyle)
      buffer.print(2, 2, "Basic vs Enhanced Unicode Support", Style(fg: ColorYellow))
      
      # Draw navigation help
      buffer.print(2, 4, "Use left/right arrow keys to navigate examples, Q to quit",
                  Style(fg: ColorGreen))
      
      # Draw progress indicator
      let modes = [Width, Display, Editing, Alignment, Emoji, Boundary]
      var progressBar = "["
      for i, mode in modes:
        if mode == currentMode:
          progressBar.add("●")
        else:
          progressBar.add("○")
        
        if i < modes.high:
          progressBar.add(" ")
      progressBar.add("]")
      buffer.print(width - progressBar.len - 2, 4, progressBar)
      
      # Draw the current comparison
      drawComparison(buffer, currentMode, 6 - scrollY)
      
      # Draw buffer
      drawBuffer(buffer)
      
      # Process input
      let event = input.pollEvent()
      
      if event.kind == KeyPress:
        case event.key
        of KeyLeft:
          let idx = ord(currentMode)
          currentMode = if idx > 0: ComparisonMode(idx - 1) else: ComparisonMode(high(ComparisonMode).ord)
          scrollY = 0  # Reset scroll position
        of KeyRight:
          let idx = ord(currentMode)
          currentMode = if idx < high(ComparisonMode).ord: ComparisonMode(idx + 1) else: ComparisonMode(0)
          scrollY = 0  # Reset scroll position
        of KeyUp:
          scrollY = max(0, scrollY - 5)
        of KeyDown:
          scrollY += 5
        of KeyQ:
          running = false
        else:
          discard

# Create a sample report on Unicode text processing
proc generateReport(filePath: string) =
  # Create a text report comparing basic and enhanced Unicode handling
  var report = """
# Unicode Text Processing Comparison Report

This report compares basic Unicode handling methods with libterminal's enhanced Unicode support.

## Overview of Unicode Challenges

Unicode text processing presents several challenges:

1. **Display Width Calculation**: Characters have varying display widths (e.g., Latin vs CJK)
2. **Grapheme Clusters**: Multiple code points may form a single visual character
3. **Bidirectional Text**: Mixing right-to-left and left-to-right scripts
4. **Emoji Sequences**: Complex emoji using ZWJ, variation selectors, and skin tones
5. **Text Boundaries**: Word and line breaking across different scripts

## Basic vs Enhanced Unicode Handling

| Feature | Basic Handling | Enhanced Handling (libterminal) |
|---------|---------------|----------------------------|
| Width Calculation | Treats all characters as 1 unit wide | Correctly handles full-width characters (CJK, emoji) |
| Grapheme Clusters | Splits combining characters | Preserves combining characters with their base |
| Cursor Movement | Moves by code point | Moves by grapheme cluster |
| Text Alignment | Uses character count | Uses visual width |
| Emoji | Splits sequences into individual code points | Preserves emoji sequences as single units |
| Bidirectional Text | Poor handling of mixed RTL/LTR | Respects text direction |

## Test Cases and Results

### Case 1: Width Calculation
```
Text: Hello 你好 こんにちは 안녕하세요
Basic: 19 characters, each 1 unit width
Enhanced: 19 characters with varying widths (Latin: 1, CJK: 2)
```

### Case 2: Combining Characters
```
Text: é (e + ́)
Basic: Treats as two separate characters
Enhanced: Treats as a single grapheme cluster
```

### Case 3: Emoji Sequences
```
Text: 👨‍👩‍👧‍👦 (family emoji)
Basic: Splits into 7 separate code points
Enhanced: Treats as a single grapheme cluster
```

### Case 4: Bidirectional Text
```
Text: Hello مرحبا World
Basic: Incorrect visual ordering
Enhanced: Proper bidirectional algorithm implementation
```

## Performance Considerations

The enhanced Unicode support does come with some performance cost:

- Grapheme cluster detection requires more processing
- Width calculation requires lookups in Unicode tables
- Bidirectional algorithm adds complexity

However, modern optimizations (like caching) minimize this impact, and the benefits
of correct Unicode handling far outweigh the performance considerations for most applications.

## Conclusion

Proper Unicode handling is essential for applications that:

1. Support multiple languages
2. Display user-generated content
3. Need precise text layout
4. Require text editing functionality

libterminal provides enhanced Unicode support that handles these challenges correctly,
resulting in a better user experience across languages and scripts.
"""

  # Write the report to file
  writeFile(filePath, report)
  echo "Report generated: " & filePath

when isMainModule:
  if paramCount() > 0 and paramStr(1) == "--report":
    # Generate a report
    let reportPath = 
      if paramCount() > 1: paramStr(2)
      else: "unicode_comparison_report.md"
    generateReport(reportPath)
  else:
    # Run the interactive comparison
    main()