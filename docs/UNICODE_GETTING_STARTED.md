# Getting Started with Unicode in libterminal

Welcome to libterminal's Unicode support! This guide will help you quickly get started with proper Unicode handling in your terminal applications.

## Quick Start

### Basic Setup

1. Import the necessary modules:

```nim
import libterminal
import std/unicode
```

2. Use the enhanced printing functions for proper Unicode handling:

```nim
# Initialize terminal
withTerminal:
  # Get terminal size
  let (width, height) = raw.getTerminalSize()
  
  # Create a buffer
  var buffer = newBuffer(width, height)
  
  # Print Unicode text with proper handling
  buffer.printAdvanced(2, 3, "Hello 世界! Emoji: 👋", Style())
  
  # Draw the buffer
  drawBuffer(buffer)
  
  # Wait for keypress
  discard input.pollEvent()
```

### Handling Different Scripts

For applications that need to support multiple languages and scripts:

```nim
# Text in various scripts
let englishText = "Hello World"
let japaneseText = "こんにちは世界"
let arabicText = "مرحبا بالعالم"
let emojiText = "👨‍👩‍👧‍👦 👍 🚀"

# Print with proper alignment
buffer.printAdvanced(5, 5, englishText, Style())
buffer.printAdvanced(5, 6, japaneseText, Style())
buffer.printAdvanced(5, 7, arabicText, Style())
buffer.printAdvanced(5, 8, emojiText, Style())
```

## Common Unicode Tasks

### Calculate Text Width

To properly calculate text width (important for alignment and layout):

```nim
let text = "Hello 你好 👋"
let width = displayWidth(text)  # Returns the visual width (11)
```

### Count Characters Correctly

To count user-perceived characters (rather than bytes or code points):

```nim
let text = "é 👨‍👩‍👧‍👦 안녕"
let count = graphemeLength(text)  # Returns 4, not the number of code points
```

### Text Alignment

To center text with proper width calculation:

```nim
proc centerText(text: string, width: int): string =
  let textWidth = displayWidth(text)
  let padding = max(0, width - textWidth)
  let leftPadding = padding div 2
  let rightPadding = padding - leftPadding
  return " ".repeat(leftPadding) & text & " ".repeat(rightPadding)

# Use it
let centeredText = centerText("Hello 世界", 20)
buffer.printAdvanced(0, 10, centeredText, Style())
```

### Text Truncation

To truncate text while respecting grapheme clusters:

```nim
proc truncateText(text: string, maxWidth: int): string =
  let clusters = splitIntoGraphemeClusters(text)
  var result = ""
  var currentWidth = 0
  
  for cluster in clusters:
    if currentWidth + cluster.width <= maxWidth:
      # Add all codepoints in this cluster
      for r in cluster.codePoints:
        result.add(toUTF8(r))
      currentWidth += cluster.width
    else:
      break
      
  return result

# Use it
let truncated = truncateText("Very long text with emoji 😊 that needs truncating", 20)
buffer.printAdvanced(0, 12, truncated, Style())
```

## What Makes libterminal's Unicode Support Special?

1. **Grapheme Cluster Awareness**: Treats user-perceived characters as single units
2. **Proper Width Calculation**: Handles full-width characters like CJK and emoji correctly
3. **Bidirectional Text Support**: Manages right-to-left languages properly
4. **Emoji Support**: Correctly displays emoji, including sequences with modifiers

## Key Concepts to Understand

### Grapheme Clusters

A grapheme cluster is what a user perceives as a single character. It might consist of:
- A single code point ("A", "1")
- A base character plus combining marks (é = e + ◌́)
- An emoji with modifiers (👍🏽)
- A sequence joined with zero-width joiners (👨‍👩‍👧‍👦)

### Display Width

Different characters take up different amounts of space:
- Latin, Arabic, Cyrillic, etc.: 1 unit wide
- CJK characters (中文, 日本語, 한글): 2 units wide
- Emoji (😊, 👍): 2 units wide
- Combining marks (◌́, ◌̀, ◌̈): 0 units wide

### Text Direction

Some languages are written right-to-left:
- Arabic, Hebrew: main text direction is RTL
- Mixed text: needs special handling when combining LTR and RTL content

## Next Steps

After you've mastered the basics:

1. **Explore Examples**: Run the examples in the `examples/` directory:
   ```
   nim c -r examples/enhanced_unicode_example.nim
   ```

2. **Read the Developer Guide**: For a deeper understanding, see [Unicode Handling in Terminal Applications](UNICODE_GUIDE.md).

3. **Keep the Cheat Sheet Handy**: For quick reference, use the [Unicode Cheat Sheet](UNICODE_CHEATSHEET.md).

4. **Try the Interactive Demo**: Run the interactive demo to explore Unicode features:
   ```
   nim c -r examples/interactive_unicode_demo.nim
   ```

## Common Pitfalls to Avoid

1. **Don't** use `len()` to count characters in a string (it counts bytes)
2. **Don't** use `runeLen` for visual layout (it counts code points, not visual width)
3. **Don't** split or truncate text at arbitrary positions (respect grapheme cluster boundaries)
4. **Don't** assume all characters have the same width
5. **Don't** use standard print functions for complex Unicode text (use `printAdvanced()` instead)

## Quick Solutions for Common Issues

| Issue | Solution |
|-------|----------|
| Text alignment is incorrect | Use `displayWidth()` to calculate text width |
| Emoji or combining characters are broken | Use `printAdvanced()` instead of `print()` |
| Character count is wrong | Use `graphemeLength()` to count characters |
| Text truncation breaks characters | Truncate at grapheme cluster boundaries |
| RTL text displayed incorrectly | Consider text direction in layout |

## Need Help?

- Check the complete [Unicode documentation](../README_UNICODE.md)
- Run the [`unicode_comparison.nim`](../examples/unicode_comparison.nim) example to understand differences
- See implementation details in the source code of [`unicode_utils.nim`](../src/libterminal/private/unicode_utils.nim)

---

*This Getting Started guide is part of the libterminal Unicode support documentation. For more detailed information, see the [complete Unicode documentation](../README_UNICODE.md).*