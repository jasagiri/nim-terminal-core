import widgets, label, button, output, input, unicode, strutils, private/common

type
  DialogResult* = enum
    DialogNone,      # No result yet
    DialogOk,        # OK clicked
    DialogCancel,    # Cancel clicked
    DialogYes,       # Yes clicked
    DialogNo,        # No clicked
    DialogCustom     # Custom button clicked

  DialogButtonsType* = enum
    DialogButtonsOk,           # Just OK button
    DialogButtonsOkCancel,     # OK and Cancel buttons
    DialogButtonsYesNo,        # Yes and No buttons
    DialogButtonsYesNoCancel,  # Yes, No, and Cancel buttons
    DialogButtonsCustom        # Custom buttons

  DialogButtonInfo* = object
    text*: string
    result*: DialogResult
    isDefault*: bool
    id*: string

  DialogState* = ref object of WidgetState
    title*: string
    content*: string
    buttonsType*: DialogButtonsType
    buttons*: seq[DialogButtonInfo]
    customButtons*: seq[DialogButtonInfo]
    result*: DialogResult
    closeCallback*: proc(dialog: Widget, result: DialogResult) {.closure.}
    contentWidget*: Widget
    isModal*: bool
    hasBorder*: bool

proc newDialogState*(): DialogState =
  result = DialogState()
  result.title = ""
  result.content = ""
  result.buttonsType = DialogButtonsOk
  result.buttons = @[]
  result.customButtons = @[]
  result.result = DialogNone
  result.closeCallback = nil
  result.contentWidget = nil
  result.isModal = true
  result.hasBorder = true

proc newDialog*(id: string, title: string = "", content: string = ""): Widget =
  result = newWidget(id, 0, 0, 40, 10)  # Default size for dialog
  result.state = newDialogState()
  
  # Set dialog properties
  let state = DialogState(result.state)
  state.title = title
  state.content = content
  
  # Default style
  result.style.fg = ColorDefault
  result.style.bg = ColorDefault
  result.style.focusFg = ColorDefault
  result.style.focusBg = ColorDefault
  
  # A dialog can contain other widgets
  result.flags.incl(WidgetVisible)

proc getDialogState*(widget: Widget): DialogState =
  return DialogState(widget.state)

proc setTitle*(dialog: Widget, title: string) =
  let state = dialog.getDialogState()
  state.title = title
  dialog.markDirty()

proc setContent*(dialog: Widget, content: string) =
  let state = dialog.getDialogState()
  state.content = content
  
  # If we have a content widget, update it
  if state.contentWidget != nil and state.contentWidget.id == "dialog_content":
    let label = Label(state.contentWidget)
    label.setText(content)
  
  dialog.markDirty()

proc setContentWidget*(dialog: Widget, widget: Widget) =
  let state = dialog.getDialogState()
  
  # Remove old content widget if it exists
  if state.contentWidget != nil:
    discard dialog.removeChild(state.contentWidget)
  
  # Set new content widget
  state.contentWidget = widget
  state.content = "" # Clear string content since we have a widget
  
  # Add the widget as a child
  dialog.addChild(widget)
  dialog.markDirty()

