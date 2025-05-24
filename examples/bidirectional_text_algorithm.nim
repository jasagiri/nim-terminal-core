# bidirectional_text_algorithm.nim
## Unicode Bidirectional Algorithm Implementation
##
## This example demonstrates the implementation of the Unicode Bidirectional Algorithm (UAX #9)
## for correctly displaying mixed right-to-left and left-to-right text in terminal applications.

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/algorithm
import std/sequtils

# Bidirectional character types as defined in Unicode UAX #9
type
  BidiCharacterType = enum
    # Strong types
    L,    # Left-to-Right
    R,    # Right-to-Left
    AL,   # Arabic Letter (Right-to-Left)
    
    # Weak types
    EN,   # European Number
    ES,   # European Number Separator
    ET,   # European Number Terminator
    AN,   # Arabic Number
    CS,   # Common Number Separator
    NSM,  # Nonspacing Mark
    BN,   # Boundary Neutral
    
    # Neutral types
    B,    # Paragraph Separator
    S,    # Segment Separator
    WS,   # Whitespace
    ON,   # Other Neutral
    
    # Explicit formatting codes
    LRE,  # Left-to-Right Embedding
    RLE,  # Right-to-Left Embedding
    LRO,  # Left-to-Right Override
    RLO,  # Right-to-Left Override
    PDF,  # Pop Directional Format
    LRI,  # Left-to-Right Isolate
    RLI,  # Right-to-Left Isolate
    FSI,  # First Strong Isolate
    PDI   # Pop Directional Isolate

  BidiParagraphDirection = enum
    LeftToRight,
    RightToLeft
    
  BidiLevelRun = object
    startIndex: int
    length: int
    level: int
    text: string
    
  BidiInfo = object
    charTypes: seq[BidiCharacterType]
    levels: seq[int]
    paragraphDir: BidiParagraphDirection
    runs: seq[BidiLevelRun]
    visualOrder: seq[int]

# Simplified character type lookup (covers basic ranges)
proc getBidiCharacterType(r: Rune): BidiCharacterType =
  let codePoint = r.int32
  
  # Strong types
  if codePoint < 0x0590:
    # ASCII, Latin, Greek, Cyrillic, etc.
    return L
  elif (codePoint >= 0x0590 and codePoint <= 0x08FF) or  # Hebrew/Arabic ranges
       (codePoint >= 0xFB1D and codePoint <= 0xFDFF) or
       (codePoint >= 0xFE70 and codePoint <= 0xFEFF):
    if codePoint >= 0x0600 and codePoint <= 0x07BF:
      # Arabic
      return AL
    else:
      # Hebrew and other RTL
      return R
    
  # European Numbers
  elif (codePoint >= 0x0030 and codePoint <= 0x0039):  # ASCII digits
    return EN
  
  # Arabic Numbers
  elif (codePoint >= 0x0660 and codePoint <= 0x0669) or  # Arabic-Indic digits
       (codePoint >= 0x06F0 and codePoint <= 0x06F9):    # Extended Arabic-Indic digits
    return AN
  
  # Common Number Separators
  elif codePoint == 0x002E or   # FULL STOP
       codePoint == 0x002C:     # COMMA
    return CS
  
  # European Number Separators
  elif codePoint == 0x002B or   # PLUS SIGN
       codePoint == 0x002D or   # HYPHEN-MINUS
       codePoint == 0x2212:     # MINUS SIGN
    return ES
    
  # European Number Terminators
  elif codePoint == 0x0025 or   # PERCENT SIGN
       codePoint == 0x00A2 or   # CENT SIGN
       codePoint == 0x00A3 or   # POUND SIGN
       codePoint == 0x00A5 or   # YEN SIGN
       codePoint == 0x20AC:     # EURO SIGN
    return ET
    
  # Nonspacing Marks
  elif (codePoint >= 0x0300 and codePoint <= 0x036F) or  # Combining diacritical marks
       (codePoint >= 0x1DC0 and codePoint <= 0x1DFF):    # Combining diacritical marks supplement
    return NSM
    
  # Whitespace
  elif codePoint == 0x0020 or   # SPACE
       codePoint == 0x0009 or   # TAB
       codePoint == 0x00A0:     # NO-BREAK SPACE
    return WS
    
  # Explicit formatting codes
  elif codePoint == 0x202A: return LRE
  elif codePoint == 0x202B: return RLE
  elif codePoint == 0x202D: return LRO
  elif codePoint == 0x202E: return RLO
  elif codePoint == 0x202C: return PDF
  elif codePoint == 0x2066: return LRI
  elif codePoint == 0x2067: return RLI
  elif codePoint == 0x2068: return FSI
  elif codePoint == 0x2069: return PDI
    
  # Default to Other Neutral
  return ON

