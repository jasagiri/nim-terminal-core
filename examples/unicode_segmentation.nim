# unicode_segmentation.nim
## Unicode Text Segmentation
## 
## This example demonstrates Unicode-aware text segmentation algorithms:
## - Grapheme cluster boundaries (UAX #29)
## - Word boundaries (UAX #29)
## - Sentence boundaries (UAX #29)
## - Line break opportunities (UAX #14)

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/algorithm
import std/sequtils

# Types of segmentation boundaries
type
  BoundaryType = enum
    GraphemeCluster,  # User-perceived character boundaries
    Word,             # Word boundaries
    Sentence,         # Sentence boundaries
    LineBreak         # Line breaking opportunities
    
  WordType = enum
    Unknown,
    Alnum,        # Alphanumeric
    Punctuation,  # Punctuation
    Whitespace,   # Whitespace
    Symbol,       # Symbols
    Number,       # Numbers
    
  SentenceBreakProperty = enum
    SB_Lower,      # Lowercase letter
    SB_Upper,      # Uppercase letter
    SB_OLetter,    # Letter (other)
    SB_Numeric,    # Numeric
    SB_ATerm,      # Sentence terminal (e.g., period)
    SB_STerm,      # Sentence terminal (e.g., question/exclamation)
    SB_Close,      # Closing punctuation
    SB_Sep,        # Separator (CR, LF, PS)
    SB_Sp,         # Whitespace
    SB_ParaSep,    # Paragraph Separator
    SB_Other       # Other
    
  LineBreakProperty = enum
    LB_Mandatory,  # Mandatory break
    LB_Direct,     # Direct break allowed
    LB_Indirect,   # Indirect break opportunity
    LB_Prohibited, # No break allowed
    LB_CJK,        # CJK-specific rules
    LB_Space,      # Space
    LB_Hyphen,     # Hyphen
    LB_Numeric,    # Numeric
    LB_Glue,       # Non-breaking ("glue")
    LB_Other       # Other characters
    
  BreakOpportunity = object
    position: int  # Position in the string (in bytes)
    canBreak: bool # Whether a break is allowed at this position
    property: LineBreakProperty # Property of the character that determines this break
    
  WordSegment = object
    text: string
    startPos: int
    endPos: int
    wordType: WordType
    
  SentenceSegment = object
    text: string
    startPos: int
    endPos: int

# Determine if a grapheme cluster boundary exists between positions
proc isGraphemeClusterBoundary(text: string, pos: int): bool =
  if pos <= 0 or pos >= text.len:
    return true
  
  let runes = text.toRunes
  var runePos = 0
  var bytePos = 0
  
  for i, r in runes:
    let runeBytes = toUTF8(r).len
    bytePos += runeBytes
    
    if bytePos == pos:
      # Check if this is a grapheme cluster boundary
      if i+1 < runes.len:
        # Simple rules for grapheme cluster detection:
        
        # 1. Check if the next character is a combining mark
        if unicode.getCategory(runes[i+1]) in {
          CatMn,  # Mark, nonspacing
          CatMc,  # Mark, spacing combining
          CatMe   # Mark, enclosing
        }:
          return false
          
        # 2. Check for emoji modifiers
        let cp = runes[i+1].int32
        if (cp >= 0x1F3FB and cp <= 0x1F3FF):  # Emoji skin tone modifiers
          return false
          
        # 3. Check for zero-width joiner
        if runes[i+1].int32 == 0x200D:  # Zero-width joiner
          return false
      
      return true
  
  return true

# Get all grapheme cluster boundaries in a string
proc getGraphemeClusterBoundaries(text: string): seq[int] =
  result = @[0]  # Always include start of string
  
  for i in 1..<text.len:
    if isGraphemeClusterBoundary(text, i):
      result.add(i)
      
  if text.len > 0 and result[^1] != text.len:
    result.add(text.len)  # Always include end of string

