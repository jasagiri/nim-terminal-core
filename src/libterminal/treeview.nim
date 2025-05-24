import widgets, output, input, unicode, sequtils, private/common

type
  TreeNodeState* = enum
    Expanded,
    Collapsed
  
  TreeNode* = ref object
    id*: string
    text*: string
    parent*: TreeNode
    children*: seq[TreeNode]
    isExpanded*: bool
    data*: pointer
    isSelectable*: bool
  
  TreeViewState* = ref object of WidgetState
    rootNode*: TreeNode
    selectedNode*: TreeNode
    showRootNode*: bool
    indentSize*: int
    highlightSelectedNodeParents*: bool
    expandedNodeIcon*: string
    collapsedNodeIcon*: string
    leafNodeIcon*: string
    onNodeSelected*: proc(node: TreeNode) {.closure.}
    onNodeExpanded*: proc(node: TreeNode) {.closure.}
    onNodeCollapsed*: proc(node: TreeNode) {.closure.}
    onNodeActivated*: proc(node: TreeNode) {.closure.}
    scrollOffset*: int  # Vertical scroll offset

proc newTreeNode*(id, text: string, data: pointer = nil): TreeNode =
  result = TreeNode()
  result.id = id
  result.text = text
  result.parent = nil
  result.children = @[]
  result.isExpanded = false
  result.data = data
  result.isSelectable = true

proc addChild*(parent: TreeNode, child: TreeNode) =
  child.parent = parent
  parent.children.add(child)

proc findNode*(node: TreeNode, id: string): TreeNode =
  if node.id == id:
    return node
  
  for child in node.children:
    let found = findNode(child, id)
    if found != nil:
      return found
  
  return nil

proc expand*(node: TreeNode) =
  node.isExpanded = true

proc collapse*(node: TreeNode) =
  node.isExpanded = false

proc toggle*(node: TreeNode) =
  node.isExpanded = not node.isExpanded

proc isLeaf*(node: TreeNode): bool =
  return node.children.len == 0

proc newTreeViewState*(): TreeViewState =
  result = TreeViewState()
  result.rootNode = nil
  result.selectedNode = nil
  result.showRootNode = true
  result.indentSize = 2
  result.highlightSelectedNodeParents = true
  result.expandedNodeIcon = "▼ "
  result.collapsedNodeIcon = "▶ "
  result.leafNodeIcon = "• "
  result.onNodeSelected = nil
  result.onNodeExpanded = nil
  result.onNodeCollapsed = nil
  result.onNodeActivated = nil
  result.scrollOffset = 0

proc newTreeView*(id: string): Widget =
  result = newWidget(id, 0, 0, 50, 25)
  result.state = newTreeViewState()
  
  # Default style
  result.style.fg = ColorDefault
  result.style.bg = ColorDefault
  result.style.focusFg = ColorYellow
  result.style.focusBg = ColorBlue
  result.style.selectedFg = ColorBlack
  result.style.selectedBg = ColorCyan
  
  result.flags.incl(WidgetFocusable)
  result.flags.incl(WidgetVisible)

proc getTreeViewState*(widget: Widget): TreeViewState =
  return TreeViewState(widget.state)

proc setRootNode*(treeView: Widget, rootNode: TreeNode) =
  let state = treeView.getTreeViewState()
  state.rootNode = rootNode
  treeView.markDirty()

proc setShowRootNode*(treeView: Widget, show: bool) =
  let state = treeView.getTreeViewState()
  state.showRootNode = show
  treeView.markDirty()

proc setIndentSize*(treeView: Widget, indentSize: int) =
  let state = treeView.getTreeViewState()
  state.indentSize = max(1, indentSize)
  treeView.markDirty()

proc setHighlightSelectedNodeParents*(treeView: Widget, highlight: bool) =
  let state = treeView.getTreeViewState()
  state.highlightSelectedNodeParents = highlight
  treeView.markDirty()

