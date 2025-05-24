import widgets, output, input, unicode, sequtils, strutils, math, private/common

type
  ColumnAlign* = enum
    AlignLeft,
    AlignCenter,
    AlignRight
  
  SortDirection* = enum
    SortNone,
    SortAscending,
    SortDescending
  
  TableColumn* = object
    id*: string
    title*: string
    width*: int
    align*: ColumnAlign
    sortable*: bool
    sortDirection*: SortDirection
    widthMode*: WidthMode  # Fixed, Percentage, or Auto
  
  WidthMode* = enum
    WidthFixed,      # Fixed pixel width
    WidthPercentage, # Percentage of available space
    WidthAuto        # Auto-size based on content
  
  TableSelection* = enum
    SelectNone,      # No selection
    SelectRow,       # Select entire rows
    SelectCell       # Select individual cells
  
  TableCell* = object
    text*: string
    data*: pointer
  
  TableRow* = object
    cells*: seq[TableCell]
    isHeader*: bool
    isSelected*: bool
    isEnabled*: bool
    data*: pointer
  
  TableViewState* = ref object of WidgetState
    columns*: seq[TableColumn]
    rows*: seq[TableRow]
    selectedRow*: int
    selectedColumn*: int
    selectionMode*: TableSelection
    showHeader*: bool
    showGrid*: bool
    rowHeight*: int
    headerHeight*: int
    horScrollOffset*: int
    vertScrollOffset*: int
    onSelectionChanged*: proc(row, col: int) {.closure.}
    onHeaderClicked*: proc(column: int) {.closure.}
    onCellActivated*: proc(row, col: int) {.closure.}
    customCellRenderer*: proc(widget: Widget, row, col: int, rect: Rect, selected: bool) {.closure.}
    sortByColumn*: proc(column: int, direction: SortDirection) {.closure.}

proc newTableViewState*(): TableViewState =
  result = TableViewState()
  result.columns = @[]
  result.rows = @[]
  result.selectedRow = -1
  result.selectedColumn = -1
  result.selectionMode = SelectRow
  result.showHeader = true
  result.showGrid = true
  result.rowHeight = 1
  result.headerHeight = 1
  result.horScrollOffset = 0
  result.vertScrollOffset = 0
  result.onSelectionChanged = nil
  result.onHeaderClicked = nil
  result.onCellActivated = nil
  result.customCellRenderer = nil
  result.sortByColumn = nil

proc newTableView*(id: string): Widget =
  result = newWidget(id, 0, 0, 60, 20)
  result.state = newTableViewState()
  
  # Default style
  result.style.fg = ColorDefault
  result.style.bg = ColorDefault
  result.style.focusFg = ColorYellow
  result.style.focusBg = ColorBlue
  result.style.selectedFg = ColorBlack
  result.style.selectedBg = ColorCyan
  
  result.flags.incl(WidgetFocusable)
  result.flags.incl(WidgetVisible)

proc getTableViewState*(widget: Widget): TableViewState =
  return TableViewState(widget.state)

proc addColumn*(tableView: Widget, id, title: string, width: int = 10, 
               align: ColumnAlign = AlignLeft, sortable: bool = false,
               widthMode: WidthMode = WidthFixed) =
  let state = tableView.getTableViewState()
  
  let column = TableColumn(
    id: id,
    title: title,
    width: max(1, width),
    align: align,
    sortable: sortable,
    sortDirection: SortNone,
    widthMode: widthMode
  )
  
  state.columns.add(column)
  tableView.markDirty()

proc removeColumn*(tableView: Widget, columnIndex: int) =
  let state = tableView.getTableViewState()
  
  if columnIndex < 0 or columnIndex >= state.columns.len:
    return
  
  # Remove column
  state.columns.delete(columnIndex)
  
  # Remove corresponding cells from all rows
  for i in 0..<state.rows.len:
    if columnIndex < state.rows[i].cells.len:
      state.rows[i].cells.delete(columnIndex)
  
  # Update selected column if needed
  if state.selectedColumn >= state.columns.len:
    state.selectedColumn = max(0, state.columns.len - 1)
  
  tableView.markDirty()

proc clearColumns*(tableView: Widget) =
  let state = tableView.getTableViewState()
  state.columns = @[]
  state.rows = @[]  # Clear rows as well since they no longer match
  state.selectedRow = -1
  state.selectedColumn = -1
  tableView.markDirty()