# Determine if a position is a word boundary
proc isWordBoundary(text: string, pos: int): bool =
  if pos <= 0 or pos >= text.len:
    return true
  
  let runes = text.toRunes
  var runePos = 0
  var bytePos = 0
  
  for i, r in runes:
    let runeBytes = toUTF8(r).len
    bytePos += runeBytes
    
    if bytePos == pos:
      # Simple word boundary rules:
      
      # Check categories of characters on both sides
      let prevAlnum = i > 0 and (isAlpha(runes[i-1]) or isDigit(runes[i-1]))
      let currAlnum = isAlpha(runes[i]) or isDigit(runes[i])
      
      # Different types = boundary
      if prevAlnum != currAlnum:
        return true
        
      # Both are non-alphanumeric, check if either is whitespace or punctuation
      if not prevAlnum and not currAlnum:
        let prevIsSpace = i > 0 and isSpaceAscii($runes[i-1])
        let currIsSpace = isSpaceAscii($runes[i])
        
        # Transition between space and non-space punctuation
        if prevIsSpace != currIsSpace:
          return true
      
      return false
  
  return true

# Get all word boundaries in a string
proc getWordBoundaries(text: string): seq[int] =
  result = @[0]  # Always include start of string
  
  for i in 1..<text.len:
    if isWordBoundary(text, i):
      result.add(i)
      
  if text.len > 0 and result[^1] != text.len:
    result.add(text.len)  # Always include end of string

# Get the type of a word
proc getWordType(text: string): WordType =
  if text.len == 0:
    return Unknown
    
  let firstRune = text[0].Rune
  
  if isSpaceAscii($firstRune):
    return Whitespace
  elif isDigit(firstRune):
    return Number
  elif isAlpha(firstRune):
    return Alnum
  elif firstRune.int32 in {
    '.'.int32, ','.int32, ';'.int32, ':'.int32, '!'.int32, '?'.int32,
    '\''.int32, '"'.int32, '('.int32, ')'.int32, '['.int32, ']'.int32,
    '{'.int32, '}'.int32, '-'.int32, '_'.int32, '/'.int32, '\\'.int32
  }:
    return Punctuation
  elif firstRune.int32 in {
    '+'.int32, '*'.int32, '='.int32, '<'.int32, '>'.int32, '^'.int32,
    '~'.int32, '|'.int32, '$'.int32, '%'.int32, '#'.int32, '@'.int32,
    '&'.int32
  }:
    return Symbol
    
  # Default
  return Unknown

# Get all words in a string
proc getWords(text: string): seq[WordSegment] =
  result = @[]
  
  let boundaries = getWordBoundaries(text)
  if boundaries.len < 2:
    return
    
  # Create word segments from boundaries
  for i in 0..<(boundaries.len-1):
    let start = boundaries[i]
    let finish = boundaries[i+1]
    
    if start != finish:
      let word = text[start..<finish]
      let wordType = getWordType(word)
      
      # Skip whitespace if needed
      if wordType != Whitespace:
        result.add(WordSegment(
          text: word,
          startPos: start,
          endPos: finish,
          wordType: wordType
        ))

# Get the sentence break property of a character
proc getSentenceBreakProperty(r: Rune): SentenceBreakProperty =
  # Simplified mapping of characters to sentence break properties
  if isLower(r):
    return SB_Lower
  elif isUpper(r):
    return SB_Upper
  elif isAlpha(r):
    return SB_OLetter
  elif isDigit(r):
    return SB_Numeric
  elif r.int32 in {'.'.int32, '\u2024'.int32}:  # Period, one dot leader
    return SB_ATerm
  elif r.int32 in {'?'.int32, '!'.int32}:  # Question mark, exclamation mark
    return SB_STerm
  elif r.int32 in {')'.int32, ']'.int32, '}'.int32, '"'.int32, '\''.int32}:  # Closing punctuation
    return SB_Close
  elif r.int32 in {'\r'.int32, '\n'.int32, '\u2029'.int32}:  # CR, LF, paragraph separator
    return SB_Sep
  elif isSpaceAscii($r):
    return SB_Sp
  elif r.int32 == '\u2028'.int32:  # Line separator
    return SB_ParaSep
  else:
    return SB_Other

