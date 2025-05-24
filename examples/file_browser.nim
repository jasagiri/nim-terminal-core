# File Browser
# A practical application demonstrating file system navigation

import std/os
import std/strformat
import std/strutils
import std/algorithm
import libterminal
import libterminal/shortcuts

type
  FileInfo = object
    name*: string
    path*: string
    isDirectory*: bool
    size*: int64
    permissions*: string

proc getFileInfo(path: string): FileInfo =
  ## Get file information for display
  result.name = extractFilename(path)
  result.path = path
  result.isDirectory = dirExists(path)
  
  try:
    if result.isDirectory:
      result.size = -1  # Directories don't have size
    else:
      result.size = getFileSize(path)
  except:
    result.size = 0
  
  # Simple permissions placeholder
  result.permissions = "rw-r--r--"

proc formatFileSize(size: int64): string =
  ## Format file size in human readable format
  if size < 0:
    return "<DIR>"
  elif size < 1024:
    return $size & " B"
  elif size < 1024 * 1024:
    return $(size div 1024) & " KB"
  elif size < 1024 * 1024 * 1024:
    return $(size div (1024 * 1024)) & " MB"
  else:
    return $(size div (1024 * 1024 * 1024)) & " GB"

proc listDirectory(path: string): seq[FileInfo] =
  ## List files and directories in the given path
  result = @[]
  
  try:
    for kind, file in walkDir(path):
      result.add(getFileInfo(file))
    
    # Sort: directories first, then files, both alphabetically
    result.sort(proc(a, b: FileInfo): int =
      if a.isDirectory and not b.isDirectory:
        return -1
      elif not a.isDirectory and b.isDirectory:
        return 1
      else:
        return cmp(a.name.toLower(), b.name.toLower())
    )
    
    # Add parent directory entry if not at root
    if path != "/" and path != "" and not (path.len == 3 and path[1] == ':'):
      let parent = FileInfo(
        name: "..",
        path: parentDir(path),
        isDirectory: true,
        size: -1,
        permissions: "rwxr-xr-x"
      )
      result.insert(parent, 0)
  except:
    # If we can't read the directory, return empty list
    discard