proc setNodeIcons*(treeView: Widget, expanded, collapsed, leaf: string) =
  let state = treeView.getTreeViewState()
  state.expandedNodeIcon = expanded
  state.collapsedNodeIcon = collapsed
  state.leafNodeIcon = leaf
  treeView.markDirty()

proc setOnNodeSelected*(treeView: Widget, handler: proc(node: TreeNode) {.closure.}) =
  let state = treeView.getTreeViewState()
  state.onNodeSelected = handler

proc setOnNodeExpanded*(treeView: Widget, handler: proc(node: TreeNode) {.closure.}) =
  let state = treeView.getTreeViewState()
  state.onNodeExpanded = handler

proc setOnNodeCollapsed*(treeView: Widget, handler: proc(node: TreeNode) {.closure.}) =
  let state = treeView.getTreeViewState()
  state.onNodeCollapsed = handler

proc setOnNodeActivated*(treeView: Widget, handler: proc(node: TreeNode) {.closure.}) =
  let state = treeView.getTreeViewState()
  state.onNodeActivated = handler

proc selectNode*(treeView: Widget, node: TreeNode) =
  let state = treeView.getTreeViewState()
  
  if node != nil and not node.isSelectable:
    return
  
  if state.selectedNode != node:
    state.selectedNode = node
    if node != nil and state.onNodeSelected != nil:
      state.onNodeSelected(node)
    treeView.markDirty()

proc selectNodeById*(treeView: Widget, id: string) =
  let state = treeView.getTreeViewState()
  if state.rootNode == nil:
    return
  
  let node = findNode(state.rootNode, id)
  if node != nil:
    treeView.selectNode(node)

proc expandNode*(treeView: Widget, node: TreeNode) =
  if node == nil or node.isLeaf or node.isExpanded:
    return
  
  node.expand()
  
  let state = treeView.getTreeViewState()
  if state.onNodeExpanded != nil:
    state.onNodeExpanded(node)
  
  treeView.markDirty()

proc collapseNode*(treeView: Widget, node: TreeNode) =
  if node == nil or node.isLeaf or not node.isExpanded:
    return
  
  node.collapse()
  
  let state = treeView.getTreeViewState()
  if state.onNodeCollapsed != nil:
    state.onNodeCollapsed(node)
  
  treeView.markDirty()

proc toggleNode*(treeView: Widget, node: TreeNode) =
  if node == nil or node.isLeaf:
    return
  
  let oldState = node.isExpanded
  node.toggle()
  
  let state = treeView.getTreeViewState()
  if node.isExpanded != oldState:
    if node.isExpanded:
      if state.onNodeExpanded != nil:
        state.onNodeExpanded(node)
    else:
      if state.onNodeCollapsed != nil:
        state.onNodeCollapsed(node)
  
  treeView.markDirty()

proc activateNode*(treeView: Widget, node: TreeNode) =
  if node == nil or not node.isSelectable:
    return
  
  let state = treeView.getTreeViewState()
  if state.onNodeActivated != nil:
    state.onNodeActivated(node)

# Node counter for traversal
proc countVisibleNodes(node: TreeNode, showRootNode: bool = true): int =
  if node == nil:
    return 0
  
  # Root node is counted separately
  result = if showRootNode: 1 else: 0
  
  # Count visible children
  if showRootNode == false or node.isExpanded:
    for child in node.children:
      result += countVisibleNodes(child, true)

# Build a flattened list of all visible nodes for rendering and navigation
proc flattenVisibleNodes(node: TreeNode, 
                        showRootNode: bool, 
                        result: var seq[tuple[node: TreeNode, level: int]], 
                        level: int = 0) =
  if node == nil:
    return
  
  if showRootNode:
    result.add((node, level))
  
  if showRootNode == false or node.isExpanded:
    for child in node.children:
      flattenVisibleNodes(child, true, result, level + 1)