# Determine the paragraph direction from text
proc getParagraphDirection(text: string): BidiParagraphDirection =
  # Implements rule P2 of the Bidirectional Algorithm
  # Find the first strong directional character and use its direction
  
  let runes = text.toRunes
  for r in runes:
    let charType = getBidiCharacterType(r)
    if charType == L:
      return LeftToRight
    elif charType == R or charType == AL:
      return RightToLeft
  
  # Default to left-to-right if no strong directional character is found
  return LeftToRight

# Resolve explicit levels and embeddings (rules X1-X8)
proc resolveExplicitLevels(bidi: var BidiInfo, text: string) =
  let runes = text.toRunes
  var directionalStatusStack: seq[int] = @[]
  var overrideStatusStack: seq[char] = @[]
  
  # Initialize with paragraph embedding level
  var currentLevel = if bidi.paragraphDir == LeftToRight: 0 else: 1
  var currentOverride = 'n'  # 'n' for neutral, 'l' for LTR override, 'r' for RTL override
  
  for i, r in runes:
    let charType = bidi.charTypes[i]
    
    # Handle explicit embedding codes
    if charType == LRE:
      # Push current state onto stack
      directionalStatusStack.add(currentLevel)
      overrideStatusStack.add(currentOverride)
      
      # Set new embedding level (minimum odd level higher than current)
      currentLevel = ((currentLevel div 2) * 2) + 2
      if currentLevel > 125: currentLevel = 125  # Maximum level
      currentOverride = 'n'
      
      bidi.levels[i] = currentLevel
      
    elif charType == RLE:
      # Push current state onto stack
      directionalStatusStack.add(currentLevel)
      overrideStatusStack.add(currentOverride)
      
      # Set new embedding level (minimum odd level higher than current)
      currentLevel = ((currentLevel div 2) * 2) + 1
      if currentLevel > 126: currentLevel = 126  # Maximum level
      currentOverride = 'n'
      
      bidi.levels[i] = currentLevel
      
    elif charType == LRO:
      # Push current state onto stack
      directionalStatusStack.add(currentLevel)
      overrideStatusStack.add(currentOverride)
      
      # Set new embedding level (minimum even level higher than current)
      currentLevel = ((currentLevel div 2) * 2) + 2
      if currentLevel > 125: currentLevel = 125  # Maximum level
      currentOverride = 'l'
      
      bidi.levels[i] = currentLevel
      
    elif charType == RLO:
      # Push current state onto stack
      directionalStatusStack.add(currentLevel)
      overrideStatusStack.add(currentOverride)
      
      # Set new embedding level (minimum odd level higher than current)
      currentLevel = ((currentLevel div 2) * 2) + 1
      if currentLevel > 126: currentLevel = 126  # Maximum level
      currentOverride = 'r'
      
      bidi.levels[i] = currentLevel
      
    elif charType == PDF:
      # Pop last state from stack
      if directionalStatusStack.len > 0:
        currentLevel = directionalStatusStack.pop()
        currentOverride = overrideStatusStack.pop()
      
      bidi.levels[i] = currentLevel
      
    else:
      # Regular character
      bidi.levels[i] = currentLevel
      
      # Apply override if any
      if currentOverride == 'l':
        bidi.charTypes[i] = L
      elif currentOverride == 'r':
        bidi.charTypes[i] = R

