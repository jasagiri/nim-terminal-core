## Simple Layout Test - without complex terminal rendering
## 
## This example demonstrates the layout system calculation only

import std/strutils
import ../src/libterminal/layout
import ../src/libterminal/output

proc main() =
  # Create a dummy buffer for layout calculation
  var buffer = newBuffer(80, 24)
  
  # Create layout
  var layout = newLayout(buffer)
  
  echo "Testing Layout System"
  echo "====================="
  
  # Create main horizontal layout
  let mainLayout = newLayoutNode("main", LayoutHorizontal)
  mainLayout.margin = margin(2)
  mainLayout.padding = padding(1)
  
  # Left panel (30% width)
  let leftPanel = newLayoutNode("left", LayoutVertical)
  leftPanel.margin = margin(0, 1, 0, 0)  # Right margin for spacing
  
  # Right panel (70% width)
  let rightPanel = newLayoutNode("right", LayoutVertical)
  
  # Add panels to main layout
  mainLayout.addChild(leftPanel, percent(30.0))
  mainLayout.addChild(rightPanel, percent(70.0))
  
  # Split right panel vertically
  let topRight = newLayoutNode("top-right", LayoutHorizontal)
  let bottomRight = newLayoutNode("bottom-right", LayoutHorizontal)
  topRight.margin = margin(0, 0, 1, 0)  # Bottom margin
  
  rightPanel.addChild(topRight, percent(60.0))
  rightPanel.addChild(bottomRight, percent(40.0))
  
  # Set the root layout
  layout.setRootNode(mainLayout)
  
  # Calculate layout
  layout.calculateLayout()
  
  # Print layout information
  proc printNodeInfo(node: LayoutNode, level: int = 0) =
    let indent = "  ".repeat(level)
    let rect = node.rect
    let contentRect = node.contentRect()
    
    echo indent, "Node: ", node.id
    echo indent, "  Rect: ", rect
    echo indent, "  Content: ", contentRect
    echo indent, "  Visible: ", node.visible
    echo indent, "  Margin: (", node.margin.top, ",", node.margin.right, ",", node.margin.bottom, ",", node.margin.left, ")"
    echo indent, "  Padding: (", node.padding.top, ",", node.padding.right, ",", node.padding.bottom, ",", node.padding.left, ")"
    
    for child in node.children:
      printNodeInfo(child.node, level + 1)
  
  echo "Layout Structure:"
  echo "=================="
  printNodeInfo(layout.root)
  
  echo "\nGrid Layout Test:"
  echo "=================="
  
  # Test grid layout
  let grid = newGridLayout(3, 3, 1)
  let gridRect = Rect(x: 10, y: 5, width: 60, height: 15)
  
  # Fill the grid
  for row in 0..<3:
    for col in 0..<3:
      let node = newLayoutNode("cell-" & $row & "-" & $col, LayoutVertical)
      node.padding = padding(1)
      grid.setCell(row, col, node)
  
  # Calculate grid layout
  grid.calculateGridLayout(gridRect)
  
  # Print grid information
  echo "Grid Rect: ", grid.rect
  echo "Rows: ", grid.rows, ", Cols: ", grid.cols, ", Cell Padding: ", grid.cellPadding
  
  for row in 0..<3:
    for col in 0..<3:
      let node = grid.getCell(row, col)
      if node != nil:
        echo "Cell [", row, ",", col, "]: ", node.rect, " Content: ", node.contentRect()
  
  # Test different size specifications
  echo "\nSize specification tests:"
  echo "========================"
  
  let testLayout = newLayoutNode("test", LayoutHorizontal)
  testLayout.rect = Rect(x: 0, y: 0, width: 100, height: 50)
  
  let fixedChild = newLayoutNode("fixed", LayoutVertical)
  let percentChild = newLayoutNode("percent", LayoutVertical)
  let autoChild = newLayoutNode("auto", LayoutVertical)
  
  testLayout.addChild(fixedChild, fixed(20))
  testLayout.addChild(percentChild, percent(50.0))
  testLayout.addChild(autoChild, auto(10))
  
  calculateLayout(testLayout, testLayout.rect)
  
  echo "Fixed size (20): ", fixedChild.rect
  echo "Percent size (50%): ", percentChild.rect
  echo "Auto size (min 10): ", autoChild.rect
  
  # Test rectangles operations
  echo "\nRectangle operations tests:"
  echo "=========================="
  
  let rect1 = Rect(x: 10, y: 10, width: 20, height: 15)
  let rect2 = Rect(x: 15, y: 12, width: 25, height: 10)
  
  echo "Rect1: ", rect1
  echo "Rect2: ", rect2
  echo "Intersects: ", rect1.intersects(rect2)
  echo "Intersection: ", rect1.intersection(rect2)
  echo "Point (15, 15) in rect1: ", rect1.contains(15, 15)
  echo "Point (5, 5) in rect1: ", rect1.contains(5, 5)

when isMainModule:
  main()