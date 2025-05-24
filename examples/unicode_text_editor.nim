# unicode_text_editor.nim
## Unicode-aware Simple Text Editor
## 
## A basic text editor that demonstrates proper Unicode handling in a real application.
## Features include:
## - Multi-script text editing with proper cursor positioning
## - Bidirectional text support
## - Unicode character width awareness
## - Syntax highlighting for common programming languages

import libterminal
import std/unicode
import std/strutils
import std/sequtils
import std/algorithm
import std/os
import std/times

type
  EditorMode = enum
    Normal, Insert
  
  SyntaxHighlight = enum
    None, Nim, Python, JavaScript, Markdown
  
  EditorState = object
    filename: string
    buffer: seq[string]  # Each line of text
    cursorX, cursorY: int  # Cursor position (logical position)
    visualX: int          # Visual cursor position (for display)
    offsetY: int          # Scroll offset
    mode: EditorMode
    modified: bool
    statusMessage: string
    statusTime: float
    highlight: SyntaxHighlight
    running: bool

# Helper functions for Unicode handling
# Use the imported functions from unicode_utils instead
proc visualPosToLogical(line: string, visualPos: int): int =
  ## Convert visual (displayed) position to logical (string index) position
  return unicode_utils.visualPosToLogical(line, visualPos)

# Use the imported functions from unicode_utils instead
proc logicalPosToVisual(line: string, logicalPos: int): int =
  ## Convert logical (string index) position to visual (displayed) position
  return unicode_utils.logicalPosToVisual(line, logicalPos)

proc calculateDisplayLine(line: string, startCol: int, width: int): string =
  ## Calculate the portion of line to display based on horizontal scroll
  if line.len == 0:
    return ""
  
  # Convert startCol from visual position to logical position
  let logicalStartPos = visualPosToLogical(line, startCol)
  
  # Get the substring starting from logical position
  let visibleText = line[logicalStartPos..<line.len]
  
  # Calculate display width of visible text
  let visibleWidth = displayWidth(visibleText)
  
  # If it fits within the display width, return it all
  if visibleWidth <= width:
    return visibleText
  
  # Otherwise, truncate based on visual width
  var result = ""
  var currentWidth = 0
  let clusters = unicode_utils.splitIntoGraphemeClusters(visibleText)
  
  for cluster in clusters:
    if currentWidth + cluster.width > width:
      break
    
    # Add all codepoints in this cluster
    for r in cluster.codePoints:
      result.add(toUTF8(r))
    
    currentWidth += cluster.width
  
  return result