proc findNodeIndex(treeView: Widget, node: TreeNode): int =
  if node == nil:
    return -1
  
  let state = treeView.getTreeViewState()
  var visibleNodes: seq[tuple[node: TreeNode, level: int]] = @[]
  flattenVisibleNodes(state.rootNode, state.showRootNode, visibleNodes)
  
  for i, item in visibleNodes:
    if item.node == node:
      return i
  
  return -1

proc renderTreeView*(widget: Widget) =
  let state = widget.getTreeViewState()
  let rect = widget.rect
  
  # Skip if there's no root node
  if state.rootNode == nil or rect.width <= 0 or rect.height <= 0:
    return
  
  # Clear the area
  var bgStyle = Style(fg: widget.style.fg, bg: widget.style.bg)
  setStyle(bgStyle)
  
  for y in 0..<rect.height:
    setCursor(rect.x, rect.y + y)
    for x in 0..<rect.width:
      stdout.write(" ")
  
  # Build a flattened list of visible nodes
  var visibleNodes: seq[tuple[node: TreeNode, level: int]] = @[]
  flattenVisibleNodes(state.rootNode, state.showRootNode, visibleNodes)
  
  # Render visible nodes within the viewport
  let startIdx = state.scrollOffset
  let endIdx = min(startIdx + rect.height, visibleNodes.len)
  
  for i in startIdx..<endIdx:
    let item = visibleNodes[i]
    let node = item.node
    let level = item.level
    let y = rect.y + (i - startIdx)
    let indent = level * state.indentSize
    
    # Skip if outside the visible area
    if y < rect.y or y >= rect.y + rect.height:
      continue
    
    # Determine node icon
    let icon = if node.isLeaf: 
                 state.leafNodeIcon
               elif node.isExpanded: 
                 state.expandedNodeIcon
               else: 
                 state.collapsedNodeIcon
    
    # Determine if node is in selection path
    var isSelected = node == state.selectedNode
    var isInSelectionPath = false
    
    if state.highlightSelectedNodeParents and state.selectedNode != nil:
      var parent = state.selectedNode.parent
      while parent != nil:
        if parent == node:
          isInSelectionPath = true
          break
        parent = parent.parent
    
    # Set style based on selection state
    var style: Style
    if isSelected:
      style = Style(fg: widget.style.selectedFg, bg: widget.style.selectedBg)
    elif isInSelectionPath:
      style = Style(fg: widget.style.focusFg, bg: widget.style.bg)
    elif widget.hasFlag(WidgetFocused) and i == findNodeIndex(widget, state.selectedNode):
      style = Style(fg: widget.style.focusFg, bg: widget.style.focusBg)
    else:
      style = Style(fg: widget.style.fg, bg: widget.style.bg)
    
    setStyle(style)
    
    # Draw the node
    setCursor(rect.x + indent, y)
    var displayText = icon & node.text
    
    # Handle width constraints
    let availableWidth = rect.width - indent
    if displayText.runeLen() > availableWidth:
      displayText = displayText.runeSubStr(0, availableWidth - 1) & "…"
    
    stdout.write(displayText)
    
    # Fill the rest of the line
    let remainingWidth = availableWidth - displayText.runeLen()
    for j in 0..<remainingWidth:
      stdout.write(" ")

# Navigate to the next node (visually downward)
proc selectNextNode(treeView: Widget) =
  let state = treeView.getTreeViewState()
  
  # Get flattened list of visible nodes
  var visibleNodes: seq[tuple[node: TreeNode, level: int]] = @[]
  flattenVisibleNodes(state.rootNode, state.showRootNode, visibleNodes)
  
  if visibleNodes.len == 0:
    return
  
  # Find the index of the currently selected node
  var currentIdx = -1
  for i, item in visibleNodes:
    if item.node == state.selectedNode:
      currentIdx = i
      break
  
  # Select the next node if possible
  var nextIdx = if currentIdx == -1: 0 else: currentIdx + 1
  while nextIdx < visibleNodes.len:
    if visibleNodes[nextIdx].node.isSelectable:
      treeView.selectNode(visibleNodes[nextIdx].node)
      
      # Adjust scroll if needed
      let rect = treeView.rect
      if nextIdx >= state.scrollOffset + rect.height:
        state.scrollOffset = nextIdx - rect.height + 1
      elif nextIdx < state.scrollOffset:
        state.scrollOffset = nextIdx
      
      return
    nextIdx += 1