proc addRow*(tableView: Widget, texts: seq[string], data: pointer = nil) =
  let state = tableView.getTableViewState()
  
  # Create cells for the row
  var cells: seq[TableCell] = @[]
  for i, text in texts:
    if i < state.columns.len:
      cells.add(TableCell(text: text, data: nil))
  
  # Fill any missing cells with empty text
  while cells.len < state.columns.len:
    cells.add(TableCell(text: "", data: nil))
  
  # Create and add row
  let row = TableRow(
    cells: cells,
    isHeader: false,
    isSelected: false,
    isEnabled: true,
    data: data
  )
  
  state.rows.add(row)
  tableView.markDirty()

proc removeRow*(tableView: Widget, rowIndex: int) =
  let state = tableView.getTableViewState()
  
  if rowIndex < 0 or rowIndex >= state.rows.len:
    return
  
  state.rows.delete(rowIndex)
  
  # Update selected row if needed
  if state.selectedRow >= state.rows.len:
    state.selectedRow = max(-1, state.rows.len - 1)
  
  tableView.markDirty()

proc clearRows*(tableView: Widget) =
  let state = tableView.getTableViewState()
  state.rows = @[]
  state.selectedRow = -1
  state.selectedColumn = -1
  state.vertScrollOffset = 0
  tableView.markDirty()

proc setCellText*(tableView: Widget, row, col: int, text: string) =
  let state = tableView.getTableViewState()
  
  if row < 0 or row >= state.rows.len or
     col < 0 or col >= state.columns.len:
    return
  
  # Ensure cell exists
  if col >= state.rows[row].cells.len:
    for i in state.rows[row].cells.len..<col+1:
      state.rows[row].cells.add(TableCell(text: "", data: nil))
  
  state.rows[row].cells[col].text = text
  tableView.markDirty()

proc getCellText*(tableView: Widget, row, col: int): string =
  let state = tableView.getTableViewState()
  
  if row < 0 or row >= state.rows.len or
     col < 0 or col >= state.columns.len or
     col >= state.rows[row].cells.len:
    return ""
  
  return state.rows[row].cells[col].text

proc setCellData*(tableView: Widget, row, col: int, data: pointer) =
  let state = tableView.getTableViewState()
  
  if row < 0 or row >= state.rows.len or
     col < 0 or col >= state.columns.len:
    return
  
  # Ensure cell exists
  if col >= state.rows[row].cells.len:
    for i in state.rows[row].cells.len..<col+1:
      state.rows[row].cells.add(TableCell(text: "", data: nil))
  
  state.rows[row].cells[col].data = data
  tableView.markDirty()

proc getCellData*(tableView: Widget, row, col: int): pointer =
  let state = tableView.getTableViewState()
  
  if row < 0 or row >= state.rows.len or
     col < 0 or col >= state.columns.len or
     col >= state.rows[row].cells.len:
    return nil
  
  return state.rows[row].cells[col].data

proc setRowData*(tableView: Widget, row: int, data: pointer) =
  let state = tableView.getTableViewState()
  
  if row < 0 or row >= state.rows.len:
    return
  
  state.rows[row].data = data
  tableView.markDirty()

proc getRowData*(tableView: Widget, row: int): pointer =
  let state = tableView.getTableViewState()
  
  if row < 0 or row >= state.rows.len:
    return nil
  
  return state.rows[row].data

proc setSelectionMode*(tableView: Widget, mode: TableSelection) =
  let state = tableView.getTableViewState()
  state.selectionMode = mode
  tableView.markDirty()

proc setShowHeader*(tableView: Widget, show: bool) =
  let state = tableView.getTableViewState()
  state.showHeader = show
  tableView.markDirty()

proc setShowGrid*(tableView: Widget, show: bool) =
  let state = tableView.getTableViewState()
  state.showGrid = show
  tableView.markDirty()

proc setRowHeight*(tableView: Widget, height: int) =
  let state = tableView.getTableViewState()
  state.rowHeight = max(1, height)
  tableView.markDirty()

proc setHeaderHeight*(tableView: Widget, height: int) =
  let state = tableView.getTableViewState()
  state.headerHeight = max(1, height)
  tableView.markDirty()

proc setOnSelectionChanged*(tableView: Widget, handler: proc(row, col: int) {.closure.}) =
  let state = tableView.getTableViewState()
  state.onSelectionChanged = handler

