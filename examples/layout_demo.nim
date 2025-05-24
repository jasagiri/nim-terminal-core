## Layout System Demo
## 
## This example demonstrates the layout system capabilities

import ../src/libterminal
import ../src/libterminal/layout

proc main() =
  withTerminal:
    # Create buffer and layout
    var buffer = newBuffer(80, 24)
    var layout = newLayout(buffer)
    
    # Clear screen and hide cursor
    clearScreen()
    hideCursor()
    
    # Create main horizontal layout
    let mainLayout = newLayoutNode("main", LayoutHorizontal)
    mainLayout.margin = margin(1)
    mainLayout.padding = padding(1)
    
    # Left panel (30% width)
    let leftPanel = newLayoutNode("left", LayoutVertical)
    leftPanel.margin = margin(0, 1, 0, 0)  # Right margin for spacing
    
    # Right panel (70% width) - will be split vertically
    let rightPanel = newLayoutNode("right", LayoutVertical)
    
    # Add panels to main layout
    mainLayout.addChild(leftPanel, percent(30))
    mainLayout.addChild(rightPanel, percent(70))
    
    # Split right panel vertically
    let topRight = newLayoutNode("top-right", LayoutHorizontal)
    let bottomRight = newLayoutNode("bottom-right", LayoutHorizontal)
    topRight.margin = margin(0, 0, 1, 0)  # Bottom margin for spacing
    
    rightPanel.addChild(topRight, percent(60))
    rightPanel.addChild(bottomRight, percent(40))
    
    # Add some sub-panels to top-right
    let topLeft = newLayoutNode("top-left", LayoutVertical)
    let topMiddle = newLayoutNode("top-middle", LayoutVertical)
    let topRightSub = newLayoutNode("top-right-sub", LayoutVertical)
    
    topLeft.margin = margin(0, 1, 0, 0)
    topMiddle.margin = margin(0, 1, 0, 0)
    
    topRight.addChild(topLeft, percent(33))
    topRight.addChild(topMiddle, percent(33))
    topRight.addChild(topRightSub, percent(34))
    
    # Set the root layout
    layout.setRootNode(mainLayout)
    
    # Calculate layout
    layout.calculateLayout()
    
    # Draw some content in each panel
    proc drawPanelContent(node: LayoutNode, title: string, content: seq[string] = @[]) =
      let rect = node.contentRect()
      if rect.width > 0 and rect.height > 0:
        # Draw title
        buffer.print(rect.x, rect.y, title, Style(fg: fgYellow, bg: bgBlack, attrs: {attBold}))
        
        # Draw content
        for i, line in content:
          if i + 1 < rect.height:
            let truncated = if line.len > rect.width: line[0..<rect.width] else: line
            buffer.print(rect.x, rect.y + i + 1, truncated, Style(fg: fgWhite, bg: bgBlack, attrs: {}))
    
    # Add content to panels
    drawPanelContent(leftPanel, "Left Panel", @[
      "This is the left",
      "sidebar panel.",
      "It takes 30% of",
      "the width.",
      "",
      "You can put:",
      "- Navigation",
      "- Status info",
      "- Quick actions"
    ])
    
    drawPanelContent(topLeft, "Top-Left", @[
      "33% width",
      "60% height",
      "of right side"
    ])
    
    drawPanelContent(topMiddle, "Top-Middle", @[
      "33% width",
      "Central area"
    ])
    
    drawPanelContent(topRightSub, "Top-Right", @[
      "34% width",
      "Right corner"
    ])
    
    drawPanelContent(bottomRight, "Bottom Panel", @[
      "This bottom panel spans the full width",
      "of the right side (70% of total width)",
      "and takes 40% of the right side height."
    ])
    
    # Draw the layout structure for debugging
    layout.drawLayoutDebug()
    
    # Show instructions
    buffer.print(2, 0, "Layout Demo - Press any key to continue", 
                Style(fg: fgCyan, bg: bgBlack, attrs: {attBold}))
    
    # Draw buffer
    buffer.drawBuffer()
    
    # Wait for keypress
    discard readKey()
    
    # Demo 2: Grid Layout
    buffer.clear()
    
    # Create a 3x3 grid
    var grid = newGridLayout(3, 3, 1)  # 1 character padding between cells
    let gridRect = Rect(x: 5, y: 3, width: 60, height: 15)
    
    # Fill the grid with some demo nodes
    for row in 0..<3:
      for col in 0..<3:
        let node = newLayoutNode("cell-" & $row & "-" & $col, LayoutVertical)
        node.padding = padding(1)
        grid.setCell(row, col, node)
    
    # Calculate grid layout
    grid.calculateGridLayout(gridRect)
    
    # Draw grid content
    for row in 0..<3:
      for col in 0..<3:
        let node = grid.getCell(row, col)
        if node != nil:
          let rect = node.contentRect()
          if rect.width > 0 and rect.height > 0:
            buffer.print(rect.x, rect.y, "Cell " & $row & "," & $col, 
                        Style(fg: fgMagenta, bg: bgBlack, attrs: {attBold}))
            buffer.print(rect.x, rect.y + 1, "Size: " & $rect.width & "x" & $rect.height,
                        Style(fg: fgWhite, bg: bgBlack, attrs: {}))
    
    # Draw grid boundaries
    for row in 0..<3:
      for col in 0..<3:
        let node = grid.getCell(row, col)
        if node != nil:
          let rect = node.rect
          let borderStyle = Style(fg: fgBlue, bg: bgBlack, attrs: {})
          
          # Draw border
          for x in rect.x..<(rect.x + rect.width):
            if rect.y >= 0 and rect.y < buffer.height:
              buffer[x, rect.y] = Cell(ch: '-'.Rune, style: borderStyle, width: 1)
            if rect.y + rect.height - 1 >= 0 and rect.y + rect.height - 1 < buffer.height:
              buffer[x, rect.y + rect.height - 1] = Cell(ch: '-'.Rune, style: borderStyle, width: 1)
          
          for y in rect.y..<(rect.y + rect.height):
            if rect.x >= 0 and rect.x < buffer.width:
              buffer[rect.x, y] = Cell(ch: '|'.Rune, style: borderStyle, width: 1)
            if rect.x + rect.width - 1 >= 0 and rect.x + rect.width - 1 < buffer.width:
              buffer[rect.x + rect.width - 1, y] = Cell(ch: '|'.Rune, style: borderStyle, width: 1)
          
          # Corners
          if rect.x >= 0 and rect.x < buffer.width and rect.y >= 0 and rect.y < buffer.height:
            buffer[rect.x, rect.y] = Cell(ch: '+'.Rune, style: borderStyle, width: 1)
          if rect.x + rect.width - 1 >= 0 and rect.x + rect.width - 1 < buffer.width and rect.y >= 0 and rect.y < buffer.height:
            buffer[rect.x + rect.width - 1, rect.y] = Cell(ch: '+'.Rune, style: borderStyle, width: 1)
          if rect.x >= 0 and rect.x < buffer.width and rect.y + rect.height - 1 >= 0 and rect.y + rect.height - 1 < buffer.height:
            buffer[rect.x, rect.y + rect.height - 1] = Cell(ch: '+'.Rune, style: borderStyle, width: 1)
          if rect.x + rect.width - 1 >= 0 and rect.x + rect.width - 1 < buffer.width and rect.y + rect.height - 1 >= 0 and rect.y + rect.height - 1 < buffer.height:
            buffer[rect.x + rect.width - 1, rect.y + rect.height - 1] = Cell(ch: '+'.Rune, style: borderStyle, width: 1)
    
    buffer.print(2, 0, "Grid Layout Demo (3x3 Grid) - Press any key to exit", 
                Style(fg: fgCyan, bg: bgBlack, attrs: {attBold}))
    
    # Draw buffer
    buffer.drawBuffer()
    
    # Wait for keypress
    discard readKey()
    
    showCursor()
    clearScreen()

when isMainModule:
  main()