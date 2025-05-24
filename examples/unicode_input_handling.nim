# unicode_input_handling.nim
## Unicode-aware Input Handling
##
## This example demonstrates advanced Unicode input handling in terminal applications,
## including proper cursor navigation, text selection, editing operations,
## and input method support for international languages.

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/times
import std/algorithm
import std/sequtils

type
  CursorDirection = enum
    Left, Right, Up, Down, Home, End, PageUp, PageDown
    
  SelectionMode = enum
    None, Character, Word, Line
    
  TextBuffer = object
    lines: seq[string]
    cursorX: int      # Visual cursor X position (in columns)
    cursorY: int      # Cursor Y position (in lines)
    selectionStart: tuple[x, y: int]  # Selection start coordinates (visual)
    selectionEnd: tuple[x, y: int]    # Selection end coordinates (visual)
    selectionMode: SelectionMode
    logicalCursorPos: int  # Byte position in current line
    visibleAreaStart: int  # First visible line
    visibleAreaHeight: int # Number of visible lines
    
  InputState = enum
    Normal,   # Regular input
    Compose,  # Composing multi-key sequence (e.g., ` + e → è)
    IME       # Input Method Editor mode (e.g., pinyin, hangul)
    
  InputHandler = object
    buffer: TextBuffer
    inputState: InputState
    composeSequence: string
    imeBuffer: string
    imePopupItems: seq[string]
    imeSelectedIndex: int
    undoStack: seq[TextBuffer]
    redoStack: seq[TextBuffer]
    maxUndoLevels: int
    clipboard: string
    lastModified: float

# Initialize a new text buffer
proc newTextBuffer(): TextBuffer =
  result.lines = @[""]
  result.cursorX = 0
  result.cursorY = 0
  result.selectionStart = (0, 0)
  result.selectionEnd = (0, 0)
  result.selectionMode = None
  result.logicalCursorPos = 0
  result.visibleAreaStart = 0
  result.visibleAreaHeight = 20

# Initialize a new input handler
proc newInputHandler(): InputHandler =
  result.buffer = newTextBuffer()
  result.inputState = Normal
  result.composeSequence = ""
  result.imeBuffer = ""
  result.imePopupItems = @[]
  result.imeSelectedIndex = -1
  result.undoStack = @[]
  result.redoStack = @[]
  result.maxUndoLevels = 100
  result.clipboard = ""
  result.lastModified = epochTime()

# Push current buffer state to undo stack
proc pushUndo(handler: var InputHandler) =
  # Don't push if nothing changed
  if handler.undoStack.len > 0 and 
     handler.undoStack[^1].lines == handler.buffer.lines:
    return
  
  # Create a deep copy of current buffer
  var bufferCopy = handler.buffer
  bufferCopy.lines = @[]
  for line in handler.buffer.lines:
    bufferCopy.lines.add(line)
  
  # Push to undo stack
  handler.undoStack.add(bufferCopy)
  
  # Limit stack size
  if handler.undoStack.len > handler.maxUndoLevels:
    handler.undoStack.delete(0)
  
  # Clear redo stack on new changes
  handler.redoStack = @[]
  
  # Update modification time
  handler.lastModified = epochTime()

# Convert logical (byte) position to visual position
proc logicalToVisual(line: string, logicalPos: int): int =
  if logicalPos <= 0:
    return 0
  
  let beforeCursor = line[0..<logicalPos]
  return displayWidth(beforeCursor)

# Convert visual position to logical (byte) position
proc visualToLogical(line: string, visualPos: int): int =
  if visualPos <= 0:
    return 0
  
  let clusters = unicode_utils.splitIntoGraphemeClusters(line)
  var currentVisual = 0
  var currentLogical = 0
  
  for cluster in clusters:
    if currentVisual >= visualPos:
      return currentLogical
    
    currentVisual += cluster.width
    
    # Add byte length for all code points in this cluster
    for r in cluster.codePoints:
      currentLogical += toUTF8(r).len
  
  return line.len

# Get visual width of a text selection
proc getSelectionWidth(line: string, startPos, endPos: int): int =
  if startPos >= endPos:
    return 0
  
  let selText = line[startPos..<endPos]
  return displayWidth(selText)

# Update cursor position based on logical position
proc updateCursorFromLogical(buffer: var TextBuffer) =
  if buffer.cursorY >= buffer.lines.len:
    buffer.cursorY = max(0, buffer.lines.len - 1)
  
  let line = buffer.lines[buffer.cursorY]
  buffer.cursorX = logicalToVisual(line, buffer.logicalCursorPos)