proc setOnHeaderClicked*(tableView: Widget, handler: proc(column: int) {.closure.}) =
  let state = tableView.getTableViewState()
  state.onHeaderClicked = handler

proc setOnCellActivated*(tableView: Widget, handler: proc(row, col: int) {.closure.}) =
  let state = tableView.getTableViewState()
  state.onCellActivated = handler

proc setCustomCellRenderer*(tableView: Widget, 
                           renderer: proc(widget: Widget, row, col: int, rect: Rect, selected: bool) {.closure.}) =
  let state = tableView.getTableViewState()
  state.customCellRenderer = renderer

proc setSortByColumn*(tableView: Widget, handler: proc(column: int, direction: SortDirection) {.closure.}) =
  let state = tableView.getTableViewState()
  state.sortByColumn = handler

proc selectCell*(tableView: Widget, row, col: int) =
  let state = tableView.getTableViewState()
  
  # Validate indices
  if row < -1 or row >= state.rows.len or
     col < -1 or col >= state.columns.len:
    return
  
  let oldRow = state.selectedRow
  let oldCol = state.selectedColumn
  
  # Update selection
  state.selectedRow = row
  state.selectedColumn = col
  
  # Update row selection state
  if oldRow != row:
    if oldRow >= 0 and oldRow < state.rows.len:
      state.rows[oldRow].isSelected = false
    
    if row >= 0 and row < state.rows.len:
      state.rows[row].isSelected = true
  
  # Adjust scroll position to ensure selected cell is visible
  if row >= 0 and col >= 0:
    let rect = tableView.rect
    let visibleRows = (rect.height - (if state.showHeader: state.headerHeight else: 0)) div state.rowHeight
    
    # Vertical scrolling
    if row < state.vertScrollOffset:
      state.vertScrollOffset = row
    elif row >= state.vertScrollOffset + visibleRows:
      state.vertScrollOffset = row - visibleRows + 1
    
    # Horizontal scrolling - need to calculate column positions
    var colStart = 0
    for i in 0..<col:
      colStart += state.columns[i].width
    
    let colEnd = colStart + state.columns[col].width
    
    if colStart < state.horScrollOffset:
      state.horScrollOffset = colStart
    elif colEnd > state.horScrollOffset + rect.width:
      state.horScrollOffset = colEnd - rect.width
    
    # Ensure non-negative values
    state.horScrollOffset = max(0, state.horScrollOffset)
    state.vertScrollOffset = max(0, state.vertScrollOffset)
  
  # Call selection changed callback
  if (oldRow != row or oldCol != col) and state.onSelectionChanged != nil:
    state.onSelectionChanged(row, col)
  
  tableView.markDirty()

proc getSelectedCell*(tableView: Widget): tuple[row, col: int] =
  let state = tableView.getTableViewState()
  return (state.selectedRow, state.selectedColumn)

proc getSelectedRow*(tableView: Widget): int =
  return tableView.getTableViewState().selectedRow

proc getSelectedColumn*(tableView: Widget): int =
  return tableView.getTableViewState().selectedColumn

proc getVisibleRowRange*(tableView: Widget): tuple[first, last: int] =
  let state = tableView.getTableViewState()
  let rect = tableView.rect
  
  let headerOffset = if state.showHeader: state.headerHeight else: 0
  let visibleRows = (rect.height - headerOffset) div state.rowHeight
  
  let first = state.vertScrollOffset
  let last = min(state.rows.len - 1, first + visibleRows - 1)
  
  return (first, last)

proc getVisibleColumnRange*(tableView: Widget): tuple[first, last: int] =
  let state = tableView.getTableViewState()
  let rect = tableView.rect
  
  var colStart = 0
  var first = 0
  var last = -1
  
  # Find first visible column
  for i in 0..<state.columns.len:
    if colStart >= state.horScrollOffset:
      first = i
      break
    colStart += state.columns[i].width
  
  # Find last visible column
  colStart = 0
  for i in 0..<state.columns.len:
    colStart += state.columns[i].width
    if colStart > state.horScrollOffset + rect.width:
      last = i - 1
      break
  
  if last == -1 and state.columns.len > 0:
    last = state.columns.len - 1
  
  return (first, last)