proc setButtonsType*(dialog: Widget, buttonsType: DialogButtonsType) =
  let state = dialog.getDialogState()
  state.buttonsType = buttonsType
  state.buttons = @[] # Clear existing buttons
  
  # Remove existing button widgets
  for child in dialog.children:
    if child.id.startsWith("dialog_button_"):
      discard dialog.removeChild(child)
  
  case buttonsType
  of DialogButtonsOk:
    state.buttons.add(DialogButtonInfo(text: "OK", result: DialogOk, isDefault: true, id: "ok"))
  of DialogButtonsOkCancel:
    state.buttons.add(DialogButtonInfo(text: "OK", result: DialogOk, isDefault: true, id: "ok"))
    state.buttons.add(DialogButtonInfo(text: "Cancel", result: DialogCancel, isDefault: false, id: "cancel"))
  of DialogButtonsYesNo:
    state.buttons.add(DialogButtonInfo(text: "Yes", result: DialogYes, isDefault: true, id: "yes"))
    state.buttons.add(DialogButtonInfo(text: "No", result: DialogNo, isDefault: false, id: "no"))
  of DialogButtonsYesNoCancel:
    state.buttons.add(DialogButtonInfo(text: "Yes", result: DialogYes, isDefault: true, id: "yes"))
    state.buttons.add(DialogButtonInfo(text: "No", result: DialogNo, isDefault: false, id: "no"))
    state.buttons.add(DialogButtonInfo(text: "Cancel", result: DialogCancel, isDefault: false, id: "cancel"))
  of DialogButtonsCustom:
    state.buttons = state.customButtons
  
  dialog.markDirty()

proc setCustomButtons*(dialog: Widget, buttons: seq[DialogButtonInfo]) =
  let state = dialog.getDialogState()
  state.customButtons = buttons
  
  if state.buttonsType == DialogButtonsCustom:
    state.buttons = buttons
    
    # Remove existing button widgets
    for child in dialog.children:
      if child.id.startsWith("dialog_button_"):
        discard dialog.removeChild(child)
    
    dialog.markDirty()

proc setModal*(dialog: Widget, isModal: bool) =
  let state = dialog.getDialogState()
  state.isModal = isModal
  dialog.markDirty()

proc setHasBorder*(dialog: Widget, hasBorder: bool) =
  let state = dialog.getDialogState()
  state.hasBorder = hasBorder
  dialog.markDirty()

proc setCloseCallback*(dialog: Widget, callback: proc(dialog: Widget, result: DialogResult) {.closure.}) =
  let state = dialog.getDialogState()
  state.closeCallback = callback

proc getResult*(dialog: Widget): DialogResult =
  return dialog.getDialogState().result

proc close*(dialog: Widget, result: DialogResult) =
  let state = dialog.getDialogState()
  state.result = result
  
  # Call the close callback if it exists
  if state.closeCallback != nil:
    state.closeCallback(dialog, result)
  
  # Hide the dialog
  dialog.flags.excl(WidgetVisible)
  dialog.markDirty()

proc center*(dialog: Widget, parentWidth, parentHeight: int) =
  let rect = dialog.rect
  dialog.rect.x = max(0, (parentWidth - rect.width) div 2)
  dialog.rect.y = max(0, (parentHeight - rect.height) div 2)
  dialog.markDirty()

proc createButtons(dialog: Widget) =
  let state = dialog.getDialogState()
  
  # Remove existing button widgets
  for child in dialog.children:
    if child.id.startsWith("dialog_button_"):
      discard dialog.removeChild(child)
  
  # Create button widgets for each button in the state
  let buttonCount = state.buttons.len
  if buttonCount == 0:
    return
  
  let dialogWidth = dialog.rect.width
  let dialogHeight = dialog.rect.height
  
  # Calculate button positions
  let buttonY = dialogHeight - 3
  let buttonSpacing = 2
  let buttonWidth = 10
  
  # Calculate total width of all buttons
  let totalButtonWidth = buttonCount * buttonWidth + (buttonCount - 1) * buttonSpacing
  
  # Calculate starting X position for buttons
  var buttonX = max(2, (dialogWidth - totalButtonWidth) div 2)
  
  for i, buttonInfo in state.buttons:
    let id = "dialog_button_" & buttonInfo.id
    var button = newButton(id, buttonInfo.text)
    
    # Position the button
    button.rect.x = buttonX
    button.rect.y = buttonY
    button.rect.width = buttonWidth
    button.rect.height = 1
    
    # Set focus if it's the default button
    if buttonInfo.isDefault:
      button.flags.incl(WidgetFocused)
    
    # Set up button click handler
    let buttonResult = buttonInfo.result
    button.addEventHandler(WidgetClick, proc(widget: Widget, event: WidgetEvent): bool =
      dialog.close(buttonResult)
      return true
    )
    
    # Add button to dialog
    dialog.addChild(button)
    
    # Update X position for next button
    buttonX += buttonWidth + buttonSpacing