# Syntax highlighting functions
proc getHighlightStyle(line: string, pos: int, highlight: SyntaxHighlight): Style =
  ## Get the highlighting style for a character based on syntax
  if highlight == None:
    return Style(fg: ColorDefault, bg: ColorDefault)
  
  # Default style
  result = Style(fg: ColorDefault, bg: ColorDefault)
  
  case highlight
  of Nim:
    # Keywords
    let nimKeywords = ["if", "else", "elif", "while", "for", "proc", "func", 
                       "method", "return", "var", "let", "const", "import", 
                       "from", "type", "object", "enum", "case", "of", "break",
                       "continue", "when", "discard", "yield", "template", "macro"]
    
    # Check if this position is part of a keyword
    for keyword in nimKeywords:
      if pos < line.len - keyword.len + 1:
        let endPos = pos + keyword.len
        if line[pos..<endPos] == keyword and 
           (pos == 0 or not line[pos-1].isAlphaNumeric) and
           (endPos >= line.len or not line[endPos].isAlphaNumeric):
          return Style(fg: ColorBlue, bg: ColorDefault, attrs: {AttrBold})
    
    # Comments
    if line.find('#', pos) == pos:
      return Style(fg: ColorGreen, bg: ColorDefault)
    
    # Strings
    if pos < line.len and (line[pos] == '"' or line[pos] == '\''):
      return Style(fg: ColorRed, bg: ColorDefault)
    
  of Python:
    # Keywords
    let pyKeywords = ["if", "else", "elif", "while", "for", "def", "class", 
                      "return", "import", "from", "as", "try", "except", 
                      "finally", "with", "break", "continue", "in", "is", 
                      "not", "and", "or", "True", "False", "None", "lambda"]
    
    # Check if this position is part of a keyword
    for keyword in pyKeywords:
      if pos < line.len - keyword.len + 1:
        let endPos = pos + keyword.len
        if line[pos..<endPos] == keyword and 
           (pos == 0 or not line[pos-1].isAlphaNumeric) and
           (endPos >= line.len or not line[endPos].isAlphaNumeric):
          return Style(fg: ColorBlue, bg: ColorDefault, attrs: {AttrBold})
    
    # Comments
    if line.find('#', pos) == pos:
      return Style(fg: ColorGreen, bg: ColorDefault)
    
    # Strings
    if pos < line.len and (line[pos] == '"' or line[pos] == '\''):
      return Style(fg: ColorRed, bg: ColorDefault)
    
  of JavaScript:
    # Keywords
    let jsKeywords = ["if", "else", "while", "for", "function", "return", 
                      "var", "let", "const", "class", "import", "export", 
                      "from", "as", "try", "catch", "finally", "throw", 
                      "break", "continue", "switch", "case", "default", 
                      "true", "false", "null", "undefined", "new", "this"]
    
    # Check if this position is part of a keyword
    for keyword in jsKeywords:
      if pos < line.len - keyword.len + 1:
        let endPos = pos + keyword.len
        if line[pos..<endPos] == keyword and 
           (pos == 0 or not line[pos-1].isAlphaNumeric) and
           (endPos >= line.len or not line[endPos].isAlphaNumeric):
          return Style(fg: ColorBlue, bg: ColorDefault, attrs: {AttrBold})
    
    # Comments
    if pos + 1 < line.len and line[pos..<pos+2] == "//":
      return Style(fg: ColorGreen, bg: ColorDefault)
    
    # Strings
    if pos < line.len and (line[pos] == '"' or line[pos] == '\'' or line[pos] == '`'):
      return Style(fg: ColorRed, bg: ColorDefault)
    
  of Markdown:
    # Headers
    if pos == 0 and line.startsWith('#'):
      let headerLevel = line.find(' ')
      if headerLevel > 0 and headerLevel <= 6:
        return Style(fg: ColorMagenta, bg: ColorDefault, attrs: {AttrBold})
    
    # Bold
    if pos + 1 < line.len and line[pos..<pos+2] == "**":
      return Style(fg: ColorDefault, bg: ColorDefault, attrs: {AttrBold})
    
    # Italic
    if pos < line.len and line[pos] == '*':
      return Style(fg: ColorDefault, bg: ColorDefault, attrs: {AttrItalic})
    
    # Links
    if pos < line.len and line[pos] == '[' or line[pos] == ']' or 
       line[pos] == '(' or line[pos] == ')':
      return Style(fg: ColorBlue, bg: ColorDefault)
    
    # Code blocks
    if pos < line.len and line[pos] == '`':
      return Style(fg: ColorCyan, bg: ColorDefault)
    
  else:
    discard
  
  return result

proc detectHighlight(filename: string): SyntaxHighlight =
  ## Detect syntax highlighting based on filename extension
  let ext = splitFile(filename).ext.toLowerAscii()
  
  case ext
  of ".nim":
    return Nim
  of ".py", ".pyw":
    return Python
  of ".js", ".ts", ".jsx", ".tsx":
    return JavaScript
  of ".md", ".markdown":
    return Markdown
  else:
    return None

# File operations
proc loadFile(state: var EditorState, filename: string) =
  if not fileExists(filename):
    state.buffer = @[""]
    state.filename = filename
    state.modified = false
    state.statusMessage = "New file"
    state.statusTime = epochTime()
    return
  
  try:
    state.buffer = readFile(filename).splitLines()
    # Ensure there's at least one line
    if state.buffer.len == 0:
      state.buffer = @[""]
    
    state.filename = filename
    state.modified = false
    state.highlight = detectHighlight(filename)
    state.statusMessage = "Loaded " & filename
    state.statusTime = epochTime()
  except:
    state.statusMessage = "Error: Could not load " & filename
    state.statusTime = epochTime()

proc saveFile(state: var EditorState) =
  if state.filename == "":
    state.statusMessage = "Error: No filename specified"
    state.statusTime = epochTime()
    return
  
  try:
    writeFile(state.filename, state.buffer.join("\n"))
    state.modified = false
    state.statusMessage = "Saved " & state.filename
    state.statusTime = epochTime()
  except:
    state.statusMessage = "Error: Could not save " & state.filename
    state.statusTime = epochTime()