proc getColumnAt*(tableView: Widget, x: int): int =
  let state = tableView.getTableViewState()
  let rect = tableView.rect
  
  if x < rect.x or x >= rect.x + rect.width:
    return -1
  
  let relX = x - rect.x + state.horScrollOffset
  var colStart = 0
  
  for i in 0..<state.columns.len:
    let colWidth = state.columns[i].width
    if relX >= colStart and relX < colStart + colWidth:
      return i
    colStart += colWidth
  
  return -1

proc getRowAt*(tableView: Widget, y: int): int =
  let state = tableView.getTableViewState()
  let rect = tableView.rect
  
  if y < rect.y or y >= rect.y + rect.height:
    return -1
  
  let headerHeight = if state.showHeader: state.headerHeight else: 0
  
  # Check if in header area
  if state.showHeader and y < rect.y + headerHeight:
    return -1  # -1 indicates header
  
  let relY = y - rect.y - headerHeight
  let rowIndex = relY div state.rowHeight + state.vertScrollOffset
  
  if rowIndex < 0 or rowIndex >= state.rows.len:
    return -1
  
  return rowIndex

proc activateCell*(tableView: Widget, row, col: int) =
  let state = tableView.getTableViewState()
  
  if row < 0 or row >= state.rows.len or
     col < 0 or col >= state.columns.len:
    return
  
  if state.onCellActivated != nil:
    state.onCellActivated(row, col)

proc sortByColumnIndex*(tableView: Widget, colIndex: int) =
  let state = tableView.getTableViewState()
  
  if colIndex < 0 or colIndex >= state.columns.len or not state.columns[colIndex].sortable:
    return
  
  # Get the current sort direction and toggle it
  let currentDir = state.columns[colIndex].sortDirection
  let newDir = if currentDir == SortAscending: SortDescending else: SortAscending
  
  # Reset all other columns' sort directions
  for i in 0..<state.columns.len:
    if i != colIndex:
      state.columns[i].sortDirection = SortNone
  
  # Set the new sort direction for this column
  state.columns[colIndex].sortDirection = newDir
  
  # Call the sort handler if available
  if state.sortByColumn != nil:
    state.sortByColumn(colIndex, newDir)
  
  tableView.markDirty()

proc formatCellText(text: string, width: int, align: ColumnAlign): string =
  if text.runeLen() >= width:
    return text.runeSubStr(0, width - 1) & "…"
  
  let padding = width - text.runeLen()
  
  case align
  of AlignLeft:
    return text & " ".repeat(padding)
  of AlignRight:
    return " ".repeat(padding) & text
  of AlignCenter:
    let leftPad = padding div 2
    let rightPad = padding - leftPad
    return " ".repeat(leftPad) & text & " ".repeat(rightPad)

