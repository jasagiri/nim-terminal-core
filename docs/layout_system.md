# Layout System

The Nim Terminal Library provides a flexible layout system for organizing UI components in terminal applications. The layout system supports hierarchical layouts, flexible sizing, and various layout strategies.

## Key Features

- **Hierarchical Layouts**: Support for nested layouts with parent-child relationships
- **Flexible Sizing**: Fixed, percentage, and automatic sizing options
- **Grid Layouts**: Easy creation of grid-based UIs
- **Margins and Padding**: Fine control over spacing and positioning
- **Rectangle Operations**: Comprehensive geometry operations for positioning

## Basic Concepts

### Layout Nodes

A `LayoutNode` represents a container in the layout hierarchy. Each node can contain child nodes and has properties for:

- **Direction**: Horizontal or vertical layout direction
- **Margins**: External spacing around the node
- **Padding**: Internal spacing within the node
- **Size**: How the node should be sized relative to its parent

### Size Specifications

The layout system supports three types of size specifications:

1. **Fixed Size**: Absolute size in characters
2. **Percentage Size**: Relative size as a percentage of available space
3. **Auto Size**: Automatically calculated based on content and constraints

### Rectangle System

The layout system uses a coordinate system where:
- Origin (0,0) is at the top-left
- Positive X extends to the right
- Positive Y extends downward
- All measurements are in character cells

## Basic Usage

### Creating Layouts

```nim
import libterminal

# Create a buffer for rendering
var buffer = newBuffer(80, 24)
var layout = newLayout(buffer)

# Create a horizontal layout
let mainLayout = newLayoutNode("main", LayoutHorizontal)
mainLayout.margin = margin(2)       # 2-character margin on all sides
mainLayout.padding = padding(1)     # 1-character padding on all sides

# Create child panels
let leftPanel = newLayoutNode("left", LayoutVertical)
let rightPanel = newLayoutNode("right", LayoutVertical)

# Add children with size specifications
mainLayout.addChild(leftPanel, percent(30.0))   # 30% width
mainLayout.addChild(rightPanel, percent(70.0))  # 70% width

# Set as root and calculate layout
layout.setRootNode(mainLayout)
layout.calculateLayout()
```

### Size Specifications

```nim
# Fixed size: exactly 20 characters
node.addChild(child, fixed(20))

# Percentage size: 50% of available space
node.addChild(child, percent(50.0))

# Auto size: calculated automatically, minimum 10 characters
node.addChild(child, auto(10))
```

### Nested Layouts

```nim
# Create a main vertical layout
let mainLayout = newLayoutNode("main", LayoutVertical)

# Create a horizontal sublayout for the top section
let topSection = newLayoutNode("top", LayoutHorizontal)
let bottomSection = newLayoutNode("bottom", LayoutVertical)

# Add subsections to the horizontal layout
topSection.addChild(newLayoutNode("top-left", LayoutVertical), percent(50.0))
topSection.addChild(newLayoutNode("top-right", LayoutVertical), percent(50.0))

# Add sections to main layout
mainLayout.addChild(topSection, percent(60.0))
mainLayout.addChild(bottomSection, percent(40.0))
```

## Grid Layouts

For regular grid-based layouts, use the `GridLayout` type:

```nim
# Create a 3x3 grid with 1-character padding between cells
let grid = newGridLayout(3, 3, 1)

# Fill the grid with nodes
for row in 0..<3:
  for col in 0..<3:
    let node = newLayoutNode("cell-" & $row & "-" & $col, LayoutVertical)
    grid.setCell(row, col, node)

# Calculate grid layout
let gridRect = Rect(x: 10, y: 5, width: 60, height: 15)
grid.calculateGridLayout(gridRect)

# Access cells
let cell = grid.getCell(1, 2)  # Get cell at row 1, column 2
```

## Margin and Padding

Fine-tune spacing using margin and padding:

```nim
# Set margins (external spacing)
node.margin = margin(2, 4, 2, 4)  # top, right, bottom, left
node.margin = margin(2, 4)        # vertical, horizontal
node.margin = margin(2)           # all sides

# Set padding (internal spacing)
node.padding = padding(1, 2, 1, 2)  # top, right, bottom, left
node.padding = padding(1, 2)        # vertical, horizontal
node.padding = padding(1)           # all sides
```

## Rectangle Operations

The layout system provides comprehensive rectangle operations:

```nim
let rect1 = Rect(x: 10, y: 10, width: 20, height: 15)
let rect2 = Rect(x: 15, y: 12, width: 25, height: 10)

# Check intersection
if rect1.intersects(rect2):
  let overlap = rect1.intersection(rect2)
  echo "Overlap: ", overlap

# Check point containment
if rect1.contains(15, 15):
  echo "Point is inside rectangle"

# Get content rectangle (excluding margin/padding)
let contentArea = node.contentRect()
```

## Layout Debugging

The layout system includes debugging capabilities:

```nim
# Draw layout boundaries for debugging
layout.drawLayoutDebug()

# Print layout information
proc printNodeInfo(node: LayoutNode, level: int = 0) =
  let indent = "  ".repeat(level)
  echo indent, "Node: ", node.id
  echo indent, "  Rect: ", node.rect
  echo indent, "  Content: ", node.contentRect()
  
  for child in node.children:
    printNodeInfo(child.node, level + 1)

printNodeInfo(layout.root)
```

## Performance Considerations

- Layout calculation is performed once when `calculateLayout()` is called
- Only recalculate when the terminal size changes or layout structure changes
- Use `findNode(id)` to efficiently locate nodes in the hierarchy
- Grid layouts are optimized for regular cell patterns

## Examples

See the following example files:
- `examples/layout_test_simple.nim` - Basic layout calculation demonstration
- `examples/layout_demo.nim` - Interactive layout demonstration (when terminal issues are resolved)

## Integration with Rendering

The layout system is designed to work seamlessly with the terminal rendering system:

```nim
# After calculating layout, use node rectangles for drawing
let rect = node.contentRect()
buffer.print(rect.x, rect.y, "Content", style)

# For multi-line content with wrapping
buffer.printMultiLine(rect.x, rect.y, text, style, rect.width, WrapWord)
```

The layout system provides the foundation for building complex terminal UIs with proper spacing, alignment, and responsive behavior.