# Navigate to the previous node (visually upward)
proc selectPreviousNode(treeView: Widget) =
  let state = treeView.getTreeViewState()
  
  # Get flattened list of visible nodes
  var visibleNodes: seq[tuple[node: TreeNode, level: int]] = @[]
  flattenVisibleNodes(state.rootNode, state.showRootNode, visibleNodes)
  
  if visibleNodes.len == 0:
    return
  
  # Find the index of the currently selected node
  var currentIdx = -1
  for i, item in visibleNodes:
    if item.node == state.selectedNode:
      currentIdx = i
      break
  
  # Select the previous node if possible
  var prevIdx = if currentIdx == -1: 0 else: currentIdx - 1
  while prevIdx >= 0:
    if visibleNodes[prevIdx].node.isSelectable:
      treeView.selectNode(visibleNodes[prevIdx].node)
      
      # Adjust scroll if needed
      let rect = treeView.rect
      if prevIdx >= state.scrollOffset + rect.height:
        state.scrollOffset = prevIdx - rect.height + 1
      elif prevIdx < state.scrollOffset:
        state.scrollOffset = prevIdx
      
      return
    prevIdx -= 1

proc handleTreeViewKeyEvent*(widget: Widget, event: KeyEvent): bool =
  let state = widget.getTreeViewState()
  
  if state.rootNode == nil:
    return false
  
  case event.key
  of KeyUp:
    widget.selectPreviousNode()
    return true
  of KeyDown:
    widget.selectNextNode()
    return true
  of KeyRight:
    if state.selectedNode != nil and not state.selectedNode.isLeaf:
      widget.expandNode(state.selectedNode)
    return true
  of KeyLeft:
    if state.selectedNode != nil:
      if state.selectedNode.isExpanded:
        widget.collapseNode(state.selectedNode)
      elif state.selectedNode.parent != nil:
        widget.selectNode(state.selectedNode.parent)
    return true
  of KeyEnter, KeySpace:
    if state.selectedNode != nil:
      if state.selectedNode.isLeaf:
        widget.activateNode(state.selectedNode)
      else:
        widget.toggleNode(state.selectedNode)
    return true
  of KeyHome:
    # Go to first node
    var visibleNodes: seq[tuple[node: TreeNode, level: int]] = @[]
    flattenVisibleNodes(state.rootNode, state.showRootNode, visibleNodes)
    if visibleNodes.len > 0:
      widget.selectNode(visibleNodes[0].node)
      state.scrollOffset = 0
    return true
  of KeyEnd:
    # Go to last node
    var visibleNodes: seq[tuple[node: TreeNode, level: int]] = @[]
    flattenVisibleNodes(state.rootNode, state.showRootNode, visibleNodes)
    if visibleNodes.len > 0:
      widget.selectNode(visibleNodes[^1].node)
      let rect = widget.rect
      if visibleNodes.len > rect.height:
        state.scrollOffset = visibleNodes.len - rect.height
    return true
  of KeyPageUp:
    # Move up a page
    let rect = widget.rect
    var visibleNodes: seq[tuple[node: TreeNode, level: int]] = @[]
    flattenVisibleNodes(state.rootNode, state.showRootNode, visibleNodes)
    
    var currentIdx = 0
    for i, item in visibleNodes:
      if item.node == state.selectedNode:
        currentIdx = i
        break
    
    let newIdx = max(0, currentIdx - rect.height)
    if newIdx < visibleNodes.len:
      widget.selectNode(visibleNodes[newIdx].node)
      state.scrollOffset = max(0, state.scrollOffset - rect.height)
    
    return true
  of KeyPageDown:
    # Move down a page
    let rect = widget.rect
    var visibleNodes: seq[tuple[node: TreeNode, level: int]] = @[]
    flattenVisibleNodes(state.rootNode, state.showRootNode, visibleNodes)
    
    var currentIdx = 0
    for i, item in visibleNodes:
      if item.node == state.selectedNode:
        currentIdx = i
        break
    
    let newIdx = min(visibleNodes.len - 1, currentIdx + rect.height)
    if newIdx < visibleNodes.len:
      widget.selectNode(visibleNodes[newIdx].node)
      state.scrollOffset = min(visibleNodes.len - rect.height, state.scrollOffset + rect.height)
      if state.scrollOffset < 0:
        state.scrollOffset = 0
    
    return true
  else:
    return false

