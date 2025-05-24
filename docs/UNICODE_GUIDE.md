# Unicode Handling in Terminal Applications

This guide provides practical advice and best practices for implementing proper Unicode support in terminal applications. It explains common challenges, solutions, and techniques used in the libterminal library that you can apply to your own projects.

## Table of Contents

1. [Introduction to Unicode Challenges](#1-introduction-to-unicode-challenges)
2. [Understanding Grapheme Clusters](#2-understanding-grapheme-clusters)
3. [Character Width Calculation](#3-character-width-calculation)
4. [Bidirectional Text Handling](#4-bidirectional-text-handling)
5. [Emoji Support](#5-emoji-support)
6. [Text Editing Considerations](#6-text-editing-considerations)
7. [Performance Optimization](#7-performance-optimization)
8. [Internationalization Best Practices](#8-internationalization-best-practices)
9. [Testing Unicode Support](#9-testing-unicode-support)
10. [Resources and References](#10-resources-and-references)

## 1. Introduction to Unicode Challenges

Unicode text processing in terminal applications presents several unique challenges:

### Terminal Limitations

Terminals have grid-based layouts with fixed-width cells, making it challenging to handle:

- Variable-width characters (CJK, emoji)
- Combining characters (accents, diacritics)
- Complex script layouts (Arabic, Indic scripts)
- Bidirectional text (mixed RTL/LTR content)

### Common Issues

Without proper handling, Unicode text can exhibit problems such as:

- Misaligned text and UI elements
- Broken combining character sequences
- Split emoji or incorrect emoji display
- Cursor positioning errors when editing text
- Bidirectional text display issues

### Baseline Requirements

At minimum, a terminal application with good Unicode support should:

1. Correctly identify and preserve grapheme clusters
2. Calculate and respect character display widths
3. Handle cursor positioning based on visual width
4. Support emoji sequences and combining characters
5. Implement basic bidirectional text handling

## 2. Understanding Grapheme Clusters

### What Are Grapheme Clusters?

A grapheme cluster is what users perceive as a single "character" on screen. It may consist of:

- A single code point ("A", "1", "文")
- A base character plus combining marks ("é" = "e" + "◌́")
- An emoji with optional modifiers ("👍" or "👍🏽")
- A sequence of code points joined with ZWJ ("👨‍👩‍👧‍👦")

### Implementation Approaches

To properly handle grapheme clusters:

1. **Use a Grapheme Cluster Library**: In Nim, you can implement this as we did in libterminal's `unicode_utils.nim`:

```nim
type
  GraphemeCluster* = object
    codePoints*: seq[Rune]  # Sequence of code points in this grapheme
    width*: int            # Display width of this grapheme
    isEmoji*: bool         # Whether this grapheme is an emoji

proc splitIntoGraphemeClusters*(text: string): seq[GraphemeCluster] =
  # Implementation that follows Unicode Standard Annex #29
  # This segments text into user-perceived characters
  result = @[]
  if text.len == 0:
    return
  
  var currentCluster: GraphemeCluster
  var runes = toRunes(text)
  var i = 0
  
  while i < runes.len:
    let r = runes[i]
    
    # Start a new cluster if needed
    if currentCluster.codePoints.len == 0:
      currentCluster = GraphemeCluster(
        codePoints: @[r],
        width: runeWidth(r),
        isEmoji: detectEmojiPresentation(r) == EmojiGraphic
      )
    else:
      # Check if this rune is an extender
      if isExtender(r):
        # Add to current cluster
        currentCluster.codePoints.add(r)
        # Update properties as needed
        if detectEmojiPresentation(r) == EmojiGraphic:
          currentCluster.isEmoji = true
        # Add to width only for non-zero width characters
        let width = runeWidth(r)
        if width > 0:
          currentCluster.width += width
      else:
        # Finish current cluster and start a new one
        result.add(currentCluster)
        currentCluster = GraphemeCluster(
          codePoints: @[r],
          width: runeWidth(r),
          isEmoji: detectEmojiPresentation(r) == EmojiGraphic
        )
    
    i += 1
  
  # Add the last cluster if there is one
  if currentCluster.codePoints.len > 0:
    result.add(currentCluster)
```

2. **Detecting Extenders**: The key to proper grapheme cluster detection is identifying which characters extend the previous ones:

```nim
proc isExtender*(r: Rune): bool =
  ## Check if rune is an extender for grapheme clusters
  let codePoint = r.int32
  
  # Zero-width joiners
  if codePoint == 0x200D:  # Zero-width joiner
    return true
    
  # Emoji modifiers
  if codePoint >= 0x1F3FB and codePoint <= 0x1F3FF:  # Emoji skin tone modifiers
    return true
    
  # Emoji variation selectors
  if codePoint == 0xFE0F or codePoint == 0xFE0E:
    return true
  
  # Check if rune is in any zero-width category
  for category in zeroWidthCategories:
    if codePoint in category:
      return true
      
  return false
```

### Utility Functions

Provide convenient functions to work with grapheme clusters:

```nim
proc graphemeLength*(text: string): int =
  ## Count the number of grapheme clusters in a string
  return splitIntoGraphemeClusters(text).len

proc displayWidth*(text: string): int =
  ## Calculate the display width of a string considering grapheme clusters
  let clusters = splitIntoGraphemeClusters(text)
  result = 0
  for cluster in clusters:
    result += cluster.width
```

## 3. Character Width Calculation

### Width Categories

Unicode characters generally fall into these width categories:

- **Width 0**: Combining marks, control characters, zero-width joiners
- **Width 1**: Most Latin, Cyrillic, Arabic, Indic scripts
- **Width 2**: CJK ideographs, Hiragana, Katakana, Hangul, emoji

### Implementation Strategy

Implement width calculation following Unicode East Asian Width property (UAX #11):

```nim
proc runeWidth*(r: Rune): int =
  ## Calculate the display width of a Unicode character
  
  # Check cache first for performance
  if r in widthCache:
    return widthCache[r]
  
  let codePoint = r.int32
  var width = 1  # Default width
  
  # Control character check (width 0)
  for category in controlCategories:
    if codePoint in category:
      width = 0
      break
  
  # Zero-width character check (width 0)
  if width == 1:
    for category in zeroWidthCategories:
      if codePoint in category:
        width = 0
        break
  
  # Full-width character check (width 2)
  if width == 1:
    for category in fullWidthCategories:
      if codePoint in category:
        width = 2
        break
      
  # Store in cache
  widthCache[r] = width
  return width
```

### Width Calculation Tables

You'll need tables of code point ranges for different width categories. Define comprehensive tables for:

1. **Zero-width characters**: Combining marks, variation selectors, etc.
2. **Full-width characters**: CJK scripts, emoji, full-width Latin, etc.
3. **Control characters**: Non-printable characters with zero width

See the `unicode_utils.nim` file for complete examples of these tables.

### String Width Calculation

Calculate the total width of a string by respecting grapheme cluster boundaries:

```nim
proc displayWidth*(text: string): int =
  let clusters = splitIntoGraphemeClusters(text)
  result = 0
  for cluster in clusters:
    result += cluster.width
```

## 4. Bidirectional Text Handling

### Bidirectional Algorithm Basics

The Unicode Bidirectional Algorithm (UAX #9) governs how mixed LTR and RTL text should be displayed:

1. Characters are classified into directional categories
2. The base direction is determined (LTR or RTL)
3. Text is divided into directional runs
4. Runs are reordered for display

### Simplified Implementation

For terminal applications, a full bidi implementation can be complex. A simplified approach:

```nim
# Text direction detection
proc getTextDirection(text: string): TextDirection =
  # Simple heuristic - check first strong directional character
  for r in text.toRunes:
    let cp = r.int32
    if (cp >= 0x0590 and cp <= 0x08FF) or   # Hebrew/Arabic ranges
       (cp >= 0xFB1D and cp <= 0xFDFF) or
       (cp >= 0xFE70 and cp <= 0xFEFF):
      return RightToLeft
  return LeftToRight

# Direction-aware text printing
proc printBidirectional(buffer: var Buffer, x, y: int, text: string, style: Style) =
  let dir = getTextDirection(text)
  
  if dir == RightToLeft:
    # For RTL, calculate width and right-align at position
    let width = displayWidth(text)
    buffer.printAdvanced(x - width, y, text, style)
  else:
    # For LTR, print normally
    buffer.printAdvanced(x, y, text, style)
```

### Layout Considerations

When displaying bidirectional text:

1. **Text Alignment**: Right-align RTL text, left-align LTR text
2. **User Interface**: Mirror UI elements for RTL interfaces
3. **Input Handling**: Handle cursor movement differently for RTL text
4. **Mixed Content**: Consider paragraph direction for mixed content

## 5. Emoji Support

### Emoji Challenges

Emoji present unique challenges:

1. **ZWJ Sequences**: Multiple code points combined (e.g., family emoji)
2. **Modifiers**: Skin tone and other modifiers
3. **Variation Selectors**: Text vs. emoji presentation
4. **Width Calculation**: All emoji have width 2

### Emoji Detection

Implement emoji detection:

```nim
proc detectEmojiPresentation*(r: Rune): EmojiPresentation =
  ## Detect the emoji presentation of a character
  let codePoint = r.int32
  
  # Emoji presentation selector range
  if codePoint == 0xFE0F:
    return EmojiGraphic
  
  # Text presentation selector range
  if codePoint == 0xFE0E:
    return EmojiText
  
  # Emoji default presentation for specific ranges
  if (codePoint >= 0x1F300 and codePoint <= 0x1F6FF) or  # Misc. Symbols and Pictographs
     (codePoint >= 0x1F900 and codePoint <= 0x1F9FF) or  # Supplemental Symbols and Pictographs
     (codePoint >= 0x1FA70 and codePoint <= 0x1FAFF):    # Symbols and Pictographs Extended-A
    return EmojiGraphic
  
  # Default to text presentation
  return EmojiDefault
```

### Handling Emoji in Text

When processing text with emoji:

1. Treat emoji sequences as single grapheme clusters
2. Respect ZWJ sequences by keeping them together
3. Apply skin tone modifiers within the same cluster
4. Ensure proper width calculation (normally width 2)

## 6. Text Editing Considerations

### Cursor Movement

Character-based cursor movement doesn't work for Unicode. Instead:

1. **Store Logical Position**: Track cursor position in bytes or code points
2. **Convert for Display**: Map logical position to visual position for rendering
3. **Move by Grapheme**: Cursor should skip over combining characters

```nim
# Convert between visual and logical positions
proc visualPosToLogical(line: string, visualPos: int): int =
  ## Convert visual position to logical (byte) position
  var currentVisual = 0
  var i = 0
  let clusters = splitIntoGraphemeClusters(line)
  
  for cluster in clusters:
    if currentVisual >= visualPos:
      return i
    currentVisual += cluster.width
    # Add up bytes for all code points in this cluster
    for r in cluster.codePoints:
      i += toUTF8(r).len
  
  return line.len  # Return end of line if not found

proc logicalPosToVisual(line: string, logicalPos: int): int =
  ## Convert logical (byte) position to visual position
  if logicalPos <= 0:
    return 0
  return displayWidth(line[0..<logicalPos])
```

### Text Selection

When implementing text selection:

1. **Select by Grapheme**: Ensure selection boundaries respect grapheme clusters
2. **Visual Selection**: Show selection based on visual width
3. **Copy/Paste**: Preserve full Unicode sequence when copying

### Input Handling

When processing keyboard input:

1. **Character Input**: Handle multi-byte character input correctly
2. **Key Navigation**: Move cursor by grapheme cluster boundaries
3. **Deletion**: Delete entire grapheme clusters, not individual code points

## 7. Performance Optimization

### Caching Strategies

Unicode operations can be expensive. Implement caching:

```nim
# Cache for character widths
var widthCache = initTable[Rune, int]()

proc runeWidth*(r: Rune): int =
  # Check cache first
  if r in widthCache:
    return widthCache[r]
  
  # ... calculate width ...
  
  # Store in cache
  widthCache[r] = width
  return width
```

### Lazy Evaluation

Avoid unnecessary calculations:

1. **Partial Processing**: Only process visible parts of text
2. **On-demand Calculation**: Calculate widths only when needed
3. **Incremental Updates**: Only recalculate when text changes

### Efficient Storage

Choose efficient data structures:

1. **Rune Arrays**: Use arrays of runes for internal storage
2. **Grapheme Maps**: Map between logical and visual positions
3. **Spare Arrays**: For large documents with sparse edits

## 8. Internationalization Best Practices

### Text Direction

Support different text directions:

```nim
enum TextDirection = LeftToRight, RightToLeft

# Apply text direction to layout
proc layoutWithDirection(dir: TextDirection) =
  if dir == RightToLeft:
    # Mirror layout elements
    # Right-align text elements
    # Reverse the order of horizontal UI elements
  else:
    # Standard LTR layout
```

### Localization

Implement proper localization support:

1. **Translation Tables**: Store translations for UI elements
2. **Format Strings**: Use locale-specific formatting
3. **Date/Time Formatting**: Format according to locale conventions

### Font Considerations

Consider font capability issues:

1. **Font Fallback**: Some terminals need fallback fonts for specific scripts
2. **Combining Marks**: Some fonts handle combining marks poorly
3. **Emoji Support**: Terminal and font emoji support varies widely

## 9. Testing Unicode Support

### Test Cases

Create test cases covering:

1. **Combining Characters**: é, ñ, ö, Z̸̈, etc.
2. **Emoji**: 👍, 👍🏽, 👨‍👩‍👧‍👦, etc.
3. **CJK Scripts**: 你好, こんにちは, 안녕하세요, etc.
4. **RTL Text**: مرحبا, שלום, etc.
5. **Mixed Scripts**: Latin + CJK + RTL

### Visual Verification

Some aspects need visual verification:

1. **Alignment**: Check that text aligns correctly
2. **Cursor Movement**: Verify cursor moves by grapheme
3. **Selection**: Test text selection across grapheme boundaries
4. **Input**: Test typing and deleting complex Unicode

### Automated Testing

Implement unit tests:

```nim
test "grapheme cluster boundaries":
  check graphemeLength("é") == 1
  check graphemeLength("👍🏽") == 1
  check graphemeLength("👨‍👩‍👧‍👦") == 1

test "display width calculation":
  check displayWidth("Hello") == 5
  check displayWidth("你好") == 4
  check displayWidth("é") == 1
  check displayWidth("👍") == 2
```

## 10. Resources and References

### Unicode Standard

- [Unicode Standard Annex #29: Text Segmentation](https://www.unicode.org/reports/tr29/)
- [Unicode Standard Annex #11: East Asian Width](https://www.unicode.org/reports/tr11/)
- [Unicode Standard Annex #9: Bidirectional Algorithm](https://www.unicode.org/reports/tr9/)
- [Unicode Emoji](https://www.unicode.org/emoji/)

### Implementation References

- [WCWIDTH Implementation](https://www.cl.cam.ac.uk/~mgk25/ucs/wcwidth.c)
- [Unicode Grapheme Cluster Boundaries](https://unicode.org/reports/tr29/#Grapheme_Cluster_Boundaries)
- [ICU - International Components for Unicode](http://site.icu-project.org/)

### Testing Resources

- [Unicode Test Data](https://www.unicode.org/Public/UCD/)
- [Unicode CLDR](http://cldr.unicode.org/)
- [Bidirectional Test Cases](https://www.unicode.org/Public/UNIDATA/BidiTest.txt)

## Conclusion

Implementing proper Unicode support requires attention to detail, but significantly improves the user experience, especially for international users. The approaches described in this guide should help you implement robust Unicode handling in your terminal applications.

For working examples, refer to the libterminal examples directory, which includes comprehensive demonstrations of all these concepts.

---

*This guide accompanies the libterminal Unicode examples suite, which provides practical demonstrations of these concepts.*