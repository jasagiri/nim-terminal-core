# layout.nim
## Layout management system for terminal UI components
##
## This module provides a flexible layout system that supports
## horizontal and vertical splits, grid layouts, and margins/padding.

import std/tables
import std/sequtils
import std/options
import std/unicode
import output

export output.Buffer

type
  LayoutDirection* = enum
    ## Direction for splitting layouts
    LayoutHorizontal,  ## Split horizontally (left-right)
    LayoutVertical     ## Split vertically (top-bottom)

  SizeUnit* = enum
    ## Different ways to specify sizes
    SizeFixed,      ## Fixed size in characters
    SizePercent,    ## Percentage of available space
    SizeAuto        ## Automatically calculated based on content

  Size* = object
    ## Represents a size specification
    case unit*: SizeUnit
    of SizeFixed:
      value*: int
    of SizePercent:
      percent*: float
    of SizeAuto:
      minSize*: int  ## Minimum size when auto-calculating

  Margin* = object
    ## Margin specification for all sides
    top*, right*, bottom*, left*: int

  Padding* = object
    ## Padding specification for all sides
    top*, right*, bottom*, left*: int

  Rect* = object
    ## Rectangle representing a screen area
    x*, y*: int
    width*, height*: int

  LayoutNode* = ref object
    ## A node in the layout tree
    id*: string
    rect*: Rect
    margin*: Margin
    padding*: Padding
    visible*: bool
    
    case kind*: LayoutDirection
    of LayoutHorizontal, LayoutVertical:
      children*: seq[LayoutChild]
    
  LayoutChild* = object
    ## A child element in a layout
    node*: LayoutNode
    size*: Size

  GridLayout* = ref object
    ## Grid-based layout
    rows*, cols*: int
    cellPadding*: int
    rect*: Rect
    cells*: seq[seq[LayoutNode]]

  Layout* = object
    ## Main layout container
    root*: LayoutNode
    buffer*: Buffer

# Helper functions for Size creation
proc fixed*(value: int): Size =
  ## Create a fixed size
  Size(unit: SizeFixed, value: value)

proc percent*(value: float): Size =
  ## Create a percentage size
  Size(unit: SizePercent, percent: value)

proc auto*(minSize: int = 0): Size =
  ## Create an auto size
  Size(unit: SizeAuto, minSize: minSize)

# Helper functions for Margin and Padding
proc margin*(all: int): Margin =
  ## Create margin with same value for all sides
  Margin(top: all, right: all, bottom: all, left: all)

proc margin*(vertical, horizontal: int): Margin =
  ## Create margin with vertical and horizontal values
  Margin(top: vertical, right: horizontal, bottom: vertical, left: horizontal)

proc margin*(top, right, bottom, left: int): Margin =
  ## Create margin with individual values for each side
  Margin(top: top, right: right, bottom: bottom, left: left)

proc padding*(all: int): Padding =
  ## Create padding with same value for all sides
  Padding(top: all, right: all, bottom: all, left: all)

proc padding*(vertical, horizontal: int): Padding =
  ## Create padding with vertical and horizontal values
  Padding(top: vertical, right: horizontal, bottom: vertical, left: horizontal)

proc padding*(top, right, bottom, left: int): Padding =
  ## Create padding with individual values for each side
  Padding(top: top, right: right, bottom: bottom, left: left)

# Rect operations
proc `$`*(rect: Rect): string =
  ## String representation of a rectangle
  result = "Rect(x: " & $rect.x & ", y: " & $rect.y & 
           ", width: " & $rect.width & ", height: " & $rect.height & ")"

proc contains*(rect: Rect, x, y: int): bool =
  ## Check if a point is inside the rectangle
  x >= rect.x and x < rect.x + rect.width and
  y >= rect.y and y < rect.y + rect.height

proc intersects*(a, b: Rect): bool =
  ## Check if two rectangles intersect
  not (a.x + a.width <= b.x or b.x + b.width <= a.x or
       a.y + a.height <= b.y or b.y + b.height <= a.y)

proc intersection*(a, b: Rect): Rect =
  ## Calculate the intersection of two rectangles
  let x1 = max(a.x, b.x)
  let y1 = max(a.y, b.y)
  let x2 = min(a.x + a.width, b.x + b.width)
  let y2 = min(a.y + a.height, b.y + b.height)
  
  if x2 > x1 and y2 > y1:
    result = Rect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
  else:
    result = Rect(x: 0, y: 0, width: 0, height: 0)  # No intersection