# Resolve weak types (rules W1-W7)
proc resolveWeakTypes(bidi: var BidiInfo) =
  let len = bidi.charTypes.len
  
  # Rule W1: Examine each non-spacing mark and change its type to the type of
  # its previous character if the previous character exists and is not a boundary neutral
  for i in 0..<len:
    if bidi.charTypes[i] == NSM:
      if i > 0 and bidi.charTypes[i-1] != BN:
        bidi.charTypes[i] = bidi.charTypes[i-1]
      else:
        # If NSM is at start or after boundary neutral, use paragraph direction
        bidi.charTypes[i] = if bidi.paragraphDir == LeftToRight: L else: R
  
  # Rule W2: Any AN adjacent to EN becomes EN
  for i in 0..<len:
    if bidi.charTypes[i] == AN:
      if (i > 0 and bidi.charTypes[i-1] == EN) or 
         (i < len-1 and bidi.charTypes[i+1] == EN):
        bidi.charTypes[i] = EN
  
  # Rule W3: Change ALs to R
  for i in 0..<len:
    if bidi.charTypes[i] == AL:
      bidi.charTypes[i] = R
  
  # Rule W4: A sequence of ETs adjacent to EN changes to EN
  var i = 0
  while i < len:
    if bidi.charTypes[i] == ET:
      # Look backward for EN
      var beforeEN = false
      var j = i - 1
      while j >= 0:
        if bidi.charTypes[j] == EN:
          beforeEN = true
          break
        elif bidi.charTypes[j] != ET:
          break
        j -= 1
        
      # Look forward for EN
      var afterEN = false
      j = i + 1
      while j < len:
        if bidi.charTypes[j] == EN:
          afterEN = true
          break
        elif bidi.charTypes[j] != ET:
          break
        j += 1
        
      # If surrounded by ENs, convert this ET and any adjacent ETs to EN
      if beforeEN or afterEN:
        var start = i
        while start >= 0 and bidi.charTypes[start] == ET:
          bidi.charTypes[start] = EN
          start -= 1
          
        var finish = i
        while finish < len and bidi.charTypes[finish] == ET:
          bidi.charTypes[finish] = EN
          finish += 1
          
        i = finish
        continue
    
    i += 1
  
  # Rule W5: ETs and ESs after ENs change to EN
  for i in 0..<len:
    if (bidi.charTypes[i] == ET or bidi.charTypes[i] == ES) and i > 0 and bidi.charTypes[i-1] == EN:
      bidi.charTypes[i] = EN
  
  # Rule W6: Separators and terminators between numerics change to numeric
  for i in 0..<len:
    if (bidi.charTypes[i] == ES or bidi.charTypes[i] == CS) and 
       i > 0 and i < len-1 and 
       (bidi.charTypes[i-1] == EN or bidi.charTypes[i-1] == AN) and
       (bidi.charTypes[i+1] == EN or bidi.charTypes[i+1] == AN):
      bidi.charTypes[i] = bidi.charTypes[i-1]  # Change to the same numeric type
  
  # Rule W7: Change EN to L if the previous strong character is L
  var prevStrong = if bidi.paragraphDir == LeftToRight: L else: R
  for i in 0..<len:
    if bidi.charTypes[i] == L or bidi.charTypes[i] == R:
      prevStrong = bidi.charTypes[i]
    elif bidi.charTypes[i] == EN and prevStrong == L:
      bidi.charTypes[i] = L

