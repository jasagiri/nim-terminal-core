# Keyboard Shortcuts Example
# Demonstrates the use of the keyboard shortcuts system

import std/strformat
import libterminal
import libterminal/shortcuts

proc main() =
  # Initialize terminal
  initTerminal()
  
  # Create buffer and widget manager
  var buffer = newBuffer(getTerminalWidth(), getTerminalHeight())
  var manager = newWidgetManager(buffer)
  
  # Create a vertical layout for the app
  var mainLayout = newVerticalLayout("main")
  mainLayout.rect = Rect(x: 0, y: 0, width: getTerminalWidth(), height: getTerminalHeight())
  
  # Create a title label at the top
  var titleLabel = newLabel("title", "Keyboard Shortcuts Demo")
  titleLabel.setTextAlign(TextAlignCenter)
  titleLabel.style.fg = ColorYellow
  
  # Create status label to show last action
  var statusLabel = newLabel("status", "Press some shortcuts...")
  statusLabel.setTextAlign(TextAlignCenter)
  statusLabel.style.fg = ColorGreen
  
  # Create a shortcut manager
  var shortcutManager = newShortcutManager()
  
  # Create a text area to show all active shortcuts
  var shortcutsList = newLabel("shortcuts", "")
  shortcutsList.setMultiline(true)
  
  # Define some shortcut actions
  shortcutManager.registerShortcut(Key.N, {ModCtrl}, "New File", proc() =
    statusLabel.setText("Action: New File")
  )
  
  shortcutManager.registerShortcut(Key.O, {ModCtrl}, "Open File", proc() =
    statusLabel.setText("Action: Open File")
  )
  
  shortcutManager.registerShortcut(Key.S, {ModCtrl}, "Save File", proc() =
    statusLabel.setText("Action: Save File")
  )
  
  shortcutManager.registerShortcut(Key.S, {ModCtrl, ModShift}, "Save As", proc() =
    statusLabel.setText("Action: Save As")
  )
  
  shortcutManager.registerShortcut(Key.Q, {ModCtrl}, "Quit", proc() =
    statusLabel.setText("Action: Quit (not actually quitting in this demo)")
  )
  
  shortcutManager.registerShortcut(Key.Z, {ModCtrl}, "Undo", proc() =
    statusLabel.setText("Action: Undo")
  )
  
  shortcutManager.registerShortcut(Key.Y, {ModCtrl}, "Redo", proc() =
    statusLabel.setText("Action: Redo")
  )
  
  shortcutManager.registerShortcut(Key.X, {ModCtrl}, "Cut", proc() =
    statusLabel.setText("Action: Cut")
  )
  
  shortcutManager.registerShortcut(Key.C, {ModCtrl}, "Copy", proc() =
    statusLabel.setText("Action: Copy")
  )
  
  shortcutManager.registerShortcut(Key.V, {ModCtrl}, "Paste", proc() =
    statusLabel.setText("Action: Paste")
  )
  
  # Create a button to toggle shortcuts on/off
  var toggleButton = newButton("toggle", "Toggle Shortcuts")
  toggleButton.setOnClick(proc() =
    if shortcutManager.isEnabled():
      shortcutManager.disable()
      toggleButton.setText("Enable Shortcuts")
      statusLabel.setText("Shortcuts disabled")
    else:
      shortcutManager.enable()
      toggleButton.setText("Disable Shortcuts")
      statusLabel.setText("Shortcuts enabled")
  )
  
  # Create a button to add "editor" context
  var editorContextButton = newButton("editorContext", "Activate Editor Context")
  var editorContextActive = false
  editorContextButton.setOnClick(proc() =
    if editorContextActive:
      discard shortcutManager.popContext()
      editorContextActive = false
      editorContextButton.setText("Activate Editor Context")
      statusLabel.setText("Editor context deactivated")
    else:
      shortcutManager.pushContext("editor")
      editorContextActive = true
      editorContextButton.setText("Deactivate Editor Context")
      statusLabel.setText("Editor context activated")
    
    # Update shortcuts list
    updateShortcutsList()
  )
  
  # Register some editor-specific shortcuts
  shortcutManager.registerShortcut(Key.F, {ModCtrl}, "Find", proc() =
    statusLabel.setText("Action: Find")
  , "editor")
  
  shortcutManager.registerShortcut(Key.H, {ModCtrl}, "Replace", proc() =
    statusLabel.setText("Action: Replace")
  , "editor")
  
  shortcutManager.registerShortcut(Key.G, {ModCtrl}, "Go to Line", proc() =
    statusLabel.setText("Action: Go to Line")
  , "editor")
  
  # Function to update the shortcuts list
  proc updateShortcutsList() =
    var text = "Active Shortcuts:\n"
    
    for shortcut in shortcutManager.getActiveShortcuts():
      let binding = formatKeyBinding(shortcut.key, shortcut.modifiers)
      text &= fmt"{binding}: {shortcut.description} ({shortcut.context})" & "\n"
    
    shortcutsList.setText(text)
  
  # Initial update of shortcuts list
  updateShortcutsList()
  
  # Create footer with instructions
  var footerLabel = newLabel("footer", "Press ESC to exit the demo")
  footerLabel.setTextAlign(TextAlignCenter)
  footerLabel.style.fg = ColorBrightBlack
  
  # Add widgets to layout
  mainLayout.addWidget(titleLabel, LayoutSizeFixed, 1)
  mainLayout.addWidget(statusLabel, LayoutSizeFixed, 1)
  
  # Create a horizontal layout for buttons
  var buttonLayout = newHorizontalLayout("buttons")
  buttonLayout.addWidget(toggleButton, LayoutSizePercent, 50)
  buttonLayout.addWidget(editorContextButton, LayoutSizePercent, 50)
  
  mainLayout.addWidget(buttonLayout, LayoutSizeFixed, 3)
  mainLayout.addWidget(shortcutsList, LayoutSizeFill, 0)
  mainLayout.addWidget(footerLabel, LayoutSizeFixed, 1)
  
  # Set up layout
  manager.setRootLayout(mainLayout)
  
  # Install shortcut handler
  shortcutManager.installShortcutHandler(manager)
  
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