# Determine if a position is a sentence boundary
proc isSentenceBoundary(text: string, pos: int): bool =
  if pos <= 0 or pos >= text.len:
    return true
  
  let runes = text.toRunes
  var runePos = 0
  var bytePos = 0
  
  for i, r in runes:
    let runeBytes = toUTF8(r).len
    bytePos += runeBytes
    
    if bytePos == pos:
      # Simple sentence boundary rules:
      
      # 1. Check for paragraph separators
      if i > 0 and getSentenceBreakProperty(runes[i-1]) == SB_ParaSep:
        return true
        
      # 2. Check for sentence terminators followed by space
      if i > 0 and (getSentenceBreakProperty(runes[i-1]) in {SB_ATerm, SB_STerm}) and
         getSentenceBreakProperty(runes[i]) == SB_Sp:
        return true
        
      # 3. Check for sentence terminators followed by paragraph separators
      if i > 0 and (getSentenceBreakProperty(runes[i-1]) in {SB_ATerm, SB_STerm}) and
         getSentenceBreakProperty(runes[i]) == SB_ParaSep:
        return true
        
      # 4. Check for sentence terminators followed by uppercase letter
      if i > 0 and (getSentenceBreakProperty(runes[i-1]) in {SB_ATerm, SB_STerm}) and
         getSentenceBreakProperty(runes[i]) == SB_Upper:
        return true
      
      return false
  
  return true

# Get all sentence boundaries in a string
proc getSentenceBoundaries(text: string): seq[int] =
  result = @[0]  # Always include start of string
  
  for i in 1..<text.len:
    if isSentenceBoundary(text, i):
      result.add(i)
      
  if text.len > 0 and result[^1] != text.len:
    result.add(text.len)  # Always include end of string

# Get all sentences in a string
proc getSentences(text: string): seq[SentenceSegment] =
  result = @[]
  
  let boundaries = getSentenceBoundaries(text)
  if boundaries.len < 2:
    return
    
  # Create sentence segments from boundaries
  for i in 0..<(boundaries.len-1):
    let start = boundaries[i]
    let finish = boundaries[i+1]
    
    if start != finish:
      let sentence = text[start..<finish]
      
      result.add(SentenceSegment(
        text: sentence,
        startPos: start,
        endPos: finish
      ))

# Get the line break property of a character
proc getLineBreakProperty(r: Rune): LineBreakProperty =
  # Simplified mapping of characters to line break properties
  let cp = r.int32
  
  if cp in {'\n'.int32, '\r'.int32, '\f'.int32, '\u2028'.int32, '\u2029'.int32}:
    return LB_Mandatory
  elif isSpaceAscii($r):
    return LB_Space
  elif cp == '-'.int32:
    return LB_Hyphen
  elif isDigit(r):
    return LB_Numeric
  elif cp in {'\u00A0'.int32, '\u202F'.int32}:  # NBSP, narrow NBSP
    return LB_Glue
  elif cp >= 0x3000 and cp <= 0x9FFF:  # Rough CJK range
    return LB_CJK
  else:
    return LB_Other

# Determine line break opportunities
proc getLineBreakOpportunities(text: string): seq[BreakOpportunity] =
  result = @[]
  
  if text.len == 0:
    return
    
  # First position is never a break opportunity
  result.add(BreakOpportunity(
    position: 0,
    canBreak: false,
    property: LB_Prohibited
  ))
  
  let runes = text.toRunes
  var runePos = 0
  var bytePos = 0
  
  for i, r in runes:
    let runeBytes = toUTF8(r).len
    bytePos += runeBytes
    
    if i == 0:
      continue  # Already added first position
      
    # Get properties of current and previous characters
    let currProp = getLineBreakProperty(r)
    let prevProp = getLineBreakProperty(runes[i-1])
    
    # Determine if break is allowed
    var canBreak = false
    
    # Simple line break rules:
    
    # 1. Mandatory break
    if currProp == LB_Mandatory:
      canBreak = true
      
    # 2. Space followed by anything except glue
    elif prevProp == LB_Space and currProp != LB_Glue:
      canBreak = true
      
    # 3. Break after hyphen unless followed by numeric
    elif prevProp == LB_Hyphen and currProp != LB_Numeric:
      canBreak = true
      
    # 4. Don't break before or after glue
    elif prevProp == LB_Glue or currProp == LB_Glue:
      canBreak = false
      
    # 5. Break between CJK characters
    elif prevProp == LB_CJK and currProp == LB_CJK:
      canBreak = true
      
    # 6. Don't break between numeric characters
    elif prevProp == LB_Numeric and currProp == LB_Numeric:
      canBreak = false
      
    # Add the break opportunity
    result.add(BreakOpportunity(
      position: bytePos,
      canBreak: canBreak,
      property: currProp
    ))
  
  # Last position is always a break opportunity
  result.add(BreakOpportunity(
    position: text.len,
    canBreak: true,
    property: LB_Mandatory
  ))