# Resolve neutral types (rules N1-N2)
proc resolveNeutralTypes(bidi: var BidiInfo) =
  let len = bidi.charTypes.len
  
  # Rule N1: Neutral characters adopt the direction of the surrounding strong text
  for i in 0..<len:
    if bidi.charTypes[i] in {WS, ON, B, S, BN}:
      # Find the previous strong character
      var prevStrongType: BidiCharacterType = ON
      var j = i - 1
      while j >= 0:
        if bidi.charTypes[j] == L or bidi.charTypes[j] == R:
          prevStrongType = bidi.charTypes[j]
          break
        j -= 1
      
      # If no previous strong, use paragraph direction
      if prevStrongType == ON:
        prevStrongType = if bidi.paragraphDir == LeftToRight: L else: R
      
      # Find the next strong character
      var nextStrongType: BidiCharacterType = ON
      j = i + 1
      while j < len:
        if bidi.charTypes[j] == L or bidi.charTypes[j] == R:
          nextStrongType = bidi.charTypes[j]
          break
        j += 1
      
      # If no next strong, use paragraph direction
      if nextStrongType == ON:
        nextStrongType = if bidi.paragraphDir == LeftToRight: L else: R
      
      # If surrounded by same direction, neutral gets that direction
      if prevStrongType == nextStrongType:
        bidi.charTypes[i] = prevStrongType
      else:
        # If surrounded by different directions, neutral gets embedding direction
        let level = bidi.levels[i]
        bidi.charTypes[i] = if level mod 2 == 0: L else: R

# Resolve implicit levels (rules I1-I2)
proc resolveImplicitLevels(bidi: var BidiInfo) =
  let len = bidi.charTypes.len
  
  for i in 0..<len:
    let level = bidi.levels[i]
    
    # Rule I1: For odd levels, L types go up one
    if level mod 2 == 1:  # Odd level (RTL)
      if bidi.charTypes[i] == L:
        bidi.levels[i] += 1
    
    # Rule I2: For even levels, R types go up one
    else:  # Even level (LTR)
      if bidi.charTypes[i] in {R, AN, EN}:
        bidi.levels[i] += 1

# Find consecutive runs of same level
proc findLevelRuns(bidi: var BidiInfo, text: string) =
  let len = bidi.levels.len
  let runes = text.toRunes
  
  if len == 0:
    return
  
  var currentLevel = bidi.levels[0]
  var currentStart = 0
  var currentText = ""
  
  for i in 0..<len:
    if i > 0 and bidi.levels[i] != currentLevel:
      # End of current run, add it to runs
      bidi.runs.add(BidiLevelRun(
        startIndex: currentStart,
        length: i - currentStart,
        level: currentLevel,
        text: currentText
      ))
      
      # Start new run
      currentLevel = bidi.levels[i]
      currentStart = i
      currentText = $runes[i]
    else:
      # Continue current run
      currentText.add($runes[i])
  
  # Add the last run
  bidi.runs.add(BidiLevelRun(
    startIndex: currentStart,
    length: len - currentStart,
    level: currentLevel,
    text: currentText
  ))

# Determine visual ordering of runs
proc determineVisualOrder(bidi: var BidiInfo) =
  # Sort runs by level (highest first, then by start index)
  var runsByLevel: seq[tuple[index: int, run: BidiLevelRun]] = @[]
  
  for i, run in bidi.runs:
    runsByLevel.add((i, run))
  
  # Sort runs by level (odd levels in descending order, even in ascending order)
  runsByLevel.sort(proc(a, b: tuple[index: int, run: BidiLevelRun]): int =
    let levelA = a.run.level
    let levelB = b.run.level
    
    if levelA != levelB:
      return levelB - levelA  # Higher levels first
    else:
      # Same level, sort by start index (left to right)
      if levelA mod 2 == 0:  # Even levels (LTR)
        return a.run.startIndex - b.run.startIndex
      else:  # Odd levels (RTL)
        return b.run.startIndex - a.run.startIndex
  )
  
  # Create the visual order mapping
  bidi.visualOrder = @[]
  for item in runsByLevel:
    bidi.visualOrder.add(item.index)