# Layout node functions
proc newLayoutNode*(id: string, direction: LayoutDirection): LayoutNode =
  ## Create a new layout node
  result = LayoutNode(kind: direction)
  result.id = id
  result.rect = Rect(x: 0, y: 0, width: 0, height: 0)
  result.margin = margin(0)
  result.padding = padding(0)
  result.visible = true
  result.children = @[]

proc contentRect*(node: LayoutNode): Rect =
  ## Get the content rectangle (excluding margin and padding)
  let outerRect = node.rect
  let m = node.margin
  let p = node.padding
  
  result = Rect(
    x: outerRect.x + m.left + p.left,
    y: outerRect.y + m.top + p.top,
    width: max(0, outerRect.width - m.left - m.right - p.left - p.right),
    height: max(0, outerRect.height - m.top - m.bottom - p.top - p.bottom)
  )

proc addChild*(parent: LayoutNode, child: LayoutNode, size: Size) =
  ## Add a child to a layout node
  parent.children.add(LayoutChild(node: child, size: size))

proc calculateLayout*(node: LayoutNode, availableRect: Rect) =
  ## Calculate layout positions and sizes for all children
  node.rect = availableRect
  
  if not node.visible or node.children.len == 0:
    return
  
  let contentArea = node.contentRect()
  var remainingSpace = contentArea
  var fixedSpace = 0
  var percentSum = 0.0
  var autoCount = 0
  
  # First pass: calculate fixed sizes and count others
  for child in node.children:
    case child.size.unit
    of SizeFixed:
      fixedSpace += child.size.value
    of SizePercent:
      percentSum += child.size.percent
    of SizeAuto:
      autoCount += 1
  
  # Calculate available space for percentage and auto sizes
  let totalFixedSize = if node.kind == LayoutHorizontal: contentArea.width else: contentArea.height
  let availableForPercent = max(0, totalFixedSize - fixedSpace)
  let percentSpace = int(availableForPercent.float * percentSum / 100.0)
  let autoSpace = if autoCount > 0: max(0, (availableForPercent - percentSpace) div autoCount) else: 0
  
  # Second pass: assign actual sizes and positions
  var currentPos = if node.kind == LayoutHorizontal: contentArea.x else: contentArea.y
  
  for child in node.children:
    var childSize = 0
    case child.size.unit
    of SizeFixed:
      childSize = child.size.value
    of SizePercent:
      childSize = int(availableForPercent.float * child.size.percent / 100.0)
    of SizeAuto:
      childSize = max(child.size.minSize, autoSpace)
    
    # Set child rectangle
    if node.kind == LayoutHorizontal:
      child.node.rect = Rect(
        x: currentPos,
        y: contentArea.y,
        width: childSize,
        height: contentArea.height
      )
      currentPos += childSize
    else: # LayoutVertical
      child.node.rect = Rect(
        x: contentArea.x,
        y: currentPos,
        width: contentArea.width,
        height: childSize
      )
      currentPos += childSize
    
    # Recursively calculate layout for child
    calculateLayout(child.node, child.node.rect)

# Grid layout functions
proc newGridLayout*(rows, cols: int, cellPadding: int = 0): GridLayout =
  ## Create a new grid layout
  result = GridLayout(
    rows: rows,
    cols: cols,
    cellPadding: cellPadding,
    rect: Rect(x: 0, y: 0, width: 0, height: 0),
    cells: newSeq[seq[LayoutNode]](rows)
  )
  
  for i in 0..<rows:
    result.cells[i] = newSeq[LayoutNode](cols)

proc setCell*(grid: GridLayout, row, col: int, node: LayoutNode) =
  ## Set a node in a specific grid cell
  if row >= 0 and row < grid.rows and col >= 0 and col < grid.cols:
    grid.cells[row][col] = node

proc getCell*(grid: GridLayout, row, col: int): LayoutNode =
  ## Get a node from a specific grid cell
  if row >= 0 and row < grid.rows and col >= 0 and col < grid.cols:
    return grid.cells[row][col]
  return nil

