## Agent-Specific Widgets
## 
## Widgets designed for agent interaction and display

import std/[asyncdispatch, json, strutils, sequtils, tables, times, unicode, terminal]
import ../widgets
import ../widget_base
import ../input
import ../output
import ../private/common
import agent_base

type
  AgentChatWidget* = ref object of Widget
    ## Chat widget for agent conversation
    messages*: seq[AgentMessage]
    inputBuffer*: string
    scrollOffset*: int
    maxMessages*: int
    showTimestamps*: bool

  AgentStatusWidget* = ref object of Widget
    ## Status widget showing agent activity
    status*: string
    activity*: string
    lastUpdate*: DateTime
    showIcon*: bool

  CommandPaletteWidget* = ref object of Widget
    ## Command palette for agent commands
    suggestions*: seq[string]
    currentInput*: string
    selectedIndex*: int
    visible*: bool

  AgentResponseWidget* = ref object of Widget
    ## Widget for displaying agent responses with formatting
    content*: string
    formatting*: Table[string, string]  # Format hints
    scrollOffset*: int
    wordWrap*: bool

# AgentChatWidget implementation

proc newAgentChatWidget*(x, y, width, height: int): AgentChatWidget =
  ## Creates a new agent chat widget
  result = AgentChatWidget()
  result.initWidget("agent_chat", x, y, width, height)
  result.messages = @[]
  result.inputBuffer = ""
  result.scrollOffset = 0
  result.maxMessages = 100
  result.showTimestamps = false

proc addMessage*(widget: AgentChatWidget, message: AgentMessage) =
  ## Adds a message to the chat
  widget.messages.add(message)
  
  # Trim old messages if necessary
  if widget.messages.len > widget.maxMessages:
    widget.messages = widget.messages[^widget.maxMessages..^1]
  
  # Auto-scroll to bottom
  widget.scrollOffset = max(0, widget.messages.len - widget.rect.height + 2)

proc clearMessages*(widget: AgentChatWidget) =
  ## Clears all messages
  widget.messages = @[]
  widget.scrollOffset = 0

proc scrollUp*(widget: AgentChatWidget) =
  ## Scrolls the chat up
  if widget.scrollOffset > 0:
    dec widget.scrollOffset

proc scrollDown*(widget: AgentChatWidget) =
  ## Scrolls the chat down
  let maxScroll = max(0, widget.messages.len - widget.rect.height + 2)
  if widget.scrollOffset < maxScroll:
    inc widget.scrollOffset

method render*(widget: AgentChatWidget) =
  ## Renders the chat widget
  # Clear the widget area
  for i in 0..<widget.rect.height:
    setCursorPos(widget.rect.x, widget.rect.y + i)
    stdout.write(" ".repeat(widget.rect.width))
  
  # Render messages
  let startIdx = widget.scrollOffset
  let endIdx = min(widget.messages.len, startIdx + widget.rect.height - 1)
  
  for i in startIdx..<endIdx:
    let message = widget.messages[i]
    let line = widget.rect.y + (i - startIdx)
    
    setCursorPos(widget.rect.x, line)
    
    var prefix = ""
    case message.role:
    of "user":
      prefix = "› "
    of "assistant":
      prefix = "🤖 "
    of "system":
      prefix = "⚙ "
    else:
      prefix = "• "
    
    let content = prefix & message.content
    let truncated = if content.len > widget.rect.width: content[0..<widget.rect.width-3] & "..." else: content
    
    # Color coding by role
    case message.role:
    of "user":
      stdout.styledWrite(fgCyan, truncated)
    of "assistant":
      stdout.styledWrite(fgGreen, truncated)
    of "system":
      stdout.styledWrite(fgYellow, truncated)
    else:
      stdout.write(truncated)
  
  # Render input buffer at bottom
  if widget.rect.height > 0:
    setCursorPos(widget.rect.x, widget.rect.y + widget.rect.height - 1)
    let prompt = "» " & widget.inputBuffer
    let truncated = if prompt.len > widget.rect.width: prompt[0..<widget.rect.width] else: prompt
    stdout.styledWrite(fgWhite, truncated)