# Process a string using the bidi algorithm
proc processBidiText*(text: string): BidiInfo =
  result = BidiInfo()
  
  # Empty string case
  if text.len == 0:
    return result
  
  let runes = text.toRunes
  let len = runes.len
  
  # Initialize with character types and baseline levels
  result.charTypes = newSeq[BidiCharacterType](len)
  result.levels = newSeq[int](len)
  
  for i, r in runes:
    result.charTypes[i] = getBidiCharacterType(r)
  
  # Determine paragraph direction (rule P2)
  result.paragraphDir = getParagraphDirection(text)
  let baseLevel = if result.paragraphDir == LeftToRight: 0 else: 1
  
  # Initialize all levels to paragraph level
  for i in 0..<len:
    result.levels[i] = baseLevel
  
  # Apply the bidi algorithm steps
  result.resolveExplicitLevels(text)
  result.resolveWeakTypes()
  result.resolveNeutralTypes()
  result.resolveImplicitLevels()
  
  # Find level runs
  result.findLevelRuns(text)
  
  # Determine visual ordering
  result.determineVisualOrder()
  
  return result

# Reorder characters for display
proc getVisualText*(bidi: BidiInfo): string =
  var result = ""
  
  # Follow the visual order of runs
  for runIndex in bidi.visualOrder:
    let run = bidi.runs[runIndex]
    
    # For odd levels (RTL), reverse the characters within the run
    if run.level mod 2 == 1:
      var reversed = run.text
      reversed.reverse()
      result.add(reversed)
    else:
      result.add(run.text)
  
  return result

# Directional Marks for display
const
  LRM = "\u200E"  # LEFT-TO-RIGHT MARK
  RLM = "\u200F"  # RIGHT-TO-LEFT MARK
  LRE_MARK = "\u202A"  # LEFT-TO-RIGHT EMBEDDING
  RLE_MARK = "\u202B"  # RIGHT-TO-LEFT EMBEDDING
  PDF_MARK = "\u202C"  # POP DIRECTIONAL FORMATTING

# Format text showing bidi controls
proc formatWithBidiControls(text: string): string =
  result = text.replace(LRM, "{LRM}")
          .replace(RLM, "{RLM}")
          .replace(LRE_MARK, "{LRE}")
          .replace(RLE_MARK, "{RLE}")
          .replace(PDF_MARK, "{PDF}")
  return result

# Render bidi information for a text
proc renderBidiInfo(buffer: var Buffer, x, y: int, text: string, 
                    visualDisplay: bool = true, showControls: bool = false) =
  # Process the text
  var bidiText = text
  if showControls:
    bidiText = formatWithBidiControls(text)
  
  let bidi = processBidiText(bidiText)
  
  # Get the visual ordering
  let visualText = getVisualText(bidi)
  
  # Display original and visual text
  buffer.print(x, y, "Input text: " & bidiText)
  
  if visualDisplay:
    buffer.print(x, y+1, "Visual text: " & visualText)
  
  # Display paragraph direction
  let dirText = if bidi.paragraphDir == LeftToRight: "LTR" else: "RTL"
  buffer.print(x, y+2, "Paragraph direction: " & dirText)
  
  # Display level runs
  buffer.print(x, y+3, "Level runs:")
  for i, run in bidi.runs:
    let levelInfo = "Run " & $i & ": level=" & $run.level & 
                   ", text=\"" & run.text & "\""
    buffer.print(x+2, y+4+i, levelInfo)
  
  # Display visual order
  var visualOrderText = "Visual order: "
  for i, runIdx in bidi.visualOrder:
    visualOrderText.add($runIdx)
    if i < bidi.visualOrder.high:
      visualOrderText.add(", ")
  
  buffer.print(x, y+4+bidi.runs.len, visualOrderText)