proc layoutDialog(dialog: Widget) =
  let state = dialog.getDialogState()
  
  # Create content label if needed
  if state.content.len > 0 and (state.contentWidget == nil or state.contentWidget.id != "dialog_content"):
    let contentLabel = newLabel("dialog_content", state.content)
    contentLabel.rect = Rect(x: 2, y: 2, width: dialog.rect.width - 4, height: dialog.rect.height - 7)
    # TODO: Implement word wrap for labels
    # contentLabel.setWordWrap(true)
    
    # Remove old content widget if it exists
    if state.contentWidget != nil:
      discard dialog.removeChild(state.contentWidget)
      
    dialog.addChild(contentLabel)
    state.contentWidget = contentLabel
  elif state.contentWidget != nil:
    # Update content widget position
    state.contentWidget.rect = Rect(x: 2, y: 2, width: dialog.rect.width - 4, height: dialog.rect.height - 7)
  
  # Create or update buttons
  createButtons(dialog)

proc renderDialog*(widget: Widget) =
  let state = widget.getDialogState()
  let rect = widget.rect
  
  # Ensure layout is up-to-date
  layoutDialog(widget)
  
  # Draw dialog background
  for y in 0..<rect.height:
    setCursor(rect.x, rect.y + y)
    
    var style = Style(fg: widget.style.fg, bg: widget.style.bg)
    setStyle(style)
    
    for x in 0..<rect.width:
      stdout.write(" ")
  
  # Draw border if enabled
  if state.hasBorder:
    # Draw border
    var borderStyle = Style(fg: widget.style.fg, bg: widget.style.bg)
    setStyle(borderStyle)
    
    # Draw top and bottom borders
    for x in 0..<rect.width:
      setCursor(rect.x + x, rect.y)
      stdout.write("─")
      setCursor(rect.x + x, rect.y + rect.height - 1)
      stdout.write("─")
    
    # Draw left and right borders
    for y in 0..<rect.height:
      setCursor(rect.x, rect.y + y)
      stdout.write("│")
      setCursor(rect.x + rect.width - 1, rect.y + y)
      stdout.write("│")
    
    # Draw corners
    setCursor(rect.x, rect.y)
    stdout.write("┌")
    setCursor(rect.x + rect.width - 1, rect.y)
    stdout.write("┐")
    setCursor(rect.x, rect.y + rect.height - 1)
    stdout.write("└")
    setCursor(rect.x + rect.width - 1, rect.y + rect.height - 1)
    stdout.write("┘")
    
    # Draw title if present
    if state.title.len > 0:
      setCursor(rect.x + 2, rect.y)
      stdout.write(" " & state.title & " ")
  
  # No need to render children here as the widget manager will do that

proc handleDialogKeyEvent*(widget: Widget, event: KeyEvent): bool =
  let state = widget.getDialogState()
  
  # Escape key closes the dialog with DialogCancel result
  if event.key == KeyEscape and state.buttonsType != DialogButtonsCustom:
    widget.close(DialogCancel)
    return true
  
  # Dialog itself doesn't handle other keys, but children might
  return false

proc handleDialogMouseEvent*(widget: Widget, event: MouseEvent): bool =
  # Dialog itself doesn't handle mouse events, but children might
  return false

# Register dialog widget handlers
proc registerDialogWidget*() =
  # TODO: Implement widget registration system
  # registerWidgetRenderer("dialog", renderDialog)
  # registerWidgetKeyHandler("dialog", handleDialogKeyEvent)
  # registerWidgetMouseHandler("dialog", handleDialogMouseEvent)
  discard

# Auto-register when module is imported
registerDialogWidget()