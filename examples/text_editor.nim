# Simple Text Editor
# A practical application demonstrating multiple widgets working together

import std/strformat
import std/strutils
import std/os
import libterminal
import libterminal/shortcuts
import libterminal/databinding

type
  EditorState = ref object
    filename*: string
    content*: string
    modified*: bool
    cursorLine*: int
    cursorColumn*: int
    scrollOffset*: int

proc main() =
  # Initialize terminal
  initTerminal()
  
  # Create buffer and widget manager
  var buffer = newBuffer(getTerminalWidth(), getTerminalHeight())
  var manager = newWidgetManager(buffer)
  
  # Create shortcut manager
  var shortcuts = newShortcutManager()
  
  # Create binding manager
  var bindingManager = newBindingManager()
  
  # Create editor state
  var editorState = EditorState(
    filename: "untitled.txt",
    content: "Welcome to the Simple Text Editor!\n\nThis is a demonstration of the libterminal widget system.\nYou can edit this text and use keyboard shortcuts.\n\nShortcuts:\n- Ctrl+N: New file\n- Ctrl+O: Open file (placeholder)\n- Ctrl+S: Save file (placeholder)\n- Ctrl+Q: Quit\n- F1: Show help",
    modified: false,
    cursorLine: 0,
    cursorColumn: 0,
    scrollOffset: 0
  )
  
  # Create data context for editor state
  var editorContext = newDataContext()
  editorContext.addProperty(newStringProperty("filename", editorState.filename))
  editorContext.addProperty(newStringProperty("content", editorState.content))
  editorContext.addProperty(newBoolProperty("modified", editorState.modified))
  editorContext.addProperty(newStringProperty("statusLine", "Line 1, Column 1"))
  
  bindingManager.addContext("editor", editorContext)
  
  # Create main layout
  var mainLayout = newVerticalLayout("main")
  mainLayout.rect = Rect(x: 0, y: 0, width: getTerminalWidth(), height: getTerminalHeight())
  
  # Create menu bar
  var menuBar = newHorizontalLayout("menuBar")
  
  var fileMenu = newButton("fileMenu", "File")
  var editMenu = newButton("editMenu", "Edit")
  var helpMenu = newButton("helpMenu", "Help")
  
  menuBar.addWidget(fileMenu, LayoutSizeAuto, 0)
  menuBar.addWidget(editMenu, LayoutSizeAuto, 0)
  menuBar.addWidget(helpMenu, LayoutSizeAuto, 0)
  
  # Create status bar at bottom
  var statusBar = newHorizontalLayout("statusBar")
  
  var filenameLabel = newLabel("filenameLabel", editorState.filename)
  var modifiedLabel = newLabel("modifiedLabel", "")
  var positionLabel = newLabel("positionLabel", "Line 1, Column 1")
  
  statusBar.addWidget(filenameLabel, LayoutSizeFill, 0)
  statusBar.addWidget(modifiedLabel, LayoutSizeAuto, 0)
  statusBar.addWidget(positionLabel, LayoutSizeAuto, 0)
  
  # Create main text area
  var textArea = newTextInput("textArea", editorState.content)
  textArea.setMultiline(true)
  
  # Style the widgets
  menuBar.style.bg = ColorBlue
  fileMenu.style.bg = ColorBlue
  fileMenu.style.fg = ColorWhite
  editMenu.style.bg = ColorBlue
  editMenu.style.fg = ColorWhite
  helpMenu.style.bg = ColorBlue
  helpMenu.style.fg = ColorWhite
  
  statusBar.style.bg = ColorGray
  filenameLabel.style.bg = ColorGray
  filenameLabel.style.fg = ColorBlack
  modifiedLabel.style.bg = ColorGray
  modifiedLabel.style.fg = ColorRed
  positionLabel.style.bg = ColorGray
  positionLabel.style.fg = ColorBlack
  
  textArea.style.bg = ColorWhite
  textArea.style.fg = ColorBlack
  textArea.focusStyle.bg = ColorWhite
  textArea.focusStyle.fg = ColorBlack
  
  # Set up data bindings
  
  # Bind filename
  let filenameProp = newStringProperty("filenameDisplay", editorState.filename)
  filenameProp.setAccessors(
    getter = proc(): PropertyValue = newPropertyValue(filenameLabel.getText()),
    setter = proc(value: PropertyValue) =
      filenameLabel.setText(value.asString())
    ,
    notifier = proc() = filenameLabel.markDirty()
  )
  
  discard bindingManager.createBinding(
    editorContext.getProperty("filename").get,
    filenameProp,
    OneWayToTarget
  )
  
  # Bind modified indicator
  let modifiedProp = newStringProperty("modifiedDisplay", "")
  modifiedProp.setAccessors(
    getter = proc(): PropertyValue = newPropertyValue(modifiedLabel.getText()),
    setter = proc(value: PropertyValue) =
      let text = if value.asBool(): " [MODIFIED]" else: ""
      modifiedLabel.setText(text)
    ,
    notifier = proc() = modifiedLabel.markDirty()
  )
  
  discard bindingManager.createBinding(
    editorContext.getProperty("modified").get,
    modifiedProp,
    OneWayToTarget,
    proc(value: PropertyValue): PropertyValue = value  # Pass through as is
  )
  
  # Bind content to text area
  let contentProp = newStringProperty("contentDisplay", editorState.content)
  contentProp.setAccessors(
    getter = proc(): PropertyValue = newPropertyValue(textArea.getText()),
    setter = proc(value: PropertyValue) =
      textArea.setText(value.asString())
    ,
    notifier = proc() = textArea.markDirty()
  )
  
  discard bindingManager.createBinding(
    editorContext.getProperty("content").get,
    contentProp,
    TwoWay
  )
  
  # Update position label
  proc updatePosition() =
    let text = fmt"Line {editorState.cursorLine + 1}, Column {editorState.cursorColumn + 1}"
    positionLabel.setText(text)
  
  # Set up event handlers
  textArea.setOnTextChanged(proc(text: string) =
    editorState.content = text
    editorState.modified = true
    editorContext.setStringProperty("content", text)
    editorContext.setBoolProperty("modified", true)
    updatePosition()
  )
  
  # Set up menu handlers
  var helpDialogOpen = false
  helpMenu.setOnClick(proc() =
    if not helpDialogOpen:
      helpDialogOpen = true
      
      var helpDialog = newDialog("helpDialog", "Help")
      helpDialog.setContent("Keyboard Shortcuts:\n\nCtrl+N - New file\nCtrl+O - Open file\nCtrl+S - Save file\nCtrl+Q - Quit\nF1 - Show this help\n\nPress Esc to close this dialog.")
      helpDialog.addButton("Close", proc() =
        helpDialogOpen = false
        # Remove dialog from layout
        discard manager.removeWidget(helpDialog)
      )
      
      manager.addWidget(helpDialog)
  )
  
  fileMenu.setOnClick(proc() =
    # Show file operations info
    let infoDialog = newDialog("fileDialog", "File Operations")
    infoDialog.setContent("File operations are placeholder implementations.\n\nIn a real editor, these would:\n- New: Clear current content\n- Open: Show file picker\n- Save: Write to file\n\nPress Esc to close.")
    infoDialog.addButton("OK", proc() =
      discard manager.removeWidget(infoDialog)
    )
    
    manager.addWidget(infoDialog)
  )
  
  # Set up keyboard shortcuts
  shortcuts.registerShortcut(Key.N, {ModCtrl}, "New file", proc() =
    editorState.content = ""
    editorState.filename = "untitled.txt"
    editorState.modified = false
    editorContext.setStringProperty("content", "")
    editorContext.setStringProperty("filename", "untitled.txt")
    editorContext.setBoolProperty("modified", false)
  )
  
  shortcuts.registerShortcut(Key.O, {ModCtrl}, "Open file", proc() =
    # Placeholder for open file
    let infoDialog = newDialog("openDialog", "Open File")
    infoDialog.setContent("Open file functionality would be implemented here.\n\nThis would show a file picker dialog.")
    infoDialog.addButton("OK", proc() =
      discard manager.removeWidget(infoDialog)
    )
    manager.addWidget(infoDialog)
  )
  
  shortcuts.registerShortcut(Key.S, {ModCtrl}, "Save file", proc() =
    # Placeholder for save file
    editorState.modified = false
    editorContext.setBoolProperty("modified", false)
    
    let infoDialog = newDialog("saveDialog", "Save File")
    infoDialog.setContent(fmt"File '{editorState.filename}' saved successfully!\n\n(This is a placeholder - no actual file was saved)")
    infoDialog.addButton("OK", proc() =
      discard manager.removeWidget(infoDialog)
    )
    manager.addWidget(infoDialog)
  )
  
  var shouldQuit = false
  shortcuts.registerShortcut(Key.Q, {ModCtrl}, "Quit", proc() =
    if editorState.modified:
      let quitDialog = newDialog("quitDialog", "Confirm Quit")
      quitDialog.setContent("You have unsaved changes.\n\nAre you sure you want to quit?")
      quitDialog.addButton("Yes", proc() =
        shouldQuit = true
      )
      quitDialog.addButton("No", proc() =
        discard manager.removeWidget(quitDialog)
      )
      manager.addWidget(quitDialog)
    else:
      shouldQuit = true
  )
  
  shortcuts.registerShortcut(Key.F1, {}, "Show help", proc() =
    if not helpDialogOpen:
      helpDialogOpen = true
      
      var helpDialog = newDialog("helpDialog", "Help")
      helpDialog.setContent("Simple Text Editor Help\n\nThis editor demonstrates the libterminal widget system with:\n- Menu bar\n- Text editing area\n- Status bar\n- Keyboard shortcuts\n- Data binding\n- Modal dialogs\n\nPress Esc to close.")
      helpDialog.addButton("Close", proc() =
        helpDialogOpen = false
        discard manager.removeWidget(helpDialog)
      )
      
      manager.addWidget(helpDialog)
  )
  
  # Install shortcut handler
  shortcuts.installShortcutHandler(manager)
  
  # Add to main layout
  mainLayout.addWidget(menuBar, LayoutSizeFixed, 1)
  mainLayout.addWidget(textArea, LayoutSizeFill, 0)
  mainLayout.addWidget(statusBar, LayoutSizeFixed, 1)
  
  # Set focus to text area
  manager.setFocus(textArea)
  
  # Set up layout
  manager.setRootLayout(mainLayout)
  
  # Initial position update
  updatePosition()
  
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
        # Close any open dialogs first
        if helpDialogOpen:
          helpDialogOpen = false
        else:
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