# Break text into lines with a maximum width
proc breakLines(text: string, maxWidth: int): seq[string] =
  result = @[]
  
  if text.len == 0:
    return
    
  let breaks = getLineBreakOpportunities(text)
  var start = 0
  var currentWidth = 0
  var lastBreakPos = 0
  
  for i, brk in breaks:
    let segment = text[start..<brk.position]
    let segmentWidth = displayWidth(segment)
    
    if currentWidth + segmentWidth > maxWidth:
      # Need to break line
      if lastBreakPos > start:
        # We have a valid break point
        result.add(text[start..<lastBreakPos])
        start = lastBreakPos
        currentWidth = displayWidth(text[start..<brk.position])
      else:
        # No good break point, force break
        result.add(text[start..<brk.position])
        start = brk.position
        currentWidth = 0
    else:
      currentWidth += segmentWidth
    
    if brk.canBreak:
      lastBreakPos = brk.position
    
    # Handle mandatory breaks
    if brk.property == LB_Mandatory:
      result.add(text[start..<brk.position])
      start = brk.position
      currentWidth = 0
      lastBreakPos = brk.position
  
  # Add remaining text
  if start < text.len:
    result.add(text[start..^1])

# Visualize segmentation boundaries in text
proc visualizeSegmentation(text: string, boundaryType: BoundaryType): string =
  case boundaryType:
    of GraphemeCluster:
      let boundaries = getGraphemeClusterBoundaries(text)
      var result = ""
      
      var lastPos = 0
      for pos in boundaries:
        if pos > 0:
          result.add(text[lastPos..<pos])
          if pos < text.len:
            result.add("·")  # Middle dot to visualize boundary
          lastPos = pos
      
      return result
      
    of Word:
      let words = getWords(text)
      var result = text
      
      # Insert markers around words
      var offset = 0
      for word in words:
        let startPos = word.startPos + offset
        result.insert("[", startPos)
        offset += 1
        
        let endPos = word.endPos + offset
        result.insert("]", endPos)
        offset += 1
      
      return result
      
    of Sentence:
      let sentences = getSentences(text)
      var result = text
      
      # Insert markers around sentences
      var offset = 0
      for sentence in sentences:
        let startPos = sentence.startPos + offset
        result.insert("【", startPos)
        offset += 1
        
        let endPos = sentence.endPos + offset
        result.insert("】", endPos)
        offset += 1
      
      return result
      
    of LineBreak:
      let breaks = getLineBreakOpportunities(text)
      var result = ""
      
      var lastPos = 0
      for brk in breaks:
        if brk.position > lastPos:
          result.add(text[lastPos..<brk.position])
          if brk.canBreak and brk.position < text.len:
            result.add("↲")  # Line break symbol
          lastPos = brk.position
      
      return result

# Demonstrate breaking text into lines based on different scripts
proc demonstrateLineBreaking(buffer: var Buffer, x, y: int, width: int) =
  let examples = @[
    ("English text with some very long words like antidisestablishmentarianism that need to be broken properly.", "English", 30),
    ("This text has explicit soft-hyphen (­) characters to suggest break points to the line breaking algorithm.", "Soft hyphens", 25),
    ("日本語のテキストは単語間にスペースがなく、特殊な規則で改行されます。", "Japanese", 20),
    ("안녕하세요! 한국어 텍스트는 단어 경계가 있지만 다른 규칙을 따릅니다.", "Korean", 15),
    ("العربية تكتب من اليمين إلى اليسار وتحتاج إلى معالجة خاصة أثناء تقسيم النص.", "Arabic", 25),
    ("Смешанный текст with English и цифрами 123-456-789 needs special treatment too.", "Mixed", 20)
  ]
  
  var yPos = y
  
  for example in examples:
    let text = example[0]
    let description = example[1]
    let lineWidth = example[2]
    
    buffer.print(x, yPos, "Text: " & description & " (width: " & $lineWidth & ")")
    yPos += 1
    
    buffer.print(x, yPos, "Original: " & text)
    yPos += 1
    
    buffer.print(x, yPos, "Line breaks:")
    yPos += 1
    
    let lines = breakLines(text, lineWidth)
    for i, line in lines:
      buffer.print(x + 2, yPos, line)
      yPos += 1
      
    # Add ruler to show width
    var ruler = "+"
    for i in 1..lineWidth:
      if i mod 5 == 0:
        ruler.add("|")
      else:
        ruler.add("-")
    
    buffer.print(x + 2, yPos, ruler)
    yPos += 2