# Move cursor to a new position
proc moveCursor(buffer: var TextBuffer, direction: CursorDirection, wordMode: bool = false) =
  let line = if buffer.cursorY < buffer.lines.len: buffer.lines[buffer.cursorY] else: ""
  
  case direction:
    of Left:
      if wordMode:
        # Move to start of previous word
        var pos = buffer.logicalCursorPos
        let runes = line.toRunes
        var foundNonSpace = false
        
        while pos > 0:
          pos -= 1
          if pos < runes.len:
            if not foundNonSpace and not runes[pos].isWhitespace:
              foundNonSpace = true
            elif foundNonSpace and runes[pos].isWhitespace:
              pos += 1
              break
        
        buffer.logicalCursorPos = pos
      else:
        # Move left by one grapheme cluster
        let clusters = unicode_utils.splitIntoGraphemeClusters(line)
        var pos = 0
        var prevPos = 0
        
        for cluster in clusters:
          let nextPos = pos + cluster.codePoints.foldl(a + toUTF8(b).len, 0)
          if nextPos >= buffer.logicalCursorPos and pos < buffer.logicalCursorPos:
            buffer.logicalCursorPos = pos
            break
          prevPos = pos
          pos = nextPos
        
        if buffer.logicalCursorPos > 0 and pos < buffer.logicalCursorPos:
          buffer.logicalCursorPos = prevPos
      
      # If at beginning of line, move to end of previous line
      if buffer.logicalCursorPos == 0 and buffer.cursorY > 0:
        buffer.cursorY -= 1
        let prevLine = buffer.lines[buffer.cursorY]
        buffer.logicalCursorPos = prevLine.len
      
    of Right:
      if wordMode:
        # Move to start of next word
        var pos = buffer.logicalCursorPos
        let runes = line.toRunes
        
        # Skip current word if we're in the middle of one
        var inWord = false
        if pos < runes.len and not runes[pos].isWhitespace:
          inWord = true
          
        while pos < runes.len:
          if inWord and runes[pos].isWhitespace:
            inWord = false
          elif not inWord and not runes[pos].isWhitespace:
            break
          pos += 1
        
        buffer.logicalCursorPos = pos
      else:
        # Move right by one grapheme cluster
        let clusters = unicode_utils.splitIntoGraphemeClusters(line)
        var pos = 0
        
        for cluster in clusters:
          let clusterLen = cluster.codePoints.foldl(a + toUTF8(b).len, 0)
          let nextPos = pos + clusterLen
          
          if pos == buffer.logicalCursorPos:
            buffer.logicalCursorPos = nextPos
            break
          
          pos = nextPos
      
      # If at end of line, move to beginning of next line
      if buffer.logicalCursorPos >= line.len and buffer.cursorY < buffer.lines.high:
        buffer.cursorY += 1
        buffer.logicalCursorPos = 0
        
    of Up:
      if buffer.cursorY > 0:
        buffer.cursorY -= 1
        let newLine = buffer.lines[buffer.cursorY]
        buffer.logicalCursorPos = visualToLogical(newLine, buffer.cursorX)
        
    of Down:
      if buffer.cursorY < buffer.lines.high:
        buffer.cursorY += 1
        let newLine = buffer.lines[buffer.cursorY]
        buffer.logicalCursorPos = visualToLogical(newLine, buffer.cursorX)
        
    of Home:
      buffer.logicalCursorPos = 0
      
    of End:
      buffer.logicalCursorPos = line.len
      
    of PageUp:
      buffer.cursorY = max(0, buffer.cursorY - 10)
      let newLine = buffer.lines[buffer.cursorY]
      buffer.logicalCursorPos = visualToLogical(newLine, buffer.cursorX)
      
    of PageDown:
      buffer.cursorY = min(buffer.lines.high, buffer.cursorY + 10)
      let newLine = buffer.lines[buffer.cursorY]
      buffer.logicalCursorPos = visualToLogical(newLine, buffer.cursorX)
  
  # Update visual cursor position
  buffer.updateCursorFromLogical()

# Start a text selection
proc startSelection(buffer: var TextBuffer, mode: SelectionMode = Character) =
  buffer.selectionMode = mode
  buffer.selectionStart = (buffer.cursorX, buffer.cursorY)
  buffer.selectionEnd = (buffer.cursorX, buffer.cursorY)

# Update text selection based on current cursor position
proc updateSelection(buffer: var TextBuffer) =
  if buffer.selectionMode != None:
    buffer.selectionEnd = (buffer.cursorX, buffer.cursorY)

# Get selected text
proc getSelectedText(buffer: TextBuffer): string =
  if buffer.selectionMode == None:
    return ""
  
  var startX = buffer.selectionStart.x
  var startY = buffer.selectionStart.y
  var endX = buffer.selectionEnd.x
  var endY = buffer.selectionEnd.y
  
  # Ensure start is before end
  if startY > endY or (startY == endY and startX > endX):
    swap(startX, endX)
    swap(startY, endY)
  
  var result = ""
  
  # Selection on single line
  if startY == endY:
    let line = buffer.lines[startY]
    let startPos = visualToLogical(line, startX)
    let endPos = visualToLogical(line, endX)
    result = line[startPos..<endPos]
  else:
    # Multi-line selection
    # First line - partial
    let firstLine = buffer.lines[startY]
    let startPos = visualToLogical(firstLine, startX)
    result.add(firstLine[startPos..^1])
    result.add("\n")
    
    # Middle lines - whole lines
    for y in startY+1..<endY:
      result.add(buffer.lines[y])
      result.add("\n")
    
    # Last line - partial
    let lastLine = buffer.lines[endY]
    let endPos = visualToLogical(lastLine, endX)
    result.add(lastLine[0..<endPos])
  
  return result

