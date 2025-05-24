## Simple Layout Test
## 
## This example demonstrates the layout system without complex terminal control

import ../src/libterminal/layout
import ../src/libterminal/output

proc main() =
  # Create a buffer
  var buffer = newBuffer(80, 24)
  
  # Create layout
  var layout = newLayout(buffer)
  
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
  for row in 0..<3:
    for col in 0..<3:
      let node = grid.getCell(row, col)
      if node != nil:
        echo "Cell [", row, ",", col, "]: ", node.rect

when isMainModule:
  main()