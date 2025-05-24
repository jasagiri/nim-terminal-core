# Unicode Handling Cheat Sheet

Quick reference for working with Unicode text in terminal applications using libterminal.

## Core Functions

### Character and Width Functions

```nim
# Get width of a Unicode character (0, 1, or 2)
let width = runeWidth('你'.Rune)  # Returns 2

# Calculate display width of a string
let textWidth = displayWidth("Hello 你好")  # Returns 9

# Count grapheme clusters (user-perceived characters)
let charCount = graphemeLength("e\u0301")  # Returns 1, not 2

# Split text into grapheme clusters
let clusters = splitIntoGraphemeClusters("👨‍👩‍👧‍👦")
echo clusters.len  # Returns 1
echo clusters[0].width  # Returns 2
```

### Printing Functions

```nim
# Basic printing (character by character)
buffer.print(x, y, "Hello 世界", style)

# Advanced printing (grapheme cluster aware)
buffer.printAdvanced(x, y, "こんにちは👨‍👩‍👧‍👦", style)

# Advanced printing with RGB colors
buffer.printRGBAdvanced(x, y, "你好", 
                    RGBColor(r: 255, g: 100, b: 100),
                    RGBColor(r: 0, g: 0, b: 0))
```

### Text Editing Functions

```nim
# Convert between visual and logical positions
let logicalPos = visualPosToLogical(text, visualX)
let visualPos = logicalPosToVisual(text, bytePos)

# Move cursor by grapheme clusters
proc moveCursorLeft(text: string, curPos: var int) =
  let clusters = splitIntoGraphemeClusters(text[0..<curPos])
  if clusters.len > 0:
    let lastCluster = clusters[^1]
    curPos -= totalBytes(lastCluster.codePoints)
```

### Bidirectional Text

```nim
# Detect text direction
proc getTextDirection(text: string): TextDirection =
  for r in text.toRunes:
    if isRTL(r): return RightToLeft
  return LeftToRight

# Print text with direction awareness
if getTextDirection(text) == RightToLeft:
  # Right-align RTL text
  buffer.printAdvanced(x + availableWidth - displayWidth(text), y, text, style)
else:
  buffer.printAdvanced(x, y, text, style)
```

## Common Character Categories

### Display Width Categories

| Width | Description | Examples |
|-------|-------------|----------|
| 0     | Zero-width characters | Combining marks (◌́ ◌̀ ◌̂), joiners |
| 1     | Standard-width characters | Latin, Cyrillic, Arabic, Indic |
| 2     | Full-width characters | CJK, Emoji, full-width forms |

### Grapheme Extenders

These characters extend the previous character to form a single grapheme cluster:

- Combining marks (accents, diacritics)
- Emoji variation selectors (FE0E, FE0F)
- Emoji modifiers (skin tones: 1F3FB-1F3FF)
- Zero-width joiners (200D)

## Common Unicode Operations

### Avoid These Mistakes

❌ **Don't** calculate string length with `.len` or `.runeLen`
✅ **Do** use `graphemeLength()` for character count

❌ **Don't** move cursor by bytes or runes
✅ **Do** move cursor by grapheme clusters

❌ **Don't** use fixed-width assumptions for all text
✅ **Do** calculate display width with `displayWidth()`

### Best Practice Examples

#### Proper Text Truncation

```nim
proc truncateText(text: string, maxWidth: int): string =
  var result = ""
  var currentWidth = 0
  
  let clusters = splitIntoGraphemeClusters(text)
  for cluster in clusters:
    if currentWidth + cluster.width <= maxWidth:
      # Add all codepoints in this cluster
      for r in cluster.codePoints:
        result.add(toUTF8(r))
      currentWidth += cluster.width
    else:
      break
  
  # Add ellipsis if truncated
  if result.len < text.len:
    result.add("…")
  
  return result
```

#### Aligned Text Layout

```nim
proc centerText(text: string, width: int): string =
  let textWidth = displayWidth(text)
  if textWidth >= width:
    return text
  
  let padding = width - textWidth
  let leftPad = padding div 2
  let rightPad = padding - leftPad
  
  return " ".repeat(leftPad) & text & " ".repeat(rightPad)
```

#### Bidirectional Text Layout

```nim
proc layoutParagraph(text: string, width: int, buffer: var Buffer, startY: int): int =
  let direction = getTextDirection(text)
  var lines = wrapText(text, width)
  var y = startY
  
  for line in lines:
    if direction == RightToLeft:
      # Right-align for RTL text
      buffer.printAdvanced(width - displayWidth(line), y, line, Style())
    else:
      buffer.printAdvanced(0, y, line, Style())
    y += 1
  
  return y - startY  # Return number of lines printed
```

## Unicode Quick Reference

### Special Character Ranges

- Basic Latin: U+0000 - U+007F
- Latin-1 Supplement: U+0080 - U+00FF
- Combining Diacritical Marks: U+0300 - U+036F
- Arabic: U+0600 - U+06FF
- CJK Unified Ideographs: U+4E00 - U+9FFF
- Emoji: U+1F000 - U+1F9FF (various ranges)

### Special Code Points

- Zero-width joiner (ZWJ): U+200D
- Left-to-right mark (LRM): U+200E
- Right-to-left mark (RLM): U+200F
- Text variation selector: U+FE0E
- Emoji variation selector: U+FE0F
- Replacement character: U+FFFD

### Emoji Skin Tone Modifiers

- Light skin tone: U+1F3FB
- Medium-light skin tone: U+1F3FC
- Medium skin tone: U+1F3FD
- Medium-dark skin tone: U+1F3FE
- Dark skin tone: U+1F3FF

## Performance Tips

- Cache width calculations for frequently used characters
- Pre-split static text into grapheme clusters
- Use buffer-based drawing instead of character-by-character
- Process only visible parts of large text blocks
- Consider lazy evaluation for expensive operations

## Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| Broken combining marks | Use `printAdvanced()` instead of `print()` |
| Cursor positioning errors | Convert between visual and logical positions |
| Text alignment problems | Calculate width with `displayWidth()` |
| Split emoji | Process as grapheme clusters |
| Truncated text in UI | Account for full-width characters when calculating space |
| RTL text display issues | Apply bidirectional algorithm rules |

---

*For more detailed information, see the [Unicode Handling Guide](UNICODE_GUIDE.md) and complete examples.*