# Demonstrate word segmentation with different scripts
proc demonstrateWordSegmentation(buffer: var Buffer, x, y: int) =
  let examples = @[
    ("Hello world! This is a simple English text.", "English"),
    ("日本語のテキストは単語間にスペースがありません。", "Japanese (no spaces between words)"),
    ("Deutsch-Englisch Wörterbuch hat Bindestrich-Wörter.", "German (hyphenated words)"),
    ("L'exemple français a des apostrophes et des accents.", "French (apostrophes)"),
    ("العربية تُكتب من اليمين إلى اليسار.", "Arabic (right-to-left)"),
    ("हिन्दी पाठ में संयुक्त अक्षर होते हैं।", "Hindi (conjuncts)")
  ]
  
  var yPos = y
  
  for example in examples:
    let text = example[0]
    let description = example[1]
    
    buffer.print(x, yPos, "Text: " & description)
    yPos += 1
    
    buffer.print(x, yPos, "Original: " & text)
    yPos += 1
    
    # Get words and display them
    let words = getWords(text)
    
    buffer.print(x, yPos, "Word count: " & $words.len)
    yPos += 1
    
    buffer.print(x, yPos, "Words:")
    yPos += 1
    
    for i, word in words:
      let typeStr = case word.wordType:
        of Alnum: "ALNUM"
        of Punctuation: "PUNCT"
        of Whitespace: "SPACE"
        of Symbol: "SYMBL"
        of Number: "NUMBR"
        else: "OTHER"
      
      buffer.print(x + 2, yPos, "\"" & word.text & "\" (" & typeStr & ")")
      yPos += 1
    
    # Visualize word boundaries
    buffer.print(x, yPos, "Visualization: " & visualizeSegmentation(text, Word))
    yPos += 2

# Demonstrate sentence segmentation
proc demonstrateSentenceSegmentation(buffer: var Buffer, x, y: int) =
  let examples = @[
    ("Hello world! This is a test. Do you like it? I hope so.", "English"),
    ("Dr. Smith visited Washington D.C. yesterday. He had a meeting at 3 P.M.", "Abbreviations"),
    ("「こんにちは。」彼は言いました。「お元気ですか？」", "Japanese"),
    ("Example with "quotes." And another sentence.", "Quotes"),
    ("¿Cómo estás? ¡Muy bien! Gracias.", "Spanish")
  ]
  
  var yPos = y
  
  for example in examples:
    let text = example[0]
    let description = example[1]
    
    buffer.print(x, yPos, "Text: " & description)
    yPos += 1
    
    buffer.print(x, yPos, "Original: " & text)
    yPos += 1
    
    # Get sentences and display them
    let sentences = getSentences(text)
    
    buffer.print(x, yPos, "Sentence count: " & $sentences.len)
    yPos += 1
    
    buffer.print(x, yPos, "Sentences:")
    yPos += 1
    
    for i, sentence in sentences:
      buffer.print(x + 2, yPos, $(i+1) & ". \"" & sentence.text & "\"")
      yPos += 1
    
    # Visualize sentence boundaries
    buffer.print(x, yPos, "Visualization: " & visualizeSegmentation(text, Sentence))
    yPos += 2