# Handle typing a character
proc typeCharacter(handler: var InputHandler, ch: string) =
  handler.pushUndo()
  
  let buffer = addr handler.buffer
  let line = buffer.lines[buffer.cursorY]
  
  # Delete selected text if there is a selection
  if buffer.selectionMode != None:
    let selection = getSelectedText(buffer[])
    if selection.len > 0:
      let startX = min(buffer.selectionStart.x, buffer.selectionEnd.x)
      let startY = min(buffer.selectionStart.y, buffer.selectionEnd.y)
      let endX = max(buffer.selectionStart.x, buffer.selectionEnd.x)
      let endY = max(buffer.selectionStart.y, buffer.selectionEnd.y)
      
      # Single line selection
      if startY == endY:
        let startPos = visualToLogical(line, startX)
        let endPos = visualToLogical(line, endX)
        buffer.lines[startY] = line[0..<startPos] & line[endPos..^1]
        buffer.logicalCursorPos = startPos
      else:
        # Multi-line selection
        let firstLine = buffer.lines[startY]
        let lastLine = buffer.lines[endY]
        let startPos = visualToLogical(firstLine, startX)
        let endPos = visualToLogical(lastLine, endX)
        
        buffer.lines[startY] = firstLine[0..<startPos] & lastLine[endPos..^1]
        buffer.lines.delete(startY + 1, endY)
        buffer.cursorY = startY
        buffer.logicalCursorPos = startPos
      
      buffer.selectionMode = None
  
  # Insert the character
  let currentLine = buffer.lines[buffer.cursorY]
  buffer.lines[buffer.cursorY] = currentLine[0..<buffer.logicalCursorPos] & 
                              ch & 
                              currentLine[buffer.logicalCursorPos..^1]
  buffer.logicalCursorPos += ch.len
  
  # Update visual cursor
  buffer.updateCursorFromLogical()

