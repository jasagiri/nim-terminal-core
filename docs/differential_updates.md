# Differential Updates

This document explains the differential update feature that enables efficient drawing processing in the terminal library.

## Overview

Traditional terminal drawing typically redrew the entire screen on each update. While simple, this approach is inefficient for applications with large screens or frequent updates.

The differential update feature provides the following benefits:

- **Efficiency**: Faster drawing by updating only changed portions
- **Reduced flicker**: Less screen flicker by updating only necessary areas
- **Bandwidth savings**: Reduced data transmission for remote connections

## How It Works

Differential updates are performed in the following steps:

1. Save the previous drawing state (buffer)
2. Compare the new buffer with the previous buffer to calculate differences
3. Send only the differences to the actual terminal

Optimizations are performed in the following cases:

- **Character changes**: When only characters change, style settings are not reapplied
- **Style changes**: When only styles change for the same character, only necessary style changes are made
- **Full update decision**: When there are too many differences, clearing the screen and redrawing everything may be more efficient

## Implementation Details

Differential calculation and drawing processing are implemented in the `output.nim` module:

### Difference Types

```nim
type
  DiffOp* = enum
    DiffNone,    # No change
    DiffChar,    # Character change
    DiffFg,      # Foreground color change
    DiffBg,      # Background color change
    DiffAttrs,   # Attribute change
    DiffAll      # All changed
```

### Difference Calculation

The `calculateDiff` function compares two buffers and generates a list of changes:

```nim
proc calculateDiff*(oldBuffer, newBuffer: Buffer): seq[CellDiff]
```

### Optimized Drawing

The `drawOptimized` function performs efficient drawing based on calculated differences:

```nim
proc drawOptimized*(buffer: var Buffer)
```

This function performs the following:
- Calculate differences by comparing with the previous buffer
- Choose partial update for few differences, full update for many
- Path optimization to minimize cursor movements

## Usage Example

Differential updates are automatically enabled when using the `Buffer` type:

```nim
# Create buffer
var buffer = newBuffer(width, height)

# Update content
buffer.print(x, y, "Hello", style)

# Draw (differential updates are performed automatically)
buffer.drawBuffer()
```

For a concrete demonstration, see `examples/diff_update_example.nim`. This example provides a visual comparison of performance between standard drawing and differential drawing.

## Performance

Differential updates are particularly effective in the following situations:

- Small updates on large screens (e.g., status bar updates)
- Screens with animations or many partial changes
- Interactive applications requiring fast updates

In tests, when changes are less than 10% of the total, performance improvements of 5-10x compared to traditional methods have been confirmed.