# Editor operations
proc moveCursor(state: var EditorState, dx, dy: int) =
  # Update cursor position
  state.cursorY = max(0, min(state.buffer.high, state.cursorY + dy))
  
  # Get the current line
  let line = if state.cursorY < state.buffer.len: state.buffer[state.cursorY] else: ""
  
  if dx != 0:
    # Convert current visual position to logical position
    let oldLogicalPos = visualPosToLogical(line, state.visualX)
    
    # Update visual position
    state.visualX = max(0, state.visualX + dx)
    
    # Convert new visual position to logical position
    state.cursorX = visualPosToLogical(line, state.visualX)
  else:
    # Just moving vertically, maintain visual position if possible
    state.cursorX = visualPosToLogical(line, state.visualX)

proc insertCharacter(state: var EditorState, ch: char) =
  # Ensure we have enough lines
  while state.cursorY >= state.buffer.len:
    state.buffer.add("")
  
  # Get current line
  var line = state.buffer[state.cursorY]
  
  # Insert character at cursor position
  if state.cursorX > line.len:
    line.add(' '.repeat(state.cursorX - line.len))
    line.add(ch)
  else:
    line.insert($ch, state.cursorX)
  
  # Update the line in buffer
  state.buffer[state.cursorY] = line
  
  # Move cursor forward
  state.cursorX += 1
  state.visualX = logicalPosToVisual(line, state.cursorX)
  
  state.modified = true

proc insertNewline(state: var EditorState) =
  # Ensure we have enough lines
  while state.cursorY >= state.buffer.len:
    state.buffer.add("")
  
  # Get current line
  let line = state.buffer[state.cursorY]
  
  # Split line at cursor
  let beforeCursor = if state.cursorX <= line.len: line[0..<state.cursorX] else: line
  let afterCursor = if state.cursorX < line.len: line[state.cursorX..^1] else: ""
  
  # Update current line and insert new line
  state.buffer[state.cursorY] = beforeCursor
  state.buffer.insert(afterCursor, state.cursorY + 1)
  
  # Move cursor to beginning of new line
  state.cursorY += 1
  state.cursorX = 0
  state.visualX = 0
  
  state.modified = true

proc deleteCharacter(state: var EditorState, backspace: bool = false) =
  # Ensure we have enough lines
  while state.cursorY >= state.buffer.len:
    state.buffer.add("")
  
  # Get current line
  var line = state.buffer[state.cursorY]
  
  if backspace:
    # Backspace: delete character before cursor
    if state.cursorX > 0:
      # If we're in a multibyte character, we need special handling
      let prevCharLen = 
        if state.cursorX >= 4: 
          min(4, state.cursorX - visualPosToLogical(line, state.visualX - 1))
        else:
          1
      
      line.delete(state.cursorX - prevCharLen, state.cursorX - 1)
      state.buffer[state.cursorY] = line
      state.cursorX -= prevCharLen
      state.visualX = logicalPosToVisual(line, state.cursorX)
      state.modified = true
    elif state.cursorY > 0:
      # At beginning of line, join with previous line
      let previousLine = state.buffer[state.cursorY - 1]
      state.cursorX = previousLine.len
      state.buffer[state.cursorY - 1] = previousLine & line
      state.buffer.delete(state.cursorY)
      state.cursorY -= 1
      state.visualX = logicalPosToVisual(state.buffer[state.cursorY], state.cursorX)
      state.modified = true
  else:
    # Delete: delete character at cursor
    if state.cursorX < line.len:
      # Get the byte length of the character at cursor
      let charLen = 
        if state.cursorX + 4 <= line.len:
          min(4, visualPosToLogical(line, state.visualX + 1) - state.cursorX)
        else:
          1
      
      line.delete(state.cursorX, state.cursorX + charLen - 1)
      state.buffer[state.cursorY] = line
      state.modified = true
    elif state.cursorY < state.buffer.high:
      # At end of line, join with next line
      state.buffer[state.cursorY] = line & state.buffer[state.cursorY + 1]
      state.buffer.delete(state.cursorY + 1)
      state.modified = true