proc main() =
  # Initialize terminal
  initTerminal()
  
  # Create buffer and widget manager
  var buffer = newBuffer(getTerminalWidth(), getTerminalHeight())
  var manager = newWidgetManager(buffer)
  
  # Create shortcut manager
  var shortcuts = newShortcutManager()
  
  # Current directory and file listing
  var currentPath = getCurrentDir()
  var currentFiles = listDirectory(currentPath)
  
  # Create main layout
  var mainLayout = newVerticalLayout("main")
  mainLayout.rect = Rect(x: 0, y: 0, width: getTerminalWidth(), height: getTerminalHeight())
  
  # Create title bar
  var titleBar = newHorizontalLayout("titleBar")
  var titleLabel = newLabel("title", "File Browser")
  var pathLabel = newLabel("path", currentPath)
  
  titleLabel.style.fg = ColorYellow
  titleLabel.style.bg = ColorBlue
  pathLabel.style.fg = ColorWhite
  pathLabel.style.bg = ColorBlue
  
  titleBar.addWidget(titleLabel, LayoutSizeAuto, 0)
  titleBar.addWidget(pathLabel, LayoutSizeFill, 0)
  
  # Create main content area with tree view on left and details on right
  var contentLayout = newHorizontalLayout("content")
  
  # Create tree view for directory navigation
  var directoryTree = newTreeView("dirTree")
  directoryTree.setShowRootNode(true)
  directoryTree.setIndentSize(2)
  
  # Create file list table
  var fileTable = newTableView("fileTable")
  fileTable.addColumn("name", "Name", 30, AlignLeft, true)
  fileTable.addColumn("size", "Size", 10, AlignRight, true)
  fileTable.addColumn("type", "Type", 10, AlignLeft, true)
  fileTable.addColumn("perms", "Permissions", 12, AlignLeft, false)
  
  fileTable.setShowHeader(true)
  fileTable.setShowGrid(true)
  
  # Create status bar
  var statusBar = newLabel("statusBar", fmt"Current directory: {currentPath}")
  statusBar.style.bg = ColorGray
  statusBar.style.fg = ColorBlack
  
  # Create info panel on the right
  var infoPanel = newVerticalLayout("infoPanel")
  var infoTitle = newLabel("infoTitle", "File Information")
  var infoContent = newLabel("infoContent", "Select a file to see details")
  
  infoTitle.style.fg = ColorCyan
  infoContent.setMultiline(true)
  
  infoPanel.addWidget(infoTitle, LayoutSizeFixed, 1)
  infoPanel.addWidget(infoContent, LayoutSizeFill, 0)
  
  # Update file table
  proc updateFileTable() =
    fileTable.clearRows()
    currentFiles = listDirectory(currentPath)
    
    for file in currentFiles:
      let fileType = if file.isDirectory: "Directory" else: "File"
      let size = formatFileSize(file.size)
      
      fileTable.addRow(@[file.name, size, fileType, file.permissions])
    
    # Select first item if available
    if currentFiles.len > 0:
      fileTable.selectCell(0, 0)
  
  # Update directory tree (simplified - just show current path)
  proc updateDirectoryTree() =
    let rootNode = newTreeNode("root", extractFilename(currentPath))
    if extractFilename(currentPath) == "":
      rootNode.text = currentPath
    
    directoryTree.setRootNode(rootNode)
    directoryTree.selectNode(rootNode)
    
    pathLabel.setText(currentPath)
    statusBar.setText(fmt"Current directory: {currentPath} ({currentFiles.len} items)")
  
  # Set up event handlers
  fileTable.setOnCellActivated(proc(row, col: int) =
    if row >= 0 and row < currentFiles.len:
      let file = currentFiles[row]
      
      if file.isDirectory:
        # Navigate to directory
        currentPath = file.path
        updateFileTable()
        updateDirectoryTree()
      else:
        # Show file info
        let info = fmt"""Selected File: {file.name}
        
Path: {file.path}
Size: {formatFileSize(file.size)}
Type: File
Permissions: {file.permissions}

Press Enter to navigate directories or view file details."""
        
        infoContent.setText(info)
  )
  
  fileTable.setOnSelectionChanged(proc(row, col: int) =
    if row >= 0 and row < currentFiles.len:
      let file = currentFiles[row]
      
      let info = fmt"""Name: {file.name}
Path: {file.path}
Size: {formatFileSize(file.size)}
Type: {if file.isDirectory: "Directory" else: "File"}
Permissions: {file.permissions}

{if file.isDirectory: "Press Enter to navigate" else: "Press Enter for details"}"""
      
      infoContent.setText(info)
  )
  
  directoryTree.setOnNodeSelected(proc(node: TreeNode) =
    # Show current directory info
    let info = fmt"""Current Directory: {extractFilename(currentPath)}
    
Full Path: {currentPath}
Items: {currentFiles.len}

Use the file table to navigate files and subdirectories.
Use keyboard shortcuts for quick navigation."""
    
    infoContent.setText(info)
  )
  
  # Set up keyboard shortcuts
  shortcuts.registerShortcut(Key.H, {ModCtrl}, "Go Home", proc() =
    currentPath = getHomeDir()
    updateFileTable()
    updateDirectoryTree()
  )
  
  shortcuts.registerShortcut(Key.U, {ModCtrl}, "Go Up", proc() =
    let parent = parentDir(currentPath)
    if parent != currentPath:  # Make sure we can go up
      currentPath = parent
      updateFileTable()
      updateDirectoryTree()
  )
  
  shortcuts.registerShortcut(Key.R, {ModCtrl}, "Refresh", proc() =
    updateFileTable()
    updateDirectoryTree()
  )
  
  shortcuts.registerShortcut(Key.F5, {}, "Refresh", proc() =
    updateFileTable()
    updateDirectoryTree()
  )
  
  var shouldQuit = false
  shortcuts.registerShortcut(Key.Q, {ModCtrl}, "Quit", proc() =
    shouldQuit = true
  )
  
  shortcuts.registerShortcut(Key.F1, {}, "Show Help", proc() =
    let helpDialog = newDialog("helpDialog", "File Browser Help")
    helpDialog.setContent("""File Browser Keyboard Shortcuts:

Navigation:
- Arrow Keys: Navigate file list
- Enter: Open directory or view file details
- Ctrl+H: Go to home directory  
- Ctrl+U: Go up one directory
- Ctrl+R / F5: Refresh current directory

General:
- Ctrl+Q: Quit application
- F1: Show this help
- Esc: Close dialogs

Interface:
- Left panel: Directory tree (current location)
- Center panel: File list with details
- Right panel: Selected file information""")
    
    helpDialog.addButton("Close", proc() =
      discard manager.removeWidget(helpDialog)
    )
    
    manager.addWidget(helpDialog)
  )
  
  # Install shortcut handler
  shortcuts.installShortcutHandler(manager)
  
  # Set up layout
  contentLayout.addWidget(directoryTree, LayoutSizePercent, 20)
  contentLayout.addWidget(fileTable, LayoutSizePercent, 50)
  contentLayout.addWidget(infoPanel, LayoutSizePercent, 30)
  
  mainLayout.addWidget(titleBar, LayoutSizeFixed, 1)
  mainLayout.addWidget(contentLayout, LayoutSizeFill, 0)
  mainLayout.addWidget(statusBar, LayoutSizeFixed, 1)
  
  # Set focus to file table
  manager.setFocus(fileTable)
  
  # Set up layout
  manager.setRootLayout(mainLayout)
  
  # Initial data load
  updateFileTable()
  updateDirectoryTree()
  
  # Main event loop
  var running = true
  while running and not shouldQuit:
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
        discard manager.handleEvent(event)
    of EvMouse:
      discard manager.handleEvent(event)
    of EvResize:
      mainLayout.rect.width = event.resize.width
      mainLayout.rect.height = event.resize.height
      buffer.resize(event.resize.width, event.resize.height)
    else:
      discard
  
  # Cleanup
  cleanupTerminal()

when isMainModule:
  main()