# Handle special key inputs
proc handleKey(handler: var InputHandler, key: KeyEvent): bool =
  var handled = true
  let buffer = addr handler.buffer
  
  case key.key:
    of KeyLeft:
      handler.pushUndo()
      buffer.moveCursor(Left, key.modifiers.contains(ModCtrl))
      if not key.modifiers.contains(ModShift):
        buffer.selectionMode = None
      else:
        if buffer.selectionMode == None:
          buffer.startSelection()
        buffer.updateSelection()
      
    of KeyRight:
      handler.pushUndo()
      buffer.moveCursor(Right, key.modifiers.contains(ModCtrl))
      if not key.modifiers.contains(ModShift):
        buffer.selectionMode = None
      else:
        if buffer.selectionMode == None:
          buffer.startSelection()
        buffer.updateSelection()
      
    of KeyUp:
      handler.pushUndo()
      buffer.moveCursor(Up)
      if not key.modifiers.contains(ModShift):
        buffer.selectionMode = None
      else:
        if buffer.selectionMode == None:
          buffer.startSelection()
        buffer.updateSelection()
      
    of KeyDown:
      handler.pushUndo()
      buffer.moveCursor(Down)
      if not key.modifiers.contains(ModShift):
        buffer.selectionMode = None
      else:
        if buffer.selectionMode == None:
          buffer.startSelection()
        buffer.updateSelection()
      
    of KeyHome:
      handler.pushUndo()
      buffer.moveCursor(Home)
      if not key.modifiers.contains(ModShift):
        buffer.selectionMode = None
      else:
        if buffer.selectionMode == None:
          buffer.startSelection()
        buffer.updateSelection()
      
    of KeyEnd:
      handler.pushUndo()
      buffer.moveCursor(End)
      if not key.modifiers.contains(ModShift):
        buffer.selectionMode = None
      else:
        if buffer.selectionMode == None:
          buffer.startSelection()
        buffer.updateSelection()
      
    of KeyBackspace:
      handler.pushUndo()
      if buffer.selectionMode != None:
        # Delete selection
        let selection = getSelectedText(buffer[])
        if selection.len > 0:
          let startX = min(buffer.selectionStart.x, buffer.selectionEnd.x)
          let startY = min(buffer.selectionStart.y, buffer.selectionEnd.y)
          let endX = max(buffer.selectionStart.x, buffer.selectionEnd.x)
          let endY = max(buffer.selectionStart.y, buffer.selectionEnd.y)
          
          # Single line selection
          if startY == endY:
            let line = buffer.lines[startY]
            let startPos = visualToLogical(line, startX)
            let endPos = visualToLogical(line, endX)
            buffer.lines[startY] = line[0..<startPos] & line[endPos..^1]
            buffer.logicalCursorPos = startPos
          else:
            # Multi-line selection
            let firstLine = buffer.lines[startY]
            let lastLine = buffer.lines[endY]
            let startPos = visualToLogical(firstLine, startX)
            let endPos = visualToLogical(lastLine, endX)
            
            buffer.lines[startY] = firstLine[0..<startPos] & lastLine[endPos..^1]
            buffer.lines.delete(startY + 1, endY)
            buffer.cursorY = startY
            buffer.logicalCursorPos = startPos
          
          buffer.selectionMode = None
      else:
        # No selection, delete previous character
        if buffer.logicalCursorPos > 0:
          # Delete character behind cursor
          let line = buffer.lines[buffer.cursorY]
          
          # Find previous grapheme cluster boundary
          let clusters = unicode_utils.splitIntoGraphemeClusters(line)
          var pos = 0
          var prevPos = 0
          for cluster in clusters:
            let clusterLen = cluster.codePoints.foldl(a + toUTF8(b).len, 0)
            let nextPos = pos + clusterLen
            if nextPos >= buffer.logicalCursorPos:
              break
            prevPos = pos
            pos = nextPos
          
          let deletePos = if pos < buffer.logicalCursorPos: pos else: prevPos
          buffer.lines[buffer.cursorY] = line[0..<deletePos] & line[buffer.logicalCursorPos..^1]
          buffer.logicalCursorPos = deletePos
        elif buffer.cursorY > 0:
          # At beginning of line, join with previous line
          let currentLine = buffer.lines[buffer.cursorY]
          let prevLine = buffer.lines[buffer.cursorY - 1]
          buffer.logicalCursorPos = prevLine.len
          buffer.lines[buffer.cursorY - 1] = prevLine & currentLine
          buffer.lines.delete(buffer.cursorY)
          buffer.cursorY -= 1
      
      buffer.updateCursorFromLogical()
      
    of KeyDelete:
      handler.pushUndo()
      if buffer.selectionMode != None:
        # Delete selection (same as backspace)
        let selection = getSelectedText(buffer[])
        if selection.len > 0:
          let startX = min(buffer.selectionStart.x, buffer.selectionEnd.x)
          let startY = min(buffer.selectionStart.y, buffer.selectionEnd.y)
          let endX = max(buffer.selectionStart.x, buffer.selectionEnd.x)
          let endY = max(buffer.selectionStart.y, buffer.selectionEnd.y)
          
          # Single line selection
          if startY == endY:
            let line = buffer.lines[startY]
            let startPos = visualToLogical(line, startX)
            let endPos = visualToLogical(line, endX)
            buffer.lines[startY] = line[0..<startPos] & line[endPos..^1]
            buffer.logicalCursorPos = startPos
          else:
            # Multi-line selection
            let firstLine = buffer.lines[startY]
            let lastLine = buffer.lines[endY]
            let startPos = visualToLogical(firstLine, startX)
            let endPos = visualToLogical(lastLine, endX)
            
            buffer.lines[startY] = firstLine[0..<startPos] & lastLine[endPos..^1]
            buffer.lines.delete(startY + 1, endY)
            buffer.cursorY = startY
            buffer.logicalCursorPos = startPos
          
          buffer.selectionMode = None
      else:
        # No selection, delete next character
        let line = buffer.lines[buffer.cursorY]
        
        if buffer.logicalCursorPos < line.len:
          # Find next grapheme cluster boundary
          let clusters = unicode_utils.splitIntoGraphemeClusters(line)
          var pos = 0
          var nextClusterEnd = 0
          
          for cluster in clusters:
            let clusterLen = cluster.codePoints.foldl(a + toUTF8(b).len, 0)
            let nextPos = pos + clusterLen
            
            if pos == buffer.logicalCursorPos:
              nextClusterEnd = nextPos
              break
              
            pos = nextPos
          
          if nextClusterEnd > buffer.logicalCursorPos:
            buffer.lines[buffer.cursorY] = line[0..<buffer.logicalCursorPos] & 
                                        line[nextClusterEnd..^1]
        elif buffer.cursorY < buffer.lines.high:
          # At end of line, join with next line
          let nextLine = buffer.lines[buffer.cursorY + 1]
          buffer.lines[buffer.cursorY] = line & nextLine
          buffer.lines.delete(buffer.cursorY + 1)
      
      buffer.updateCursorFromLogical()
      
    of KeyEnter:
      handler.pushUndo()
      if buffer.selectionMode != None:
        # Delete selection first
        let selection = getSelectedText(buffer[])
        if selection.len > 0:
          let startX = min(buffer.selectionStart.x, buffer.selectionEnd.x)
          let startY = min(buffer.selectionStart.y, buffer.selectionEnd.y)
          let endX = max(buffer.selectionStart.x, buffer.selectionEnd.x)
          let endY = max(buffer.selectionStart.y, buffer.selectionEnd.y)
          
          # Single line selection
          if startY == endY:
            let line = buffer.lines[startY]
            let startPos = visualToLogical(line, startX)
            let endPos = visualToLogical(line, endX)
            buffer.lines[startY] = line[0..<startPos] & line[endPos..^1]
            buffer.logicalCursorPos = startPos
            buffer.cursorY = startY
          else:
            # Multi-line selection
            let firstLine = buffer.lines[startY]
            let lastLine = buffer.lines[endY]
            let startPos = visualToLogical(firstLine, startX)
            let endPos = visualToLogical(lastLine, endX)
            
            buffer.lines[startY] = firstLine[0..<startPos] & lastLine[endPos..^1]
            buffer.lines.delete(startY + 1, endY)
            buffer.cursorY = startY
            buffer.logicalCursorPos = startPos
          
          buffer.selectionMode = None
      
      # Split line at cursor
      let line = buffer.lines[buffer.cursorY]
      let newLine = line[buffer.logicalCursorPos..^1]
      buffer.lines[buffer.cursorY] = line[0..<buffer.logicalCursorPos]
      
      # Insert new line
      buffer.lines.insert(newLine, buffer.cursorY + 1)
      buffer.cursorY += 1
      buffer.logicalCursorPos = 0
      buffer.updateCursorFromLogical()
      
    of KeyTab:
      handler.pushUndo()
      # Insert tab character or spaces
      handler.typeCharacter("  ")  # Using 2 spaces for tab
      
    # Cut, copy, paste operations
    of KeyX:
      if key.modifiers.contains(ModCtrl):
        handler.pushUndo()
        # Cut - copy then delete
        handler.clipboard = getSelectedText(buffer[])
        
        if handler.clipboard.len > 0:
          let startX = min(buffer.selectionStart.x, buffer.selectionEnd.x)
          let startY = min(buffer.selectionStart.y, buffer.selectionEnd.y)
          let endX = max(buffer.selectionStart.x, buffer.selectionEnd.x)
          let endY = max(buffer.selectionStart.y, buffer.selectionEnd.y)
          
          # Single line selection
          if startY == endY:
            let line = buffer.lines[startY]
            let startPos = visualToLogical(line, startX)
            let endPos = visualToLogical(line, endX)
            buffer.lines[startY] = line[0..<startPos] & line[endPos..^1]
            buffer.logicalCursorPos = startPos
          else:
            # Multi-line selection
            let firstLine = buffer.lines[startY]
            let lastLine = buffer.lines[endY]
            let startPos = visualToLogical(firstLine, startX)
            let endPos = visualToLogical(lastLine, endX)
            
            buffer.lines[startY] = firstLine[0..<startPos] & lastLine[endPos..^1]
            buffer.lines.delete(startY + 1, endY)
            buffer.cursorY = startY
            buffer.logicalCursorPos = startPos
          
          buffer.selectionMode = None
          buffer.updateCursorFromLogical()
      else:
        handled = false
      
    of KeyC:
      if key.modifiers.contains(ModCtrl):
        # Copy selected text
        handler.clipboard = getSelectedText(buffer[])
      else:
        handled = false
      
    of KeyV:
      if key.modifiers.contains(ModCtrl):
        handler.pushUndo()
        # Paste clipboard content
        if handler.clipboard.len > 0:
          # Delete selection if there is one
          if buffer.selectionMode != None:
            let selection = getSelectedText(buffer[])
            if selection.len > 0:
              let startX = min(buffer.selectionStart.x, buffer.selectionEnd.x)
              let startY = min(buffer.selectionStart.y, buffer.selectionEnd.y)
              let endX = max(buffer.selectionStart.x, buffer.selectionEnd.x)
              let endY = max(buffer.selectionStart.y, buffer.selectionEnd.y)
              
              # Single line selection
              if startY == endY:
                let line = buffer.lines[startY]
                let startPos = visualToLogical(line, startX)
                let endPos = visualToLogical(line, endX)
                buffer.lines[startY] = line[0..<startPos] & line[endPos..^1]
                buffer.logicalCursorPos = startPos
              else:
                # Multi-line selection
                let firstLine = buffer.lines[startY]
                let lastLine = buffer.lines[endY]
                let startPos = visualToLogical(firstLine, startX)
                let endPos = visualToLogical(lastLine, endX)
                
                buffer.lines[startY] = firstLine[0..<startPos] & lastLine[endPos..^1]
                buffer.lines.delete(startY + 1, endY)
                buffer.cursorY = startY
                buffer.logicalCursorPos = startPos
              
              buffer.selectionMode = None
          
          # Insert clipboard content
          let lines = handler.clipboard.split('\n')
          if lines.len == 1:
            # Single line paste
            let line = buffer.lines[buffer.cursorY]
            buffer.lines[buffer.cursorY] = line[0..<buffer.logicalCursorPos] & 
                                        lines[0] & 
                                        line[buffer.logicalCursorPos..^1]
            buffer.logicalCursorPos += lines[0].len
          else:
            # Multi-line paste
            let line = buffer.lines[buffer.cursorY]
            let lineEnd = line[buffer.logicalCursorPos..^1]
            
            # First line
            buffer.lines[buffer.cursorY] = line[0..<buffer.logicalCursorPos] & lines[0]
            
            # Middle lines
            for i in 1..<lines.high:
              buffer.lines.insert(lines[i], buffer.cursorY + i)
            
            # Last line + rest of original line
            buffer.lines.insert(lines[^1] & lineEnd, buffer.cursorY + lines.high)
            
            # Update cursor
            buffer.cursorY += lines.high
            buffer.logicalCursorPos = lines[^1].len
          
          buffer.updateCursorFromLogical()
      else:
        handled = false
      
    of KeyZ:
      if key.modifiers.contains(ModCtrl):
        # Undo
        if handler.undoStack.len > 0:
          # Push current state to redo stack
          var bufferCopy = handler.buffer
          handler.redoStack.add(bufferCopy)
          
          # Restore last state from undo stack
          handler.buffer = handler.undoStack.pop()
        
      elif key.modifiers.contains(ModCtrl) and key.modifiers.contains(ModShift):
        # Redo
        if handler.redoStack.len > 0:
          # Push current state to undo stack
          var bufferCopy = handler.buffer
          handler.undoStack.add(bufferCopy)
          
          # Restore state from redo stack
          handler.buffer = handler.redoStack.pop()
      else:
        handled = false
      
    of KeyEscape:
      # Cancel selection
      buffer.selectionMode = None
      
      # Exit compose or IME mode
      if handler.inputState != Normal:
        handler.inputState = Normal
        handler.composeSequence = ""
        handler.imeBuffer = ""
        handler.imePopupItems = @[]
        handler.imeSelectedIndex = -1
      
    else:
      handled = false
  
  return handled