# Drawing functions
proc drawEditor(buffer: var Buffer, state: EditorState) =
  # Clear the screen
  buffer.clear()
  
  # Calculate visible area
  let editorHeight = buffer.height - 2  # Reserve bottom lines for status
  
  # Adjust offset if needed to keep cursor in view
  var offset = state.offsetY
  if state.cursorY < offset:
    offset = state.cursorY
  if state.cursorY >= offset + editorHeight:
    offset = state.cursorY - editorHeight + 1
  
  # Draw visible lines
  for y in 0..<editorHeight:
    let fileY = y + offset
    
    if fileY < state.buffer.len:
      # Draw line numbers
      let lineNumStyle = Style(fg: ColorYellow, bg: ColorDefault)
      let lineNum = fmt"{fileY + 1:4} "
      buffer.print(0, y, lineNum, lineNumStyle)
      
      # Draw text with Unicode-aware display
      let line = state.buffer[fileY]
      let displayText = calculateDisplayLine(line, 0, buffer.width - 6)
      
      # Syntax highlighting
      if state.highlight != None:
        # Draw character by character with highlighting
        var x = 6
        var bytePos = 0
        
        let clusters = unicode_utils.splitIntoGraphemeClusters(displayText)
        for cluster in clusters:
          if bytePos < displayText.len:
            let style = getHighlightStyle(displayText, bytePos, state.highlight)
            
            # Combine all codepoints in this cluster
            var clusterStr = ""
            for r in cluster.codePoints:
              clusterStr.add(toUTF8(r))
            
            buffer.printAdvanced(x, y, clusterStr, style)
            x += cluster.width
            bytePos += clusterStr.len
      else:
        # Regular text without highlighting
        buffer.printAdvanced(6, y, displayText, Style())
    else:
      # Draw tilde for lines beyond file end
      buffer.print(0, y, "~", Style(fg: ColorBlue))
  
  # Draw status line
  let statusBg = Style(fg: ColorBlack, bg: ColorWhite)
  let statusText = " " & state.filename & 
                   (if state.modified: " [modified]" else: "") &
                   " | " & $state.buffer.len & " lines | " &
                   "Mode: " & (if state.mode == Normal: "Normal" else: "Insert") &
                   " | Highlight: " & $state.highlight
  
  let padding = " ".repeat(max(0, buffer.width - displayWidth(statusText)))
  buffer.print(0, buffer.height - 2, statusText & padding, statusBg)
  
  # Draw message line
  let msgStyle = Style(fg: ColorYellow, bg: ColorDefault)
  if state.statusMessage != "" and epochTime() - state.statusTime < 5.0:
    buffer.print(0, buffer.height - 1, state.statusMessage, msgStyle)
  else:
    let helpText = " Ctrl+S: Save | Ctrl+Q: Quit | ESC: Normal Mode | i: Insert Mode "
    buffer.print(0, buffer.height - 1, helpText, Style(fg: ColorGreen))
  
  # Draw cursor
  if state.mode == Insert:
    # In insert mode, show a blinking cursor
    let cursorY = state.cursorY - offset
    if cursorY >= 0 and cursorY < editorHeight:
      let line = state.buffer[state.cursorY]
      let cursorVisualX = logicalPosToVisual(line, state.cursorX)
      setCursor(6 + cursorVisualX, cursorY)
      showCursor()
  else:
    # In normal mode, highlight the current character
    let cursorY = state.cursorY - offset
    if cursorY >= 0 and cursorY < editorHeight:
      let line = state.buffer[state.cursorY]
      let cursorVisualX = logicalPosToVisual(line, state.cursorX)
      
      if state.cursorX < line.len:
        # Get the character at cursor
        let charPos = state.cursorX
        let charWidth = min(1, displayWidth(line[charPos..charPos]))
        
        # Highlight it with inverted colors
        let invertStyle = Style(fg: ColorBlack, bg: ColorWhite)
        let charToHighlight = if charPos < line.len: $line[charPos] else: " "
        buffer.print(6 + cursorVisualX, cursorY, charToHighlight, invertStyle)
      else:
        # Cursor is at end of line, show a block
        buffer.print(6 + cursorVisualX, cursorY, " ", Style(fg: ColorBlack, bg: ColorWhite))
      
      hideCursor()

