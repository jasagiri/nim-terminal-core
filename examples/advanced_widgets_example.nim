# Advanced Widgets Example
# Demonstrates the use of advanced widgets in the libterminal library

import std/strformat
import libterminal

proc demoDialog(parent: Widget) =
  # Create a dialog
  let dialog = newDialog("demo_dialog", "Confirmation Dialog", "Are you sure you want to continue?")
  
  # Set dialog size and position
  dialog.rect = Rect(x: 0, y: 0, width: 40, height: 8)
  dialog.center(getTerminalWidth(), getTerminalHeight())
  
  # Set dialog buttons
  dialog.setButtonsType(DialogButtonsYesNoCancel)
  
  # Set close callback
  dialog.setCloseCallback(proc(dlg: Widget, result: DialogResult) =
    case result
    of DialogYes:
      parent.getDialogState().content = "You clicked Yes!"
    of DialogNo:
      parent.getDialogState().content = "You clicked No!"
    of DialogCancel:
      parent.getDialogState().content = "You clicked Cancel!"
    else:
      discard
  )
  
  # Add dialog to parent
  parent.addChild(dialog)

proc demoMenu(parent: Widget): Widget =
  # Create a menu bar
  let menuBar = newMenu("main_menu")
  menuBar.rect = Rect(x: 0, y: 0, width: getTerminalWidth(), height: 1)
  
  # Create File menu
  let fileMenu = newSubMenuItem("File", "file_menu")
  let newItem = newMenuItem("New", "file_new", "Ctrl+N", proc() =
    parent.getDialogState().content = "You selected New"
  )
  let openItem = newMenuItem("Open", "file_open", "Ctrl+O", proc() =
    parent.getDialogState().content = "You selected Open"
  )
  let saveItem = newMenuItem("Save", "file_save", "Ctrl+S", proc() =
    parent.getDialogState().content = "You selected Save"
  )
  let saveAsItem = newMenuItem("Save As", "file_save_as", "Ctrl+Shift+S", proc() =
    parent.getDialogState().content = "You selected Save As"
  )
  let separator = newMenuSeparator()
  let exitItem = newMenuItem("Exit", "file_exit", "Alt+F4", proc() =
    parent.getDialogState().content = "You selected Exit"
  )
  
  # Add items to File menu
  fileMenu.addItem(newItem)
  fileMenu.addItem(openItem)
  fileMenu.addItem(saveItem)
  fileMenu.addItem(saveAsItem)
  fileMenu.addItem(separator)
  fileMenu.addItem(exitItem)
  
  # Create Edit menu
  let editMenu = newSubMenuItem("Edit", "edit_menu")
  let cutItem = newMenuItem("Cut", "edit_cut", "Ctrl+X", proc() =
    parent.getDialogState().content = "You selected Cut"
  )
  let copyItem = newMenuItem("Copy", "edit_copy", "Ctrl+C", proc() =
    parent.getDialogState().content = "You selected Copy"
  )
  let pasteItem = newMenuItem("Paste", "edit_paste", "Ctrl+V", proc() =
    parent.getDialogState().content = "You selected Paste"
  )
  
  # Add items to Edit menu
  editMenu.addItem(cutItem)
  editMenu.addItem(copyItem)
  editMenu.addItem(pasteItem)
  
  # Create Help menu
  let helpMenu = newSubMenuItem("Help", "help_menu")
  let aboutItem = newMenuItem("About", "help_about", "", proc() =
    parent.getDialogState().content = "You selected About"
  )
  
  # Add items to Help menu
  helpMenu.addItem(aboutItem)
  
  # Add menus to menu bar
  menuBar.addItem(fileMenu)
  menuBar.addItem(editMenu)
  menuBar.addItem(helpMenu)
  
  return menuBar