# Handle dead key or compose key
proc startCompose(handler: var InputHandler, deadKey: string) =
  handler.inputState = Compose
  handler.composeSequence = deadKey

# Handle keypress during compose mode
proc handleComposeKey(handler: var InputHandler, key: string): bool =
  if handler.inputState != Compose:
    return false
  
  # Simple compose key handling
  # This is a simplified implementation - real input methods are more complex
  let compose = handler.composeSequence & key
  var result = ""
  
  # Handle common compositions
  if compose == "`a": result = "à"
  elif compose == "`e": result = "è"
  elif compose == "`i": result = "ì"
  elif compose == "`o": result = "ò"
  elif compose == "`u": result = "ù"
  elif compose == "'a": result = "á"
  elif compose == "'e": result = "é"
  elif compose == "'i": result = "í"
  elif compose == "'o": result = "ó"
  elif compose == "'u": result = "ú"
  elif compose == "^a": result = "â"
  elif compose == "^e": result = "ê"
  elif compose == "^i": result = "î"
  elif compose == "^o": result = "ô"
  elif compose == "^u": result = "û"
  elif compose == "\"a": result = "ä"
  elif compose == "\"e": result = "ë"
  elif compose == "\"i": result = "ï"
  elif compose == "\"o": result = "ö"
  elif compose == "\"u": result = "ü"
  elif compose == "~n": result = "ñ"
  elif compose == "~a": result = "ã"
  elif compose == "~o": result = "õ"
  elif compose == ",c": result = "ç"
  
  # If composition succeeded
  if result.len > 0:
    handler.typeCharacter(result)
    handler.inputState = Normal
    handler.composeSequence = ""
    return true
  
  # Failed composition
  handler.inputState = Normal
  handler.composeSequence = ""
  
  # For failed compositions, output the individual characters
  handler.typeCharacter(compose)
  return true