proc renderTableView*(widget: Widget) =
  let state = widget.getTableViewState()
  let rect = widget.rect
  
  # Skip if invalid dimensions
  if rect.width <= 0 or rect.height <= 0 or state.columns.len == 0:
    return
  
  # Clear the area
  var bgStyle = Style(fg: widget.style.fg, bg: widget.style.bg)
  setStyle(bgStyle)
  
  for y in 0..<rect.height:
    setCursor(rect.x, rect.y + y)
    for x in 0..<rect.width:
      stdout.write(" ")
  
  # Calculate total table width
  var totalWidth = 0
  for col in state.columns:
    totalWidth += col.width
  
  # Calculate visible column range
  let (firstVisibleCol, lastVisibleCol) = getVisibleColumnRange(widget)
  
  # Calculate visible row range
  let (firstVisibleRow, lastVisibleRow) = getVisibleRowRange(widget)
  
  # Render header if enabled
  if state.showHeader and state.headerHeight > 0:
    var colPos = rect.x - state.horScrollOffset
    
    for colIdx in firstVisibleCol..lastVisibleCol:
      let column = state.columns[colIdx]
      let colWidth = column.width
      
      # Skip columns that are completely outside the visible area
      if colPos + colWidth <= rect.x or colPos >= rect.x + rect.width:
        colPos += colWidth
        continue
      
      # Calculate visible portion of the column
      let visibleColX = max(rect.x, colPos)
      let visibleColWidth = min(rect.x + rect.width, colPos + colWidth) - visibleColX
      
      # Set header style
      var headerStyle = Style(fg: widget.style.focusFg, bg: widget.style.bg)
      setStyle(headerStyle)
      
      # Render header cell
      for i in 0..<state.headerHeight:
        setCursor(visibleColX, rect.y + i)
        
        var headerText = column.title
        if column.sortable:
          if column.sortDirection == SortAscending:
            headerText &= " ↑"
          elif column.sortDirection == SortDescending:
            headerText &= " ↓"
        
        let displayText = formatCellText(headerText, colWidth, column.align)
        let startOffset = max(0, state.horScrollOffset - colPos + rect.x)
        
        if startOffset < displayText.len:
          stdout.write(displayText[startOffset..<min(displayText.len, startOffset + visibleColWidth)])
      
      # Draw grid lines if enabled
      if state.showGrid:
        setStyle(bgStyle)
        for i in 0..<state.headerHeight:
          setCursor(visibleColX + visibleColWidth - 1, rect.y + i)
          stdout.write("│")
        
        setCursor(visibleColX, rect.y + state.headerHeight - 1)
        for i in 0..<visibleColWidth:
          stdout.write("─")
      
      colPos += colWidth
  
  # Render data rows
  let dataTop = rect.y + (if state.showHeader: state.headerHeight else: 0)
  var rowY = dataTop
  
  for rowIdx in firstVisibleRow..lastVisibleRow:
    if rowIdx >= state.rows.len or rowY >= rect.y + rect.height:
      break
    
    let row = state.rows[rowIdx]
    var colPos = rect.x - state.horScrollOffset
    
    for colIdx in firstVisibleCol..lastVisibleCol:
      let column = state.columns[colIdx]
      let colWidth = column.width
      
      # Skip columns that are completely outside the visible area
      if colPos + colWidth <= rect.x or colPos >= rect.x + rect.width:
        colPos += colWidth
        continue
      
      # Calculate visible portion of the column
      let visibleColX = max(rect.x, colPos)
      let visibleColWidth = min(rect.x + rect.width, colPos + colWidth) - visibleColX
      
      # Get cell text
      let cellText = if colIdx < row.cells.len: row.cells[colIdx].text else: ""
      
      # Cell style based on selection state
      var cellStyle: Style
      let isSelected = case state.selectionMode
                       of SelectRow: rowIdx == state.selectedRow
                       of SelectCell: rowIdx == state.selectedRow and colIdx == state.selectedColumn
                       of SelectNone: false
      
      if isSelected and widget.hasFlag(WidgetFocused):
        cellStyle = Style(fg: widget.style.selectedFg, bg: widget.style.selectedBg)
      elif not row.isEnabled:
        cellStyle = Style(fg: widget.style.disabledFg, bg: widget.style.bg)
      else:
        cellStyle = Style(fg: widget.style.fg, bg: widget.style.bg)
      
      setStyle(cellStyle)
      
      # Check if custom renderer is available
      let cellRect = Rect(x: visibleColX, y: rowY, width: visibleColWidth, height: state.rowHeight)
      if state.customCellRenderer != nil:
        state.customCellRenderer(widget, rowIdx, colIdx, cellRect, isSelected)
      else:
        # Default rendering
        for i in 0..<state.rowHeight:
          setCursor(visibleColX, rowY + i)
          
          if i == 0:  # Only render text in first row if multi-line
            let displayText = formatCellText(cellText, colWidth, column.align)
            let startOffset = max(0, state.horScrollOffset - colPos + rect.x)
            
            if startOffset < displayText.len:
              stdout.write(displayText[startOffset..<min(displayText.len, startOffset + visibleColWidth)])
          else:
            for j in 0..<visibleColWidth:
              stdout.write(" ")
      
      # Draw grid lines if enabled
      if state.showGrid:
        setStyle(bgStyle)
        for i in 0..<state.rowHeight:
          setCursor(visibleColX + visibleColWidth - 1, rowY + i)
          stdout.write("│")
        
        setCursor(visibleColX, rowY + state.rowHeight - 1)
        for i in 0..<visibleColWidth:
          stdout.write("─")
      
      colPos += colWidth
    
    rowY += state.rowHeight