proc demoTabView(parent: Widget): Widget =
  # Create a tab view
  let tabView = newTabView("main_tabs")
  tabView.rect = Rect(x: 0, y: 2, width: getTerminalWidth(), height: getTerminalHeight() - 6)
  
  # Create tab contents
  let tab1 = newLabel("tab1_content", "This is the content of Tab 1")
  let tab2 = newLabel("tab2_content", "Tab 2 shows a different content")
  let tab3 = newTextInput("tab3_content", "Editable content in Tab 3")
  
  # Create a list for Tab 4
  let tab4 = newListBox("tab4_content")
  tab4.addItem("Item 1")
  tab4.addItem("Item 2")
  tab4.addItem("Item 3")
  tab4.addItem("Item 4")
  tab4.addItem("Item 5")
  
  # Add tabs to tab view
  tabView.addTab("Tab 1", "tab1", tab1, true)
  tabView.addTab("Tab 2", "tab2", tab2, true)
  tabView.addTab("Tab 3", "tab3", tab3, true)
  tabView.addTab("Items", "tab4", tab4, true)
  
  # Set active tab
  tabView.setActiveTab(0)
  
  return tabView

proc demoScrollView(parent: Widget): Widget =
  # Create a scroll view
  let scrollView = newScrollView("demo_scroll")
  scrollView.rect = Rect(x: 0, y: getTerminalHeight() - 4, width: getTerminalWidth(), height: 4)
  
  # Create content for the scroll view
  let content = newLabel("scroll_content", "")
  
  # Generate a lot of text to make it scrollable
  var longText = "This is a scrollable content. You can use arrow keys or mouse wheel to scroll.\n\n"
  for i in 1..20:
    longText &= fmt"Line {i}: This is a line of text that demonstrates scrolling functionality.\n"
  
  content.setText(longText)
  
  # Set content widget
  scrollView.setContentWidget(content)
  
  # Set content size - should be bigger than viewport
  content.rect = Rect(x: 0, y: 0, width: getTerminalWidth(), height: 25)
  
  return scrollView

proc main() =
  # Initialize terminal
  initTerminal()
  
  # Create main widget manager
  var manager = newWidgetManager()
  
  # Create main dialog as parent for everything
  var mainDialog = newDialog("main", "Advanced Widgets Demo", "This example demonstrates advanced widgets in the libterminal library.")
  mainDialog.rect = Rect(x: 0, y: 0, width: getTerminalWidth(), height: getTerminalHeight())
  mainDialog.setHasBorder(false)  # No border for the main dialog
  manager.setRootLayout(mainDialog.layoutNode)
  
  # Add menu bar
  let menuBar = demoMenu(mainDialog)
  mainDialog.addChild(menuBar)
  
  # Add tab view
  let tabView = demoTabView(mainDialog)
  mainDialog.addChild(tabView)
  
  # Add scroll view
  let scrollView = demoScrollView(mainDialog)
  mainDialog.addChild(scrollView)
  
  # Add exit instructions
  let instructions = newLabel("instructions", "Press Esc to exit | Tab to change focus | F1 to show dialog")
  instructions.rect = Rect(x: 0, y: getTerminalHeight() - 1, width: getTerminalWidth(), height: 1)
  mainDialog.addChild(instructions)
  
  # Main event loop
  var running = true
  while running:
    # Render the UI
    clearScreen()
    manager.layoutWidgets()
    manager.render()
    
    # Process input
    let event = readEvent(100)
    case event.kind
    of EvKey:
      if event.key == Key.Escape:
        running = false
      elif event.key == Key.F1:
        demoDialog(mainDialog)
      else:
        manager.handleKeyEvent(event.key)
    of EvMouse:
      manager.handleMouseEvent(event.mouse)
    of EvResize:
      # Update sizes
      mainDialog.rect.width = event.resize.width
      mainDialog.rect.height = event.resize.height
      menuBar.rect.width = event.resize.width
      tabView.rect.width = event.resize.width
      tabView.rect.height = event.resize.height - 6
      scrollView.rect.width = event.resize.width
      scrollView.rect.y = event.resize.height - 4
      instructions.rect.width = event.resize.width
      instructions.rect.y = event.resize.height - 1
    else:
      discard
  
  # Clean up
  cleanupTerminal()

when isMainModule:
  main()