# Simulate IME (Input Method Editor) behavior
proc startIME(handler: var InputHandler) =
  handler.inputState = IME
  handler.imeBuffer = ""
  handler.imePopupItems = @[]
  handler.imeSelectedIndex = -1

# Handle IME input
proc handleIMEInput(handler: var InputHandler, key: string): bool =
  if handler.inputState != IME:
    return false
  
  # Handle control keys in IME mode
  if key == "\r" or key == "\n":
    # Confirm selection or insert buffer directly
    if handler.imeSelectedIndex >= 0 and handler.imeSelectedIndex < handler.imePopupItems.len:
      handler.typeCharacter(handler.imePopupItems[handler.imeSelectedIndex])
    else:
      handler.typeCharacter(handler.imeBuffer)
    
    handler.inputState = Normal
    handler.imeBuffer = ""
    handler.imePopupItems = @[]
    handler.imeSelectedIndex = -1
    return true
    
  elif key == "\e":  # Escape
    # Cancel IME input
    handler.inputState = Normal
    handler.imeBuffer = ""
    handler.imePopupItems = @[]
    handler.imeSelectedIndex = -1
    return true
    
  elif key == "\b":  # Backspace
    # Delete last character from buffer
    if handler.imeBuffer.len > 0:
      let runes = handler.imeBuffer.toRunes
      handler.imeBuffer = $runes[0..^2]
      
      # Update suggestions
      handler.updateIMESuggestions()
    elif handler.imeBuffer.len == 0:
      # Exit IME mode if buffer is empty
      handler.inputState = Normal
    
    return true
    
  # Add character to IME buffer
  handler.imeBuffer.add(key)
  
  # Update suggestions
  handler.updateIMESuggestions()
  return true

# Update IME suggestions based on current buffer
proc updateIMESuggestions(handler: var InputHandler) =
  # This is a simplified implementation
  # Real IME would use complex algorithms, dictionaries, etc.
  handler.imePopupItems = @[]
  
  # Example: Simple pinyin to Chinese character mapping
  if handler.imeBuffer == "ni":
    handler.imePopupItems = @["你", "尼", "呢"]
  elif handler.imeBuffer == "hao":
    handler.imePopupItems = @["好", "号", "毫"]
  elif handler.imeBuffer == "nihao":
    handler.imePopupItems = @["你好", "你号", "尼毫"]
  
  # Reset selection
  if handler.imePopupItems.len > 0:
    handler.imeSelectedIndex = 0
  else:
    handler.imeSelectedIndex = -1

# Process a key event completely
proc processKeyEvent(handler: var InputHandler, event: KeyEvent): bool =
  # First try to handle special keys
  if handler.handleKey(event):
    return true
  
  # Then handle regular character input based on input state
  if event.ch.len > 0:
    if handler.inputState == Compose:
      return handler.handleComposeKey($event.ch)
    elif handler.inputState == IME:
      return handler.handleIMEInput($event.ch)
    else:
      handler.typeCharacter($event.ch)
      return true
  
  return false