# Demonstrate grapheme cluster segmentation
proc demonstrateGraphemeClusterSegmentation(buffer: var Buffer, x, y: int) =
  let examples = @[
    ("café", "Accented character (e + ◌́)"),
    ("नमस्ते", "Devanagari"),
    ("👨‍👩‍👧‍👦", "Family emoji (ZWJ sequence)"),
    ("👍🏽", "Emoji with skin tone modifier"),
    ("a̐e̐i̐o̐u̐", "Latin with multiple combining marks")
  ]
  
  var yPos = y
  
  for example in examples:
    let text = example[0]
    let description = example[1]
    
    buffer.print(x, yPos, "Text: " & description)
    yPos += 1
    
    buffer.print(x, yPos, "Original: " & text)
    yPos += 1
    
    # Show code points
    buffer.print(x, yPos, "Code points:")
    yPos += 1
    
    for i, r in text.toRunes:
      buffer.print(x + 2, yPos, "U+" & toHex(int(r), 4) & " " & $r)
      yPos += 1
    
    # Get grapheme clusters
    let boundaries = getGraphemeClusterBoundaries(text)
    let clusterCount = boundaries.len - 1  # Boundaries include start and end
    
    buffer.print(x, yPos, "Grapheme cluster count: " & $clusterCount)
    yPos += 1
    
    buffer.print(x, yPos, "Clusters:")
    yPos += 1
    
    for i in 0..<(boundaries.len-1):
      let start = boundaries[i]
      let finish = boundaries[i+1]
      
      let cluster = text[start..<finish]
      buffer.print(x + 2, yPos, "\"" & cluster & "\"")
      yPos += 1
    
    # Visualize grapheme cluster boundaries
    buffer.print(x, yPos, "Visualization: " & visualizeSegmentation(text, GraphemeCluster))
    yPos += 2