# Demonstrate correct display of bidirectional text
proc renderBidirectionalTextDemo(buffer: var Buffer, x, y: int, width: int = 60) =
  let examples = @[
    # Simple examples
    "Hello World!",  # Pure LTR
    "مرحبا بالعالم", # Pure RTL
    "Hello مرحبا!", # Mixed LTR/RTL
    
    # Numbers in different contexts
    "The number 1234 is easy to read.",  # LTR with numbers
    "العدد 1234 سهل القراءة.",  # RTL with numbers
    "Mixed: 1234 and أبجد",  # Mixed with numbers
    
    # Punctuation and special cases
    "He said \"مرحبا\" to me.",  # LTR with RTL quotation
    "قال \"Hello\" لي.",  # RTL with LTR quotation
    "A test: (123-456) and (789-000) numbers.",  # Parentheses and numbers
    "اختبار: (123-456) و (789-000) أرقام.",  # RTL with parenthesized numbers
    
    # Complex examples with explicit controls
    LRM & "Starting with LRM: " & "مرحبا",  # Forcing LTR context
    RLM & "Starting with RLM: " & "Hello",  # Forcing RTL context
    "Mixed " & LRE_MARK & "العربية English" & PDF_MARK & " text",  # Embedding
    "مختلط " & RLE_MARK & "English العربية" & PDF_MARK & " نص"  # RTL embedding
  ]
  
  let sectionTitle = Style(
    fg: ColorYellow,
    bg: ColorDefault,
    attrs: {AttrBold}
  )
  
  let ltrStyle = Style(
    fg: ColorBlue,
    bg: ColorDefault
  )
  
  let rtlStyle = Style(
    fg: ColorRed,
    bg: ColorDefault
  )
  
  # Title
  buffer.print(x, y, "Bidirectional Text Display Demo", sectionTitle)
  
  # Simple examples
  buffer.print(x, y+2, "Simple Examples:", Style(attrs: {AttrBold}))
  
  var yPos = y+3
  for i in 0..2:
    let example = examples[i]
    let bidi = processBidiText(example)
    let visual = getVisualText(bidi)
    
    // Apply different styles for LTR and RTL
    let isRTL = bidi.paragraphDir == RightToLeft
    let style = if isRTL: rtlStyle else: ltrStyle
    
    buffer.print(x, yPos, $i & ". Original: ", Style(attrs: {AttrBold}))
    buffer.printAdvanced(x+12, yPos, example, style)
    
    buffer.print(x, yPos+1, "   Visual: ")
    buffer.printAdvanced(x+12, yPos+1, visual, style)
    
    yPos += 3
  
  # Number examples
  buffer.print(x, yPos, "Numbers in Context:", Style(attrs: {AttrBold}))
  yPos += 1
  
  for i in 3..5:
    let example = examples[i]
    let bidi = processBidiText(example)
    let visual = getVisualText(bidi)
    
    let isRTL = bidi.paragraphDir == RightToLeft
    let style = if isRTL: rtlStyle else: ltrStyle
    
    buffer.print(x, yPos, $i & ". Original: ", Style(attrs: {AttrBold}))
    buffer.printAdvanced(x+12, yPos, example, style)
    
    buffer.print(x, yPos+1, "   Visual: ")
    buffer.printAdvanced(x+12, yPos+1, visual, style)
    
    yPos += 3
  
  # Punctuation examples
  buffer.print(x, yPos, "Punctuation and Special Cases:", Style(attrs: {AttrBold}))
  yPos += 1
  
  for i in 6..9:
    let example = examples[i]
    let bidi = processBidiText(example)
    let visual = getVisualText(bidi)
    
    let isRTL = bidi.paragraphDir == RightToLeft
    let style = if isRTL: rtlStyle else: ltrStyle
    
    buffer.print(x, yPos, $i & ". Original: ", Style(attrs: {AttrBold}))
    buffer.printAdvanced(x+12, yPos, formatWithBidiControls(example), style)
    
    buffer.print(x, yPos+1, "   Visual: ")
    buffer.printAdvanced(x+12, yPos+1, visual, style)
    
    yPos += 3
  
  # Complex examples with controls
  buffer.print(x, yPos, "Explicit Directional Controls:", Style(attrs: {AttrBold}))
  yPos += 1
  
  for i in 10..13:
    let example = examples[i]
    let bidi = processBidiText(example)
    let visual = getVisualText(bidi)
    
    buffer.print(x, yPos, $i & ". Original: ", Style(attrs: {AttrBold}))
    buffer.printAdvanced(x+12, yPos, formatWithBidiControls(example), Style())
    
    buffer.print(x, yPos+1, "   Visual: ")
    buffer.printAdvanced(x+12, yPos+1, visual, Style())
    
    yPos += 3
  
  # Detailed example analysis
  buffer.print(x, yPos, "Detailed Analysis:", Style(attrs: {AttrBold}))
  yPos += 1
  
  # Choose a complex example for detailed analysis
  let detailedExample = "Mixed text with numbers: 123 and العربية with! punctuation."
  renderBidiInfo(buffer, x, yPos, detailedExample, true, true)