# Draw the input buffer to the screen
proc drawInputHandler(handler: InputHandler, buffer: var Buffer, startX, startY: int, 
                      width: int, height: int, style: Style = Style()) =
  # Draw text content
  let visibleLines = min(height, handler.buffer.lines.len - handler.buffer.visibleAreaStart)
  
  for i in 0..<visibleLines:
    let lineIndex = handler.buffer.visibleAreaStart + i
    let line = handler.buffer.lines[lineIndex]
    
    # Draw line
    buffer.printAdvanced(startX, startY + i, line, style)
    
    # Draw selection if this line is selected
    if handler.buffer.selectionMode != None:
      let startLine = min(handler.buffer.selectionStart.y, handler.buffer.selectionEnd.y)
      let endLine = max(handler.buffer.selectionStart.y, handler.buffer.selectionEnd.y)
      
      if lineIndex >= startLine and lineIndex <= endLine:
        var selStartX, selEndX: int
        
        if lineIndex == handler.buffer.selectionStart.y and 
           lineIndex == handler.buffer.selectionEnd.y:
          # Selection on single line
          selStartX = min(handler.buffer.selectionStart.x, handler.buffer.selectionEnd.x)
          selEndX = max(handler.buffer.selectionStart.x, handler.buffer.selectionEnd.x)
        elif lineIndex == handler.buffer.selectionStart.y:
          # First line of multi-line selection
          selStartX = min(handler.buffer.selectionStart.x, handler.buffer.selectionEnd.x)
          selEndX = line.len
        elif lineIndex == handler.buffer.selectionEnd.y:
          # Last line of multi-line selection
          selStartX = 0
          selEndX = max(handler.buffer.selectionStart.x, handler.buffer.selectionEnd.x)
        else:
          # Middle line of multi-line selection
          selStartX = 0
          selEndX = line.len
        
        # Draw selected text with highlight
        let selLine = line
        let selStartPos = visualToLogical(selLine, selStartX)
        let selEndPos = visualToLogical(selLine, selEndX)
        
        if selStartPos < selEndPos:
          let beforeSel = selLine[0..<selStartPos]
          let selection = selLine[selStartPos..<selEndPos]
          
          let selectStyle = Style(
            fg: ColorBlack,
            bg: ColorWhite,
            attrs: style.attrs
          )
          
          let beforeWidth = displayWidth(beforeSel)
          buffer.printAdvanced(startX + beforeWidth, startY + i, selection, selectStyle)
  
  # Draw IME composition window if active
  if handler.inputState == IME:
    let imeX = startX + handler.buffer.cursorX
    let imeY = startY + handler.buffer.cursorY - handler.buffer.visibleAreaStart + 1
    
    let imeStyle = Style(
      fg: ColorDefault,
      bg: ColorBlue,
      attrs: {AttrBold}
    )
    
    # Draw composition buffer
    buffer.printAdvanced(imeX, imeY, handler.imeBuffer, imeStyle)
    
    # Draw candidate list
    if handler.imePopupItems.len > 0:
      let candidateStyle = Style(
        fg: ColorDefault,
        bg: ColorBlack
      )
      
      let selectedStyle = Style(
        fg: ColorBlack,
        bg: ColorWhite,
        attrs: {AttrBold}
      )
      
      for i, candidate in handler.imePopupItems:
        let candidateX = imeX
        let candidateY = imeY + i + 1
        
        if i == handler.imeSelectedIndex:
          buffer.printAdvanced(candidateX, candidateY, 
                             (i+1).intToStr & ". " & candidate, 
                             selectedStyle)
        else:
          buffer.printAdvanced(candidateX, candidateY, 
                             (i+1).intToStr & ". " & candidate, 
                             candidateStyle)
  
  # Draw compose sequence if active
  if handler.inputState == Compose:
    let composeX = startX + handler.buffer.cursorX
    let composeY = startY + handler.buffer.cursorY - handler.buffer.visibleAreaStart
    
    let composeStyle = Style(
      fg: ColorDefault,
      bg: ColorRed,
      attrs: {AttrBold}
    )
    
    buffer.printAdvanced(composeX, composeY, handler.composeSequence, composeStyle)
  
  # Draw cursor
  if handler.inputState == Normal:
    let cursorX = startX + handler.buffer.cursorX
    let cursorY = startY + handler.buffer.cursorY - handler.buffer.visibleAreaStart
    
    if cursorY >= startY and cursorY < startY + height:
      let cursorStyle = Style(
        fg: ColorBlack,
        bg: ColorWhite
      )
      
      # Draw cursor at current position
      let line = handler.buffer.lines[handler.buffer.cursorY]
      let ch = if handler.buffer.logicalCursorPos < line.len: 
                 $line[handler.buffer.logicalCursorPos] 
               else: " "
               
      buffer.print(cursorX, cursorY, ch, cursorStyle)