proc calculateGridLayout*(grid: GridLayout, availableRect: Rect) =
  ## Calculate layout for grid cells
  grid.rect = availableRect
  
  let cellWidth = (availableRect.width - (grid.cols - 1) * grid.cellPadding) div grid.cols
  let cellHeight = (availableRect.height - (grid.rows - 1) * grid.cellPadding) div grid.rows
  
  for row in 0..<grid.rows:
    for col in 0..<grid.cols:
      let node = grid.cells[row][col]
      if node != nil:
        let cellRect = Rect(
          x: availableRect.x + col * (cellWidth + grid.cellPadding),
          y: availableRect.y + row * (cellHeight + grid.cellPadding),
          width: cellWidth,
          height: cellHeight
        )
        calculateLayout(node, cellRect)

# Main layout functions
proc newLayout*(buffer: Buffer): Layout =
  ## Create a new layout with the given buffer
  let root = newLayoutNode("root", LayoutVertical)
  result = Layout(root: root, buffer: buffer)

proc setRootNode*(layout: var Layout, node: LayoutNode) =
  ## Set the root node of the layout
  layout.root = node

proc calculateLayout*(layout: var Layout) =
  ## Calculate the entire layout
  let bufferRect = Rect(x: 0, y: 0, width: layout.buffer.width, height: layout.buffer.height)
  calculateLayout(layout.root, bufferRect)

proc findNode*(node: LayoutNode, id: string): LayoutNode =
  ## Find a node by ID in the layout tree
  if node.id == id:
    return node
  
  for child in node.children:
    let found = findNode(child.node, id)
    if found != nil:
      return found
  
  return nil

proc findNode*(layout: Layout, id: string): LayoutNode =
  ## Find a node by ID in the layout
  return findNode(layout.root, id)

# Drawing functions
proc drawLayoutDebug*(layout: Layout) =
  ## Draw layout boundaries for debugging
  proc drawNodeDebug(node: LayoutNode, buffer: var Buffer, level: int = 0) =
    if not node.visible:
      return
    
    let rect = node.rect
    let contentArea = node.contentRect()
    
    # Draw border for the node
    let borderStyle = output.Style(fg: ColorRed, bg: ColorBlack, attrs: {})
    
    # Top and bottom borders
    for x in rect.x..<(rect.x + rect.width):
      if rect.y >= 0 and rect.y < buffer.height:
        buffer[x, rect.y] = Cell(ch: Rune('-'), style: borderStyle, width: 1)
      if rect.y + rect.height - 1 >= 0 and rect.y + rect.height - 1 < buffer.height:
        buffer[x, rect.y + rect.height - 1] = Cell(ch: Rune('-'), style: borderStyle, width: 1)
    
    # Left and right borders
    for y in rect.y..<(rect.y + rect.height):
      if rect.x >= 0 and rect.x < buffer.width:
        buffer[rect.x, y] = Cell(ch: Rune('|'), style: borderStyle, width: 1)
      if rect.x + rect.width - 1 >= 0 and rect.x + rect.width - 1 < buffer.width:
        buffer[rect.x + rect.width - 1, y] = Cell(ch: Rune('|'), style: borderStyle, width: 1)
    
    # Draw corners
    if rect.x >= 0 and rect.x < buffer.width and rect.y >= 0 and rect.y < buffer.height:
      buffer[rect.x, rect.y] = Cell(ch: Rune('+'), style: borderStyle, width: 1)
    if rect.x + rect.width - 1 >= 0 and rect.x + rect.width - 1 < buffer.width and rect.y >= 0 and rect.y < buffer.height:
      buffer[rect.x + rect.width - 1, rect.y] = Cell(ch: Rune('+'), style: borderStyle, width: 1)
    if rect.x >= 0 and rect.x < buffer.width and rect.y + rect.height - 1 >= 0 and rect.y + rect.height - 1 < buffer.height:
      buffer[rect.x, rect.y + rect.height - 1] = Cell(ch: Rune('+'), style: borderStyle, width: 1)
    if rect.x + rect.width - 1 >= 0 and rect.x + rect.width - 1 < buffer.width and rect.y + rect.height - 1 >= 0 and rect.y + rect.height - 1 < buffer.height:
      buffer[rect.x + rect.width - 1, rect.y + rect.height - 1] = Cell(ch: Rune('+'), style: borderStyle, width: 1)
    
    # Draw node ID
    if contentArea.width > node.id.len and contentArea.height > 0:
      buffer.print(contentArea.x, contentArea.y, node.id, output.Style(fg: ColorGreen, bg: ColorBlack, attrs: {}))
    
    # Draw children
    for child in node.children:
      drawNodeDebug(child.node, buffer, level + 1)
  
  var buffer = layout.buffer
  drawNodeDebug(layout.root, buffer)