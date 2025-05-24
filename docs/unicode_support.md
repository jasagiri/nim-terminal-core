# Unicode Support in Nim Terminal Library

This document outlines the Unicode support implemented in the Nim Terminal Library and provides guidance on how to use these features.

## Overview

The library provides comprehensive Unicode text handling capabilities, including:

1. **Grapheme Cluster Handling**: Properly handles Unicode grapheme clusters (user-perceived characters)
2. **Bidirectional Text Support**: Supports right-to-left languages
3. **Width Calculation**: Correctly calculates visual width of Unicode text (CJK characters, emojis, etc.)
4. **Text Wrapping**: Unicode-aware text wrapping with multiple modes
5. **Cursor Positioning**: Maps between logical (byte) and visual (screen) positions

## Grapheme Clusters

A grapheme cluster is what users perceive as a single character, but may consist of multiple Unicode code points. The library provides functions to work with grapheme clusters:

```nim
import libterminal

# Count graphemes (perceived characters) in a string
let emoji = "👨‍👩‍👧‍👦"
echo graphemeLength(emoji)  # 1 (a single family emoji)
echo emoji.runeLen          # 7 (multiple code points)

# Split text into grapheme clusters
let clusters = splitIntoGraphemeClusters(text)
for cluster in clusters:
  echo "Width: ", cluster.width
  echo "Is emoji: ", cluster.isEmoji
  echo "Direction: ", cluster.dir
```

## Text Direction

The library can detect and handle bidirectional text:

```nim
import libterminal

let arabicText = "مرحبا بالعالم"
echo getTextDirection(arabicText)  # RightToLeft

# Print with proper bidirectional handling
buffer.printBidirectional(x, y, mixedText, style)
```

## Display Width

Unicode characters have different display widths. The library accurately calculates visual widths:

```nim
import libterminal

let text = "Hello 世界"
echo displayWidth(text)  # 9 (5 for "Hello " + 4 for "世界")

# Print text with accurate width handling
buffer.printAdvanced(x, y, text, style)
```

## Text Wrapping

The library provides multiple text wrapping modes that respect Unicode properties:

```nim
import libterminal

let text = "This is a long text with Unicode characters 你好 مرحبا"

# Different wrapping modes
let noWrapLines = splitLines(text, 40, WrapNone)
let charWrapLines = splitLines(text, 40, WrapCharacter)
let wordWrapLines = splitLines(text, 40, WrapWord)

# Print multi-line text with wrapping
buffer.printMultiLine(x, y, text, style, 40, WrapWord)
```

## Cursor Positioning

The library maps between logical positions (byte offsets) and visual positions (screen columns):

```nim
import libterminal

let text = "Hello 世界"

# Convert between logical and visual positions
let visualPos = logicalPosToVisual(text, 7)  # Position at start of "界"
let logicalPos = visualPosToLogical(text, 8)  # 8th visual column to byte offset

# Print text with cursor
buffer.printTextWithCursor(x, y, text, cursorPos, normalStyle, cursorStyle)
```

## Implementation Details

The Unicode support is implemented primarily in:
- `src/libterminal/private/unicode_utils.nim` - Core Unicode functionality
- `src/libterminal/output.nim` - Unicode-aware drawing functions

Major data structures:
- `GraphemeCluster` - Represents a single user-perceived character
- `TextDirection` - Enum for text direction (LTR or RTL)
- `LineWrapMode` - Enum for different text wrapping strategies

The implementation focuses on balancing correctness with performance, using caching and optimized algorithms where possible.

## Limitations

Current limitations:
- The bidirectional algorithm is simplified and doesn't handle all cases in the Unicode Bidirectional Algorithm
- Complex scripts like Arabic may not display with correct ligatures (terminal limitation)
- Full UAX #29 grapheme breaking rules aren't implemented for performance reasons

## Future Improvements

Planned improvements:
- Full Unicode Bidirectional Algorithm implementation
- Improved handling of combining marks
- Better support for non-spacing marks and zero-width joiners
- Enhanced segmentation for complex scripts