# Main example
proc main() =
  # Initialize the terminal
  withTerminal:
    # Get initial size
    let (width, height) = raw.getTerminalSize()
    
    # Create a buffer
    var buffer = newBuffer(width, height)
    
    # Clear the screen
    clearScreen()
    
    # Title
    let titleStyle = Style(
      fg: ColorCyan,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    buffer.print(2, 1, "Unicode-aware Input Handling", titleStyle)
    
    # Description
    buffer.print(2, 3, "Demonstration of advanced Unicode input handling and text editing")
    
    # Section styles
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Input Handler Section
    buffer.print(2, 5, "Unicode Text Editor with IME Support", sectionStyle)
    
    # Draw border
    let editorX = 4
    let editorY = 7
    let editorWidth = width - 8
    let editorHeight = 20
    
    # Draw border
    for i in 0..<editorWidth+2:
      buffer.print(editorX-1+i, editorY-1, "─")
      buffer.print(editorX-1+i, editorY+editorHeight, "─")
    
    for i in 0..<editorHeight:
      buffer.print(editorX-1, editorY+i, "│")
      buffer.print(editorX+editorWidth, editorY+i, "│")
    
    buffer.print(editorX-1, editorY-1, "┌")
    buffer.print(editorX+editorWidth, editorY-1, "┐")
    buffer.print(editorX-1, editorY+editorHeight, "└")
    buffer.print(editorX+editorWidth, editorY+editorHeight, "┘")
    
    # Create input handler
    var inputHandler = newInputHandler()
    
    # Initialize with sample text
    inputHandler.buffer.lines = @[
      "Unicode Input Handling Example",
      "================================",
      "",
      "This editor demonstrates:",
      "",
      "• Grapheme cluster-aware cursor movement",
      "• Proper text selection with Unicode",
      "• Dead-key support for compositions (try ` + a for à)",
      "• IME simulation (Alt+i to activate, then type 'nihao')",
      "",
      "Sample texts in different scripts:",
      "",
      "English: The quick brown fox jumps over the lazy dog",
      "Japanese: こんにちは世界",
      "Arabic: مرحبا بالعالم",
      "Hindi: नमस्ते दुनिया",
      "Emoji: 👨‍👩‍👧‍👦 👍 🚀 🎮 🍕",
      "",
      "Try editing this text with arrow keys, backspace, delete, etc."
    ]
    
    # Instructions
    buffer.print(2, editorY + editorHeight + 2, "Navigation: Arrow keys, Home, End")
    buffer.print(2, editorY + editorHeight + 3, "Selection: Shift+Arrow")
    buffer.print(2, editorY + editorHeight + 4, "Clipboard: Ctrl+X, Ctrl+C, Ctrl+V")
    buffer.print(2, editorY + editorHeight + 5, "Composition: Press ` then a letter")
    buffer.print(2, editorY + editorHeight + 6, "IME mode: Press Alt+i, then type 'ni', 'hao', or 'nihao'")
    buffer.print(2, editorY + editorHeight + 7, "Exit: Escape")
    
    # Draw the input handler
    inputHandler.drawInputHandler(buffer, editorX, editorY, editorWidth, editorHeight)
    
    # Draw buffer
    drawBuffer(buffer)
    
    # Main event loop
    var running = true
    while running:
      let event = input.pollEvent()
      
      case event.kind:
        of EventKey:
          let key = event.key
          
          # Check for exit
          if key.key == KeyEscape and inputHandler.inputState == Normal:
            running = false
            break
          
          # Check for IME toggle
          if key.key == KeyI and key.modifiers.contains(ModAlt):
            inputHandler.startIME()
          # Check for compose key
          elif $key.ch == "`" and inputHandler.inputState == Normal:
            inputHandler.startCompose("`")
          elif $key.ch == "'" and inputHandler.inputState == Normal:
            inputHandler.startCompose("'")
          elif $key.ch == "^" and inputHandler.inputState == Normal:
            inputHandler.startCompose("^")
          elif $key.ch == "\"" and inputHandler.inputState == Normal:
            inputHandler.startCompose("\"")
          elif $key.ch == "~" and inputHandler.inputState == Normal:
            inputHandler.startCompose("~")
          elif $key.ch == "," and inputHandler.inputState == Normal:
            inputHandler.startCompose(",")
          else:
            # Process normal key event
            discard inputHandler.processKeyEvent(key)
          
          # Clear and redraw
          clearScreen()
          drawBuffer(buffer)
          
          # Redraw input handler
          inputHandler.drawInputHandler(buffer, editorX, editorY, editorWidth, editorHeight)
          
          # Update display
          drawBuffer(buffer)
          
        of EventResize:
          # Handle terminal resize
          let (newWidth, newHeight) = raw.getTerminalSize()
          buffer = newBuffer(newWidth, newHeight)
          
          # Redraw everything
          clearScreen()
          
          # Title
          buffer.print(2, 1, "Unicode-aware Input Handling", titleStyle)
          buffer.print(2, 3, "Demonstration of advanced Unicode input handling and text editing")
          buffer.print(2, 5, "Unicode Text Editor with IME Support", sectionStyle)
          
          # Draw border
          for i in 0..<editorWidth+2:
            buffer.print(editorX-1+i, editorY-1, "─")
            buffer.print(editorX-1+i, editorY+editorHeight, "─")
          
          for i in 0..<editorHeight:
            buffer.print(editorX-1, editorY+i, "│")
            buffer.print(editorX+editorWidth, editorY+i, "│")
          
          buffer.print(editorX-1, editorY-1, "┌")
          buffer.print(editorX+editorWidth, editorY-1, "┐")
          buffer.print(editorX-1, editorY+editorHeight, "└")
          buffer.print(editorX+editorWidth, editorY+editorHeight, "┘")
          
          # Instructions
          buffer.print(2, editorY + editorHeight + 2, "Navigation: Arrow keys, Home, End")
          buffer.print(2, editorY + editorHeight + 3, "Selection: Shift+Arrow")
          buffer.print(2, editorY + editorHeight + 4, "Clipboard: Ctrl+X, Ctrl+C, Ctrl+V")
          buffer.print(2, editorY + editorHeight + 5, "Composition: Press ` then a letter")
          buffer.print(2, editorY + editorHeight + 6, "IME mode: Press Alt+i, then type 'ni', 'hao', or 'nihao'")
          buffer.print(2, editorY + editorHeight + 7, "Exit: Escape")
          
          # Draw input handler
          inputHandler.drawInputHandler(buffer, editorX, editorY, editorWidth, editorHeight)
          
          # Update display
          drawBuffer(buffer)
          
        else:
          discard

when isMainModule:
  main()