# Interactive text segmentation demo
proc interactiveSegmentationDemo(buffer: var Buffer, x, y: int, width: int, height: int) =
  # Header
  buffer.print(x, y, "Interactive Text Segmentation Demo:", Style(attrs: {AttrBold}))
  
  # Draw input area
  let inputX = x + 2
  let inputY = y + 2
  
  # Draw text input area
  buffer.print(inputX, inputY, "Enter text: ")
  
  # Draw input box
  # Draw horizontal lines
  for j in 0..<40:
    buffer.print(inputX + 12 + j, inputY, "─")
    buffer.print(inputX + 12 + j, inputY + 1, "─")
  
  # Draw vertical lines
  buffer.print(inputX + 12 - 1, inputY, "┌")
  buffer.print(inputX + 12 - 1, inputY + 1, "└")
  buffer.print(inputX + 12 + 40, inputY, "┐")
  buffer.print(inputX + 12 + 40, inputY + 1, "┘")
  
  # Draw options area
  let optionsY = inputY + 3
  buffer.print(inputX, optionsY, "Segmentation type:")
  
  buffer.print(inputX + 2, optionsY + 1, "(1) Grapheme clusters")
  buffer.print(inputX + 2, optionsY + 2, "(2) Words")
  buffer.print(inputX + 2, optionsY + 3, "(3) Sentences")
  buffer.print(inputX + 2, optionsY + 4, "(4) Line breaks")
  
  # Draw results area
  let resultsY = optionsY + 6
  buffer.print(inputX, resultsY, "Results:", Style(attrs: {AttrBold}))
  
  # Draw initial help text
  buffer.print(inputX + 2, resultsY + 2, "Enter text and select segmentation type")
  buffer.print(inputX, height - 2, "Press ESC to exit")
  
  # Draw buffer initially
  drawBuffer(buffer)
  
  # Set up state for interactive input
  var 
    text = ""
    segmentationType = GraphemeCluster
    running = true
  
  proc updateDisplay() =
    # Clear input field
    for j in 0..<38:
      buffer.print(inputX + 13 + j, inputY, " ")
    
    # Display current text
    buffer.print(inputX + 13, inputY, text)
    
    # Highlight current segmentation type
    let typeStr = case segmentationType:
      of GraphemeCluster: "Grapheme clusters"
      of Word: "Words"
      of Sentence: "Sentences"
      of LineBreak: "Line breaks"
    
    for i in 1..4:
      let y = optionsY + i
      let style = if i-1 == ord(segmentationType): Style(fg: ColorGreen) else: Style()
      
      buffer.print(inputX + 2, y, "(" & $i & ") ", style)
    
    # Clear results area
    for i in 0..<15:
      buffer.print(inputX + 2, resultsY + 2 + i, " ".repeat(width - inputX - 4))
    
    # Process and display results
    if text.len > 0:
      case segmentationType:
        of GraphemeCluster:
          let boundaries = getGraphemeClusterBoundaries(text)
          let clusterCount = boundaries.len - 1
          
          buffer.print(inputX + 2, resultsY + 2, "Grapheme cluster count: " & $clusterCount)
          buffer.print(inputX + 2, resultsY + 3, "Visualization: " & 
                     visualizeSegmentation(text, GraphemeCluster))
          
          # Show individual clusters
          buffer.print(inputX + 2, resultsY + 5, "Individual clusters:")
          
          var yPos = resultsY + 6
          for i in 0..<(boundaries.len-1):
            if i >= 10:  # Limit display to 10 clusters
              buffer.print(inputX + 2, yPos, "... and " & $(clusterCount - i) & " more")
              break
              
            let start = boundaries[i]
            let finish = boundaries[i+1]
            
            let cluster = text[start..<finish]
            buffer.print(inputX + 4, yPos, $(i+1) & ". \"" & cluster & "\"")
            yPos += 1
          
        of Word:
          let words = getWords(text)
          
          buffer.print(inputX + 2, resultsY + 2, "Word count: " & $words.len)
          buffer.print(inputX + 2, resultsY + 3, "Visualization: " & 
                     visualizeSegmentation(text, Word))
          
          # Show individual words
          buffer.print(inputX + 2, resultsY + 5, "Individual words:")
          
          var yPos = resultsY + 6
          for i, word in words:
            if i >= 10:  # Limit display to 10 words
              buffer.print(inputX + 2, yPos, "... and " & $(words.len - i) & " more")
              break
              
            let typeStr = case word.wordType:
              of Alnum: "ALNUM"
              of Punctuation: "PUNCT"
              of Whitespace: "SPACE"
              of Symbol: "SYMBL"
              of Number: "NUMBR"
              else: "OTHER"
            
            buffer.print(inputX + 4, yPos, $(i+1) & ". \"" & word.text & 
                       "\" (" & typeStr & ")")
            yPos += 1
          
        of Sentence:
          let sentences = getSentences(text)
          
          buffer.print(inputX + 2, resultsY + 2, "Sentence count: " & $sentences.len)
          buffer.print(inputX + 2, resultsY + 3, "Visualization: " & 
                     visualizeSegmentation(text, Sentence))
          
          # Show individual sentences
          buffer.print(inputX + 2, resultsY + 5, "Individual sentences:")
          
          var yPos = resultsY + 6
          for i, sentence in sentences:
            if i >= 5:  # Limit display to 5 sentences
              buffer.print(inputX + 2, yPos, "... and " & $(sentences.len - i) & " more")
              break
              
            buffer.print(inputX + 4, yPos, $(i+1) & ". \"" & sentence.text & "\"")
            yPos += 1
          
        of LineBreak:
          let breaks = getLineBreakOpportunities(text)
          let breakCount = breaks.len
          
          buffer.print(inputX + 2, resultsY + 2, "Break opportunity count: " & $breakCount)
          buffer.print(inputX + 2, resultsY + 3, "Visualization: " & 
                     visualizeSegmentation(text, LineBreak))
          
          # Show line breaking
          buffer.print(inputX + 2, resultsY + 5, "Line breaking (width = 30):")
          
          let lines = breakLines(text, 30)
          var yPos = resultsY + 6
          for i, line in lines:
            buffer.print(inputX + 4, yPos, "\"" & line & "\"")
            yPos += 1
    
    # Update display
    drawBuffer(buffer)
  
  # Initial update
  updateDisplay()
  
  # Input handling loop
  while running:
    let event = input.pollEvent()
    
    case event.kind:
      of EventKey:
        let key = event.key
        
        if key.key == KeyEscape:
          running = false
          break
          
        elif key.key == KeyBackspace:
          # Handle backspace
          if text.len > 0:
            text.setLen(max(0, text.len - 1))
          updateDisplay()
          
        elif key.key == KeyEnter:
          # Update display
          updateDisplay()
          
        else:
          # Handle number keys for segmentation type
          if key.ch >= '1'.Rune and key.ch <= '4'.Rune:
            segmentationType = BoundaryType(ord(key.ch) - ord('1'.Rune))
            updateDisplay()
            
          # Add character to text
          elif key.ch != 0:
            let ch = $key.ch
            text.add(ch)
            updateDisplay()
          
      of EventResize:
        # Handle resize event
        let (newWidth, newHeight) = raw.getTerminalSize()
        buffer = newBuffer(newWidth, newHeight)
        clearScreen()
        
        # Redraw everything (simplified)
        interactiveSegmentationDemo(buffer, x, y, newWidth, newHeight)
        
      else:
        discard

