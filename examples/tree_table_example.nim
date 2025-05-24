# Tree and Table Example
# Demonstrates the use of TreeView and TableView widgets

import std/strformat
import libterminal

proc createExampleTree(): TreeNode =
  # Create a root node
  let root = newTreeNode("root", "Project")
  root.isExpanded = true
  
  # Create first level children
  let src = newTreeNode("src", "Source Code")
  let docs = newTreeNode("docs", "Documentation")
  let tests = newTreeNode("tests", "Tests")
  
  # Add first level children to root
  root.addChild(src)
  root.addChild(docs)
  root.addChild(tests)
  
  # Create second level children for src
  let core = newTreeNode("core", "Core Modules")
  let ui = newTreeNode("ui", "UI Components")
  let utils = newTreeNode("utils", "Utilities")
  
  # Add second level children to src
  src.addChild(core)
  src.addChild(ui)
  src.addChild(utils)
  
  # Create third level children for ui
  ui.addChild(newTreeNode("widgets", "Widgets"))
  ui.addChild(newTreeNode("layouts", "Layouts"))
  ui.addChild(newTreeNode("rendering", "Rendering"))
  
  # Create second level children for docs
  docs.addChild(newTreeNode("api", "API Reference"))
  docs.addChild(newTreeNode("guides", "User Guides"))
  docs.addChild(newTreeNode("examples", "Examples"))
  
  # Create second level children for tests
  tests.addChild(newTreeNode("unit", "Unit Tests"))
  tests.addChild(newTreeNode("integration", "Integration Tests"))
  tests.addChild(newTreeNode("e2e", "End-to-End Tests"))
  
  return root

proc main() =
  # Initialize terminal
  initTerminal()
  
  # Create widget manager
  var manager = newWidgetManager()
  
  # Create a vertical layout for the app
  var mainLayout = newVerticalLayout("main")
  mainLayout.rect = Rect(x: 0, y: 0, width: getTerminalWidth(), height: getTerminalHeight())
  
  # Create a title label at the top
  var titleLabel = newLabel("title", "TreeView and TableView Demo")
  titleLabel.setTextAlign(TextAlignCenter)
  titleLabel.style.fg = ColorYellow
  
  # Create a horizontal layout for the main content
  var contentLayout = newHorizontalLayout("content")
  
  # Create TreeView
  var treeView = newTreeView("tree")
  treeView.setRootNode(createExampleTree())
  
  # Create TableView
  var tableView = newTableView("table")
  
  # Add columns to the table
  tableView.addColumn("id", "ID", 5, AlignRight, true)
  tableView.addColumn("name", "Name", 20, AlignLeft, true)
  tableView.addColumn("type", "Type", 10, AlignLeft, true)
  tableView.addColumn("size", "Size", 8, AlignRight, true)
  tableView.addColumn("date", "Date", 12, AlignCenter, true)
  
  # Add sample data to the table
  tableView.addRow(@["1", "main.nim", "Source", "1.2 KB", "2024-01-15"])
  tableView.addRow(@["2", "widgets.nim", "Source", "4.5 KB", "2024-01-20"])
  tableView.addRow(@["3", "layout.nim", "Source", "2.8 KB", "2024-01-22"])
  tableView.addRow(@["4", "README.md", "Doc", "3.1 KB", "2024-01-10"])
  tableView.addRow(@["5", "LICENSE", "Doc", "1.0 KB", "2024-01-01"])
  tableView.addRow(@["6", "test_widgets.nim", "Test", "2.3 KB", "2024-01-25"])
  tableView.addRow(@["7", "test_layout.nim", "Test", "1.9 KB", "2024-01-26"])
  tableView.addRow(@["8", "config.nim", "Config", "0.5 KB", "2024-01-14"])
  tableView.addRow(@["9", "utils.nim", "Source", "3.6 KB", "2024-01-18"])
  tableView.addRow(@["10", "types.nim", "Source", "1.7 KB", "2024-01-12"])
  
  # Select first row in table
  tableView.selectCell(0, 0)
  
  # Set up node selected handler for TreeView
  treeView.setOnNodeSelected(proc(node: TreeNode) =
    titleLabel.setText("Selected: " & node.text)
  )
  
  # Set up cell activated handler for TableView
  tableView.setOnCellActivated(proc(row, col: int) =
    let cellText = tableView.getCellText(row, col)
    titleLabel.setText("Activated Cell: " & cellText)
  )
  
  # Set up column sort handler for TableView
  tableView.setSortByColumn(proc(column: int, direction: SortDirection) =
    titleLabel.setText(fmt"Sorting column {column} in {direction} order")
  )
  
  # Add widgets to content layout
  contentLayout.addWidget(treeView, 1)
  contentLayout.addWidget(tableView, 2)
  
  # Add footer with instructions
  var footerLabel = newLabel("footer", "Navigate: Arrow Keys | TreeView: Enter to Expand/Collapse | TableView: Enter to Activate | Press ESC to exit")
  footerLabel.style.fg = ColorBrightBlack
  
  # Add everything to main layout
  mainLayout.addWidget(titleLabel, LayoutSizeFixed, 1)
  mainLayout.addWidget(contentLayout, LayoutSizeFill, 0)
  mainLayout.addWidget(footerLabel, LayoutSizeFixed, 1)
  
  # Set the root layout
  manager.setRootLayout(mainLayout)
  
  # Main event loop
  var running = true
  while running:
    # Clear the screen
    clearScreen()
    
    # Layout and render widgets
    manager.layoutWidgets()
    manager.render()
    
    # Handle input
    let event = readEvent(100)
    case event.kind
    of EvKey:
      if event.key == Key.Escape:
        running = false
      else:
        manager.handleKeyEvent(event.key)
    of EvMouse:
      manager.handleMouseEvent(event.mouse)
    of EvResize:
      mainLayout.rect.width = event.resize.width
      mainLayout.rect.height = event.resize.height
    else:
      discard
  
  # Clean up
  cleanupTerminal()

when isMainModule:
  main()