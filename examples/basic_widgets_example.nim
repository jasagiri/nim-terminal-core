# Basic Widgets Example
# Demonstrates the use of all basic widgets in the libterminal library

import std/strformat
import libterminal

proc main() =
  # Initialize terminal
  initTerminal()
  
  # Create widget manager
  var manager = newWidgetManager()
  
  # Create root layout (vertical)
  var rootLayout = newVerticalLayout("root")
  rootLayout.rect = Rect(x: 0, y: 0, width: getTerminalWidth(), height: getTerminalHeight())
  
  # Add title label
  var titleLabel = newLabel("title", "Terminal Widgets Demo")
  titleLabel.setTextAlign(TextAlignCenter)
  titleLabel.style.fg = ColorYellow
  
  # Add description label
  var descLabel = newLabel("desc", "This example demonstrates all basic widgets in the libterminal library.")
  descLabel.setTextAlign(TextAlignCenter)
  
  # Create a horizontal layout for checkboxes
  var checkboxLayout = newHorizontalLayout("checkboxLayout")
  
  # Add checkboxes
  var checkbox1 = newCheckbox("checkbox1", "Option 1", true)
  var checkbox2 = newCheckbox("checkbox2", "Option 2", false)
  var checkbox3 = newCheckbox("checkbox3", "Disabled Option", false)
  checkbox3.flags.excl(WidgetEnabled)
  
  checkboxLayout.addWidget(checkbox1, 1)
  checkboxLayout.addWidget(checkbox2, 1)
  checkboxLayout.addWidget(checkbox3, 1)
  
  # Create text input
  var textInput = newTextInput("input", "Edit me...")
  
  # Create a button
  var button = newButton("button", "Click Me!")
  button.setOnClick(proc() =
    descLabel.setText("Button clicked!")
  )
  
  # Create a horizontal layout for the ListBox and ProgressBar
  var widgetsLayout = newHorizontalLayout("widgetsLayout")
  
  # Create a ListBox
  var listBox = newListBox("listBox")
  listBox.addItem("Item 1")
  listBox.addItem("Item 2")
  listBox.addItem("Item 3")
  listBox.addItem("Item 4")
  listBox.addItem("Item 5")
  listBox.setSelectedIndex(0)
  
  # Create a ProgressBar
  var progressBar = newProgressBar("progressBar")
  progressBar.setValue(75)
  
  widgetsLayout.addWidget(listBox, 1)
  widgetsLayout.addWidget(progressBar, 1)
  
  # Add all widgets to the root layout
  rootLayout.addWidget(titleLabel, LayoutSizeFixed, 1)
  rootLayout.addWidget(descLabel, LayoutSizeFixed, 1)
  rootLayout.addSpacing(1)
  rootLayout.addWidget(checkboxLayout, LayoutSizeFixed, 1)
  rootLayout.addSpacing(1)
  rootLayout.addWidget(textInput, LayoutSizeFixed, 3)
  rootLayout.addSpacing(1)
  rootLayout.addWidget(button, LayoutSizeFixed, 1)
  rootLayout.addSpacing(1)
  rootLayout.addWidget(widgetsLayout, LayoutSizeFill, 0)
  
  # Set the root layout for the widget manager
  manager.setRootLayout(rootLayout)
  
  # Setup event handlers
  listBox.setOnSelectionChange(proc(index: int, item: ListItem) =
    descLabel.setText(fmt"Selected item: {item.text}")
  )
  
  textInput.setOnTextChange(proc(text: string) =
    progressBar.setValue(float(text.len))
  )
  
  checkbox1.setOnChange(proc(checked: bool) =
    let state = if checked: "checked" else: "unchecked"
    descLabel.setText(fmt"Checkbox 1 {state}")
  )
  
  checkbox2.setOnChange(proc(checked: bool) =
    let state = if checked: "checked" else: "unchecked"
    descLabel.setText(fmt"Checkbox 2 {state}")
  )
  
  # Main event loop
  var running = true
  while running:
    # Render the UI
    clearScreen()
    manager.render()
    
    # Process input
    let event = readEvent(100)
    case event.kind
    of EvKey:
      if event.key == Key.Escape:
        running = false
      elif event.key == Key.Tab:
        manager.focusNextWidget()
      else:
        manager.handleKeyEvent(event.key)
    of EvMouse:
      manager.handleMouseEvent(event.mouse)
    of EvResize:
      rootLayout.rect.width = event.resize.width
      rootLayout.rect.height = event.resize.height
      manager.layoutWidgets()
    else:
      discard
  
  # Clean up
  cleanupTerminal()

when isMainModule:
  main()