proc main() =
  # Initialize the terminal
  withTerminal:
    # Get terminal size
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
    buffer.print(2, 1, "Unicode Text Segmentation", titleStyle)
    
    # Description
    buffer.print(2, 3, "Demonstration of Unicode text segmentation algorithms")
    
    # Section styles
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Section 1: Grapheme cluster segmentation
    buffer.print(2, 5, "1. Grapheme Cluster Segmentation", sectionStyle)
    
    buffer.print(4, 7, "Grapheme clusters are user-perceived characters, which may consist of:")
    buffer.print(4, 8, "- Single code points (e.g., 'a')")
    buffer.print(4, 9, "- Base characters with combining marks (e.g., 'é' = 'e' + '◌́')")
    buffer.print(4, 10, "- Emoji with modifiers (e.g., '👍🏽' = '👍' + '🏽')")
    buffer.print(4, 11, "- ZWJ sequences (e.g., '👨‍👩‍👧‍👦')")
    
    demonstrateGraphemeClusterSegmentation(buffer, 4, 13, width - 8)
    
    # Section 2: Word segmentation
    buffer.print(2, 35, "2. Word Segmentation", sectionStyle)
    
    buffer.print(4, 37, "Word segmentation rules vary by language:")
    buffer.print(4, 38, "- English/Latin: Words separated by spaces or punctuation")
    buffer.print(4, 39, "- CJK languages: No spaces between words, contextual rules apply")
    buffer.print(4, 40, "- Thai/Lao: No spaces between words, dictionary-based approach needed")
    
    demonstrateWordSegmentation(buffer, 4, 42)
    
    # Section 3: Sentence segmentation
    buffer.print(2, 65, "3. Sentence Segmentation", sectionStyle)
    
    buffer.print(4, 67, "Sentence boundary challenges:")
    buffer.print(4, 68, "- Ambiguous punctuation (e.g., period for abbreviations vs. end of sentence)")
    buffer.print(4, 69, "- Quotation marks and parentheses")
    buffer.print(4, 70, "- Language-specific rules")
    
    demonstrateSentenceSegmentation(buffer, 4, 72)
    
    # Section 4: Line breaking
    buffer.print(2, 95, "4. Line Breaking", sectionStyle)
    
    buffer.print(4, 97, "Line breaking considerations:")
    buffer.print(4, 98, "- Natural break opportunities (spaces, hyphens)")
    buffer.print(4, 99, "- Script-specific rules (e.g., CJK can break between characters)")
    buffer.print(4, 100, "- Never break within grapheme clusters")
    buffer.print(4, 101, "- Avoid orphans and widows")
    
    demonstrateLineBreaking(buffer, 4, 103, width - 8)
    
    # Section 5: Interactive demo
    buffer.print(2, 130, "5. Interactive Segmentation Demo", sectionStyle)
    
    buffer.print(4, 132, "Press any key to start the interactive demo, or ESC to exit")
    
    # Draw buffer
    drawBuffer(buffer)
    
    # Wait for key before starting interactive part
    let event = input.pollEvent()
    
    if event.kind != EventKey or event.key.key != KeyEscape:
      clearScreen()
      buffer = newBuffer(width, height)
      interactiveSegmentationDemo(buffer, 2, 5, width - 4, height - 7)

when isMainModule:
  main()