method handleEvent*(widget: AgentChatWidget, event: WidgetEvent): bool =
  ## Handles events for the chat widget
  case event.kind:
  of WidgetKeyDown:
    case event.key.key:
    of KeyUp:
      widget.scrollUp()
      return true
    of KeyDown:
      widget.scrollDown()
      return true
    of KeyEnter:
      if widget.inputBuffer.len > 0:
        let userMessage = AgentMessage(
          role: "user",
          content: widget.inputBuffer,
          metadata: newJObject()
        )
        widget.addMessage(userMessage)
        widget.inputBuffer = ""
        # TODO: Implement proper event propagation for custom events
        return true
    of KeyBackspace:
      if widget.inputBuffer.len > 0:
        widget.inputBuffer = widget.inputBuffer[0..<widget.inputBuffer.len-1]
        return true
    else:
      discard
  of WidgetChar:
    # Handle printable characters
    widget.inputBuffer.add(event.ch)
    return true
  else:
    discard
  
  return false

# AgentStatusWidget implementation

proc newAgentStatusWidget*(x, y, width, height: int): AgentStatusWidget =
  ## Creates a new agent status widget
  result = AgentStatusWidget()
  result.initWidget("agent_status", x, y, width, height)
  result.status = "Ready"
  result.activity = ""
  result.lastUpdate = now()
  result.showIcon = true

proc setStatus*(widget: AgentStatusWidget, status: string, activity: string = "") =
  ## Updates the status
  widget.status = status
  widget.activity = activity
  widget.lastUpdate = now()

method render*(widget: AgentStatusWidget) =
  ## Renders the status widget
  setCursorPos(widget.rect.x, widget.rect.y)
  
  var statusText = ""
  if widget.showIcon:
    case widget.status:
    of "Ready":
      statusText = "🟢 Ready"
    of "Processing":
      statusText = "🟡 Processing"
    of "Error":
      statusText = "🔴 Error"
    else:
      statusText = "⚪ " & widget.status
  else:
    statusText = widget.status
  
  if widget.activity.len > 0:
    statusText.add(" - " & widget.activity)
  
  let truncated = if statusText.len > widget.rect.width: statusText[0..<widget.rect.width] else: statusText
  stdout.write(truncated)

# CommandPaletteWidget implementation

proc newCommandPaletteWidget*(x, y, width, height: int): CommandPaletteWidget =
  ## Creates a new command palette widget
  result = CommandPaletteWidget()
  result.initWidget("command_palette", x, y, width, height)
  result.suggestions = @[]
  result.currentInput = ""
  result.selectedIndex = 0
  result.visible = false

proc show*(widget: CommandPaletteWidget, suggestions: seq[string] = @[]) =
  ## Shows the command palette
  widget.visible = true
  widget.suggestions = suggestions
  widget.currentInput = ""
  widget.selectedIndex = 0

proc hide*(widget: CommandPaletteWidget) =
  ## Hides the command palette
  widget.visible = false

proc updateSuggestions*(widget: CommandPaletteWidget, input: string, suggestions: seq[string]) =
  ## Updates suggestions based on input
  widget.currentInput = input
  widget.suggestions = suggestions
  widget.selectedIndex = 0

method render*(widget: CommandPaletteWidget) =
  ## Renders the command palette
  if not widget.visible:
    return
  
  # Clear widget area
  for i in 0..<widget.rect.height:
    setCursorPos(widget.rect.x, widget.rect.y + i)
    stdout.write(" ".repeat(widget.rect.width))
  
  # Render input line
  setCursorPos(widget.rect.x, widget.rect.y)
  let prompt = "Command: " & widget.currentInput
  stdout.styledWrite(fgCyan, prompt)
  
  # Render suggestions
  let maxSuggestions = min(widget.suggestions.len, widget.rect.height - 1)
  for i in 0..<maxSuggestions:
    setCursorPos(widget.rect.x, widget.rect.y + 1 + i)
    let suggestion = widget.suggestions[i]
    if i == widget.selectedIndex:
      stdout.styledWrite(fgYellow, "► " & suggestion)
    else:
      stdout.write("  " & suggestion)