proc handleTableViewKeyEvent*(widget: Widget, event: KeyEvent): bool =
  let state = widget.getTableViewState()
  
  if state.columns.len == 0 or state.rows.len == 0:
    return false
  
  case event.key
  of KeyUp:
    if state.selectedRow > 0:
      widget.selectCell(state.selectedRow - 1, state.selectedColumn)
    return true
  of KeyDown:
    if state.selectedRow < state.rows.len - 1:
      widget.selectCell(state.selectedRow + 1, state.selectedColumn)
    elif state.selectedRow == -1 and state.rows.len > 0:
      widget.selectCell(0, max(0, state.selectedColumn))
    return true
  of KeyLeft:
    if state.selectionMode == SelectCell and state.selectedColumn > 0:
      widget.selectCell(state.selectedRow, state.selectedColumn - 1)
    return true
  of KeyRight:
    if state.selectionMode == SelectCell and 
       state.selectedColumn < state.columns.len - 1:
      widget.selectCell(state.selectedRow, state.selectedColumn + 1)
    return true
  of KeyHome:
    if ModCtrl in event.modifiers:
      # Go to first row
      widget.selectCell(0, state.selectedColumn)
    else:
      # Go to first column in current row
      if state.selectionMode == SelectCell and state.selectedRow >= 0:
        widget.selectCell(state.selectedRow, 0)
    return true
  of KeyEnd:
    if ModCtrl in event.modifiers:
      # Go to last row
      widget.selectCell(state.rows.len - 1, state.selectedColumn)
    else:
      # Go to last column in current row
      if state.selectionMode == SelectCell and state.selectedRow >= 0:
        widget.selectCell(state.selectedRow, state.columns.len - 1)
    return true
  of KeyPageUp:
    let rect = widget.rect
    let visibleRows = (rect.height - (if state.showHeader: state.headerHeight else: 0)) div state.rowHeight
    let newRow = max(0, state.selectedRow - visibleRows)
    widget.selectCell(newRow, state.selectedColumn)
    return true
  of KeyPageDown:
    let rect = widget.rect
    let visibleRows = (rect.height - (if state.showHeader: state.headerHeight else: 0)) div state.rowHeight
    let newRow = min(state.rows.len - 1, state.selectedRow + visibleRows)
    widget.selectCell(newRow, state.selectedColumn)
    return true
  of KeyEnter:
    if state.selectedRow >= 0:
      if state.selectionMode == SelectCell:
        widget.activateCell(state.selectedRow, state.selectedColumn)
      else:
        widget.activateCell(state.selectedRow, 0)
    return true
  else:
    return false

proc handleTableViewMouseEvent*(widget: Widget, event: MouseEvent): bool =
  let state = widget.getTableViewState()
  
  if state.columns.len == 0:
    return false
  
  # Handle scrolling
  if event.button == MouseWheelUp or event.button == MouseWheelDown:
    if event.button == MouseWheelUp:
      if state.vertScrollOffset > 0:
        state.vertScrollOffset -= 1
        widget.markDirty()
    else:  # ScrollDirection.Down
      let rect = widget.rect
      let visibleRows = (rect.height - (if state.showHeader: state.headerHeight else: 0)) div state.rowHeight
      let maxScroll = max(0, state.rows.len - visibleRows)
      
      if state.vertScrollOffset < maxScroll:
        state.vertScrollOffset += 1
        widget.markDirty()
    return true
  
  # Handle clicks
  if event.action == MousePressed and event.button == MouseLeft:
    let rect = widget.rect
    let headerHeight = if state.showHeader: state.headerHeight else: 0
    
    # Check if click is in header area
    if state.showHeader and event.y >= rect.y and event.y < rect.y + headerHeight:
      let colIndex = getColumnAt(widget, event.x)
      
      if colIndex >= 0 and colIndex < state.columns.len:
        # Header click
        if state.columns[colIndex].sortable:
          sortByColumnIndex(widget, colIndex)
        
        if state.onHeaderClicked != nil:
          state.onHeaderClicked(colIndex)
      
      return true
    
    # Check if click is in data area
    let rowIndex = getRowAt(widget, event.y)
    let colIndex = getColumnAt(widget, event.x)
    
    if rowIndex >= 0 and rowIndex < state.rows.len and
       colIndex >= 0 and colIndex < state.columns.len:
      # Select cell or row
      if state.selectionMode == SelectCell:
        widget.selectCell(rowIndex, colIndex)
      else:
        widget.selectCell(rowIndex, state.selectedColumn)
      
      # Activate cell (single click for now)
      widget.activateCell(rowIndex, colIndex)
      
      return true
  
  return false

# Register tableview widget handlers
proc registerTableViewWidget*() =
  # registerWidgetRenderer("tableview", renderTableView)
  # registerWidgetKeyHandler("tableview", handleTableViewKeyEvent)
  # registerWidgetMouseHandler("tableview", handleTableViewMouseEvent)
  discard

# Auto-register when module is imported
registerTableViewWidget()