# Main editor loop
proc runEditor(filename: string = "") =
  withTerminal:
    # Get terminal size
    let (width, height) = raw.getTerminalSize()
    
    # Create terminal buffer
    var buffer = newBuffer(width, height)
    
    # Initialize editor state
    var state = EditorState(
      cursorX: 0,
      cursorY: 0,
      visualX: 0,
      offsetY: 0,
      mode: Normal,
      modified: false,
      running: true
    )
    
    # Load file if specified
    if filename != "":
      loadFile(state, filename)
    else:
      state.buffer = @[""]
      state.statusMessage = "New file. Ctrl+S to save."
      state.statusTime = epochTime()
    
    # Main editor loop
    while state.running:
      # Draw the editor
      drawEditor(buffer, state)
      drawBuffer(buffer)
      
      # Handle input
      let event = input.pollEvent()
      
      if event.kind == KeyPress:
        if event.key == KeyCtrlQ:
          if not state.modified or 
            (state.modified and state.statusMessage == "Press Ctrl+Q again to quit without saving"):
            state.running = false
          else:
            state.statusMessage = "Press Ctrl+Q again to quit without saving"
            state.statusTime = epochTime()
        elif event.key == KeyCtrlS:
          if state.filename == "":
            state.statusMessage = "Enter filename to save:"
            state.statusTime = epochTime()
            
            # Simple input for filename
            var filename = ""
            var gettingFilename = true
            
            while gettingFilename:
              # Display current filename input
              buffer.print(0, buffer.height - 1, "Save as: " & filename & "_ ", Style(fg: ColorWhite))
              drawBuffer(buffer)
              
              let filenameEvent = input.pollEvent()
              if filenameEvent.kind == KeyPress:
                if filenameEvent.key == KeyReturn and filename != "":
                  gettingFilename = false
                  state.filename = filename
                elif filenameEvent.key == KeyEscape:
                  gettingFilename = false
                  state.statusMessage = "Save aborted"
                  state.statusTime = epochTime()
                elif filenameEvent.key == KeyBackspace and filename.len > 0:
                  filename.setLen(filename.len - 1)
                elif filenameEvent.ch >= ' ' and filenameEvent.ch <= '~':
                  filename.add(filenameEvent.ch)
            
            if state.filename != "":
              saveFile(state)
          else:
            saveFile(state)
        
        elif state.mode == Normal:
          # Normal mode key handling
          case event.key
          of KeyI:
            state.mode = Insert
            state.statusMessage = "-- INSERT MODE --"
            state.statusTime = epochTime()
          of KeyH, KeyLeft:
            moveCursor(state, -1, 0)
          of KeyJ, KeyDown:
            moveCursor(state, 0, 1)
          of KeyK, KeyUp:
            moveCursor(state, 0, -1)
          of KeyL, KeyRight:
            moveCursor(state, 1, 0)
          of KeyX:
            deleteCharacter(state, false)
          of KeyD:
            # Simple delete line
            if state.buffer.len > 1:
              state.buffer.delete(state.cursorY)
              if state.cursorY >= state.buffer.len:
                state.cursorY = state.buffer.len - 1
              state.cursorX = 0
              state.visualX = 0
              state.modified = true
          of KeyY:
            # Add simple highlight cycling
            let highlights = [None, Nim, Python, JavaScript, Markdown]
            let currentIdx = highlights.find(state.highlight)
            state.highlight = highlights[(currentIdx + 1) mod highlights.len]
            state.statusMessage = "Highlight: " & $state.highlight
            state.statusTime = epochTime()
          else:
            discard
            
        elif state.mode == Insert:
          # Insert mode key handling
          case event.key
          of KeyEscape:
            state.mode = Normal
            state.statusMessage = "-- NORMAL MODE --"
            state.statusTime = epochTime()
          of KeyBackspace:
            deleteCharacter(state, true)
          of KeyDelete:
            deleteCharacter(state, false)
          of KeyReturn:
            insertNewline(state)
          of KeyUp:
            moveCursor(state, 0, -1)
          of KeyDown:
            moveCursor(state, 0, 1)
          of KeyLeft:
            moveCursor(state, -1, 0)
          of KeyRight:
            moveCursor(state, 1, 0)
          of KeyHome:
            state.cursorX = 0
            state.visualX = 0
          of KeyEnd:
            let line = state.buffer[state.cursorY]
            state.cursorX = line.len
            state.visualX = displayWidth(line)
          else:
            if event.ch != '\0':
              insertCharacter(state, event.ch)
      
      # Handle window resizing
      if buffer.width != width or buffer.height != height:
        buffer.resize(width, height)

proc main() =
  var filename = ""
  if paramCount() > 0:
    filename = paramStr(1)
  
  runEditor(filename)

when isMainModule:
  main()