method handleEvent*(widget: CommandPaletteWidget, event: WidgetEvent): bool =
  ## Handles events for the command palette
  if not widget.visible:
    return false
  
  case event.kind:
  of WidgetKeyDown:
    case event.key.key:
    of KeyUp:
      if widget.selectedIndex > 0:
        dec widget.selectedIndex
      return true
    of KeyDown:
      if widget.selectedIndex < widget.suggestions.len - 1:
        inc widget.selectedIndex
      return true
    of KeyEnter:
      if widget.selectedIndex < widget.suggestions.len:
        # Just hide for now - caller should check selected command
        widget.hide()
      return true
    of KeyEscape:
      widget.hide()
      return true
    of KeyBackspace:
      if widget.currentInput.len > 0:
        widget.currentInput = widget.currentInput[0..<widget.currentInput.len-1]
      return true
    else:
      discard
  of WidgetChar:
    # Handle printable characters
    widget.currentInput.add(event.ch)
    return true
  else:
    discard
  
  return false

# AgentResponseWidget implementation

proc newAgentResponseWidget*(x, y, width, height: int): AgentResponseWidget =
  ## Creates a new agent response widget
  result = AgentResponseWidget()
  result.initWidget("agent_response", x, y, width, height)
  result.content = ""
  result.formatting = initTable[string, string]()
  result.scrollOffset = 0
  result.wordWrap = true

proc setContent*(widget: AgentResponseWidget, content: string, formatting: Table[string, string] = initTable[string, string]()) =
  ## Sets the content of the response widget
  widget.content = content
  widget.formatting = formatting
  widget.scrollOffset = 0

method render*(widget: AgentResponseWidget) =
  ## Renders the response widget
  # Clear widget area
  for i in 0..<widget.rect.height:
    setCursorPos(widget.rect.x, widget.rect.y + i)
    stdout.write(" ".repeat(widget.rect.width))
  
  # Split content into lines
  var lines: seq[string] = @[]
  if widget.wordWrap:
    for line in widget.content.splitLines():
      if line.len <= widget.rect.width:
        lines.add(line)
      else:
        # Simple word wrapping
        var remaining = line
        while remaining.len > widget.rect.width:
          let breakPoint = min(widget.rect.width, remaining.len)
          lines.add(remaining[0..<breakPoint])
          remaining = remaining[breakPoint..^1]
        if remaining.len > 0:
          lines.add(remaining)
  else:
    lines = widget.content.splitLines()
  
  # Render visible lines
  let startIdx = widget.scrollOffset
  let endIdx = min(lines.len, startIdx + widget.rect.height)
  
  for i in startIdx..<endIdx:
    setCursorPos(widget.rect.x, widget.rect.y + (i - startIdx))
    let line = lines[i]
    let truncated = if line.len > widget.rect.width: line[0..<widget.rect.width] else: line
    
    # Apply formatting if available
    if "color" in widget.formatting:
      let color = widget.formatting["color"]
      case color:
      of "green":
        stdout.styledWrite(fgGreen, truncated)
      of "red":
        stdout.styledWrite(fgRed, truncated)
      of "yellow":
        stdout.styledWrite(fgYellow, truncated)
      of "cyan":
        stdout.styledWrite(fgCyan, truncated)
      else:
        stdout.write(truncated)
    else:
      stdout.write(truncated)

method handleEvent*(widget: AgentResponseWidget, event: WidgetEvent): bool =
  ## Handles events for the response widget
  case event.kind:
  of WidgetKeyDown:
    case event.key.key:
    of KeyUp:
      if widget.scrollOffset > 0:
        dec widget.scrollOffset
      return true
    of KeyDown:
      let maxScroll = max(0, widget.content.splitLines().len - widget.rect.height)
      if widget.scrollOffset < maxScroll:
        inc widget.scrollOffset
      return true
    else:
      discard
  else:
    discard
  
  return false