proc nodeAtPosition(treeView: Widget, x, y: int): tuple[node: TreeNode, toggleArea: bool] =
  let state = treeView.getTreeViewState()
  let rect = treeView.rect
  
  if x < rect.x or x >= rect.x + rect.width or
     y < rect.y or y >= rect.y + rect.height:
    return (nil, false)
  
  # Get flattened list of visible nodes
  var visibleNodes: seq[tuple[node: TreeNode, level: int]] = @[]
  flattenVisibleNodes(state.rootNode, state.showRootNode, visibleNodes)
  
  let relY = y - rect.y
  let visibleIndex = relY + state.scrollOffset
  
  if visibleIndex < 0 or visibleIndex >= visibleNodes.len:
    return (nil, false)
  
  let item = visibleNodes[visibleIndex]
  let node = item.node
  let level = item.level
  let indent = level * state.indentSize
  
  # Determine if click is in toggle area (icon area)
  let toggleAreaWidth = if node.isLeaf: 
                          state.leafNodeIcon.len 
                        elif node.isExpanded: 
                          state.expandedNodeIcon.len
                        else: 
                          state.collapsedNodeIcon.len
  
  let inToggleArea = x >= rect.x + indent and x < rect.x + indent + toggleAreaWidth
  
  return (node, inToggleArea)

proc handleTreeViewMouseEvent*(widget: Widget, event: MouseEvent): bool =
  let state = widget.getTreeViewState()
  
  if state.rootNode == nil:
    return false
  
  # Handle scrolling
  if event.button == MouseWheelUp or event.button == MouseWheelDown:
    var visibleNodes: seq[tuple[node: TreeNode, level: int]] = @[]
    flattenVisibleNodes(state.rootNode, state.showRootNode, visibleNodes)
    
    if event.button == MouseWheelUp:
      if state.scrollOffset > 0:
        state.scrollOffset -= 1
        widget.markDirty()
    else:  # ScrollDirection.Down
      let maxScroll = max(0, visibleNodes.len - widget.rect.height)
      if state.scrollOffset < maxScroll:
        state.scrollOffset += 1
        widget.markDirty()
    return true
  
  # Handle clicks
  if event.action == MousePressed and event.button == MouseLeft:
    let (node, inToggleArea) = nodeAtPosition(widget, event.x, event.y)
    
    if node != nil:
      widget.selectNode(node)
      
      if inToggleArea and not node.isLeaf:
        # Toggle node expansion
        widget.toggleNode(node)
      else:
        # Single click activates the node or toggles expansion
        if node.isLeaf:
          widget.activateNode(node)
        else:
          widget.toggleNode(node)
      
      return true
  
  return false

# Register treeview widget handlers
proc registerTreeViewWidget*() =
  # registerWidgetRenderer("treeview", renderTreeView)
  # registerWidgetKeyHandler("treeview", handleTreeViewKeyEvent)
  # registerWidgetMouseHandler("treeview", handleTreeViewMouseEvent)
  discard

# Auto-register when module is imported
registerTreeViewWidget()