# Interactive bidirectional text example
proc interactiveBidirectionalDemo(buffer: var Buffer, x, y: int, width: int, height: int) =
  # Define the input area and result area
  let inputAreaX = x
  let inputAreaY = y
  let inputAreaWidth = width
  let inputAreaHeight = 3
  
  let resultAreaX = x
  let resultAreaY = y + inputAreaHeight + 1
  let resultAreaWidth = width
  let resultAreaHeight = height - inputAreaHeight - 1
  
  # Draw input area border
  for i in 0..<inputAreaWidth+2:
    buffer.print(inputAreaX-1+i, inputAreaY-1, "─")
    buffer.print(inputAreaX-1+i, inputAreaY+inputAreaHeight, "─")
  
  for i in 0..<inputAreaHeight:
    buffer.print(inputAreaX-1, inputAreaY+i, "│")
    buffer.print(inputAreaX+inputAreaWidth, inputAreaY+i, "│")
  
  buffer.print(inputAreaX-1, inputAreaY-1, "┌")
  buffer.print(inputAreaX+inputAreaWidth, inputAreaY-1, "┐")
  buffer.print(inputAreaX-1, inputAreaY+inputAreaHeight, "└")
  buffer.print(inputAreaX+inputAreaWidth, inputAreaY+inputAreaHeight, "┘")
  
  # Draw result area border
  for i in 0..<resultAreaWidth+2:
    buffer.print(resultAreaX-1+i, resultAreaY-1, "─")
    buffer.print(resultAreaX-1+i, resultAreaY+resultAreaHeight, "─")
  
  for i in 0..<resultAreaHeight:
    buffer.print(resultAreaX-1, resultAreaY+i, "│")
    buffer.print(resultAreaX+resultAreaWidth, resultAreaY+i, "│")
  
  buffer.print(resultAreaX-1, resultAreaY-1, "┌")
  buffer.print(resultAreaX+resultAreaWidth, resultAreaY-1, "┐")
  buffer.print(resultAreaX-1, resultAreaY+resultAreaHeight, "└")
  buffer.print(resultAreaX+resultAreaWidth, resultAreaY+resultAreaHeight, "┘")
  
  # Labels
  buffer.print(inputAreaX, inputAreaY-1, " Input Text ")
  buffer.print(resultAreaX, resultAreaY-1, " Bidirectional Analysis ")
  
  # Input instructions
  buffer.print(inputAreaX+2, inputAreaY+1, "Type bidirectional text here (ESC to quit, Ctrl+Enter to analyze)")
  
  # Result placeholder
  buffer.print(resultAreaX+2, resultAreaY+1, "Analysis will appear here after you press Ctrl+Enter")
  
  # Draw buffer
  drawBuffer(buffer)
  
  # Initialize input state
  var inputText = ""
  var cursorPos = 0
  var running = true
  
  # Main loop
  while running:
    # Draw input text
    buffer.print(inputAreaX+2, inputAreaY+1, " ".repeat(inputAreaWidth-4))  # Clear line
    
    # Make sure input text is visible even if longer than width
    let displayStart = max(0, cursorPos - (inputAreaWidth-8))
    let visibleText = inputText.substr(displayStart, displayStart + inputAreaWidth-5)
    
    buffer.print(inputAreaX+2, inputAreaY+1, visibleText)
    
    # Draw cursor
    let cursorX = inputAreaX+2 + (cursorPos - displayStart)
    if cursorX < inputAreaX+inputAreaWidth:
      let cursorChar = if cursorPos < inputText.len: $inputText[cursorPos] else: " "
      buffer.print(cursorX, inputAreaY+1, cursorChar, Style(fg: ColorBlack, bg: ColorWhite))
    
    # Update display
    drawBuffer(buffer)
    
    # Wait for key
    let event = input.pollEvent()
    
    case event.kind:
      of EventKey:
        let key = event.key
        
        # Check for exit
        if key.key == KeyEscape:
          running = false
        
        # Check for analysis
        elif key.key == KeyEnter and key.modifiers.contains(ModCtrl):
          # Clear result area
          for i in 0..<resultAreaHeight-2:
            buffer.print(resultAreaX+2, resultAreaY+1+i, " ".repeat(resultAreaWidth-4))
          
          # Perform and display analysis
          renderBidiInfo(buffer, resultAreaX+2, resultAreaY+1, inputText, true, true)
          drawBuffer(buffer)
        
        # Handle navigation keys
        elif key.key == KeyLeft and cursorPos > 0:
          cursorPos -= 1
        
        elif key.key == KeyRight and cursorPos < inputText.len:
          cursorPos += 1
        
        elif key.key == KeyHome:
          cursorPos = 0
        
        elif key.key == KeyEnd:
          cursorPos = inputText.len
        
        # Handle editing keys
        elif key.key == KeyBackspace and cursorPos > 0:
          # Delete character before cursor
          inputText.delete(cursorPos-1, cursorPos-1)
          cursorPos -= 1
        
        elif key.key == KeyDelete and cursorPos < inputText.len:
          # Delete character at cursor
          inputText.delete(cursorPos, cursorPos)
        
        # Handle character input
        elif key.ch != 0:
          # Insert character at cursor
          inputText.insert($key.ch, cursorPos)
          cursorPos += 1
      
      of EventResize:
        # Handle terminal resize
        let (newWidth, newHeight) = raw.getTerminalSize()
        buffer = newBuffer(newWidth, newHeight)
        
        # Redraw everything
        # (simplified - in a real app, we'd recalculate all dimensions)
        interactiveBidirectionalDemo(buffer, x, y, width, height)
      
      else:
        discard

# Main example procedure
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
    buffer.print(2, 1, "Unicode Bidirectional Algorithm Implementation", titleStyle)
    
    # Description
    buffer.print(2, 3, "Demonstration of bidirectional text handling according to Unicode UAX #9")
    
    # Section styles
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Sections
    buffer.print(2, 5, "1. Bidirectional Display Examples", sectionStyle)
    
    # Display demonstration of bidirectional text
    renderBidirectionalTextDemo(buffer, 4, 7, width - 8)
    
    # Additional section for interactive demo
    buffer.print(2, 45, "2. Interactive Bidirectional Text Demo", sectionStyle)
    buffer.print(4, 47, "Try typing mixed left-to-right and right-to-left text:")
    
    # Interactive bidirectional demo
    interactiveBidirectionalDemo(buffer, 4, 49, width - 8, height - 52)
    
    # Draw buffer
    drawBuffer(buffer)
    
    # Wait for exit
    discard input.pollEvent()

when isMainModule:
  main()