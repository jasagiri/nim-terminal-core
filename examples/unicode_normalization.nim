# unicode_normalization.nim
## Unicode Normalization Forms
## 
## This example demonstrates the four Unicode normalization forms:
## - NFD (Canonical Decomposition)
## - NFC (Canonical Decomposition followed by Canonical Composition)
## - NFKD (Compatibility Decomposition)
## - NFKC (Compatibility Decomposition followed by Canonical Composition)

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/algorithm
import std/sequtils

# Normalization form
type
  NormalizationForm = enum
    NFD,   # Canonical Decomposition
    NFC,   # Canonical Decomposition followed by Canonical Composition
    NFKD,  # Compatibility Decomposition
    NFKC   # Compatibility Decomposition followed by Canonical Composition
    
  DecompositionType = enum
    Canonical,     # NFD/NFC
    Compatibility  # NFKD/NFKC

# Structure to hold decomposition mapping
type
  DecompositionMapping = object
    codePoint: int32
    decomposition: seq[int32]
    type: DecompositionType
    
  CompositionMapping = object
    first: int32
    second: int32
    composed: int32

# Load decomposition mappings (simplified version)
# In reality, this would load from Unicode Character Database
proc loadDecompositionMappings(): seq[DecompositionMapping] =
  result = @[]
  
  # Latin characters with accents (canonical decompositions)
  result.add(DecompositionMapping(
    codePoint: 'á'.int32,  # LATIN SMALL LETTER A WITH ACUTE
    decomposition: @['a'.int32, 0x0301],  # a + COMBINING ACUTE ACCENT
    type: Canonical
  ))
  
  result.add(DecompositionMapping(
    codePoint: 'à'.int32,  # LATIN SMALL LETTER A WITH GRAVE
    decomposition: @['a'.int32, 0x0300],  # a + COMBINING GRAVE ACCENT
    type: Canonical
  ))
  
  result.add(DecompositionMapping(
    codePoint: 'ä'.int32,  # LATIN SMALL LETTER A WITH DIAERESIS
    decomposition: @['a'.int32, 0x0308],  # a + COMBINING DIAERESIS
    type: Canonical
  ))
  
  result.add(DecompositionMapping(
    codePoint: 'â'.int32,  # LATIN SMALL LETTER A WITH CIRCUMFLEX
    decomposition: @['a'.int32, 0x0302],  # a + COMBINING CIRCUMFLEX ACCENT
    type: Canonical
  ))
  
  result.add(DecompositionMapping(
    codePoint: 'ñ'.int32,  # LATIN SMALL LETTER N WITH TILDE
    decomposition: @['n'.int32, 0x0303],  # n + COMBINING TILDE
    type: Canonical
  ))
  
  # Add uppercase versions
  result.add(DecompositionMapping(
    codePoint: 'Á'.int32,  # LATIN CAPITAL LETTER A WITH ACUTE
    decomposition: @['A'.int32, 0x0301],  # A + COMBINING ACUTE ACCENT
    type: Canonical
  ))
  
  result.add(DecompositionMapping(
    codePoint: 'À'.int32,  # LATIN CAPITAL LETTER A WITH GRAVE
    decomposition: @['A'.int32, 0x0300],  # A + COMBINING GRAVE ACCENT
    type: Canonical
  ))
  
  result.add(DecompositionMapping(
    codePoint: 'Ä'.int32,  # LATIN CAPITAL LETTER A WITH DIAERESIS
    decomposition: @['A'.int32, 0x0308],  # A + COMBINING DIAERESIS
    type: Canonical
  ))
  
  result.add(DecompositionMapping(
    codePoint: 'Â'.int32,  # LATIN CAPITAL LETTER A WITH CIRCUMFLEX
    decomposition: @['A'.int32, 0x0302],  # A + COMBINING CIRCUMFLEX ACCENT
    type: Canonical
  ))
  
  result.add(DecompositionMapping(
    codePoint: 'Ñ'.int32,  # LATIN CAPITAL LETTER N WITH TILDE
    decomposition: @['N'.int32, 0x0303],  # N + COMBINING TILDE
    type: Canonical
  ))
  
  # Add some compatibility mappings
  result.add(DecompositionMapping(
    codePoint: 0xFF41,  # FULLWIDTH LATIN SMALL LETTER A
    decomposition: @['a'.int32],
    type: Compatibility
  ))
  
  result.add(DecompositionMapping(
    codePoint: 0x2126,  # OHM SIGN
    decomposition: @['Ω'.int32],  # GREEK CAPITAL LETTER OMEGA
    type: Compatibility
  ))
  
  result.add(DecompositionMapping(
    codePoint: 0x2460,  # CIRCLED DIGIT ONE
    decomposition: @['1'.int32],
    type: Compatibility
  ))
  
  result.add(DecompositionMapping(
    codePoint: 0x00BD,  # VULGAR FRACTION ONE HALF
    decomposition: @['1'.int32, '/'.int32, '2'.int32],
    type: Compatibility
  ))
  
  result.add(DecompositionMapping(
    codePoint: 0x2122,  # TRADE MARK SIGN
    decomposition: @['T'.int32, 'M'.int32],
    type: Compatibility
  ))
  
  return result

# Create a table for quick lookup of decomposition mappings
proc createDecompositionTable(mappings: seq[DecompositionMapping]): 
    Table[int32, (seq[int32], DecompositionType)] =
  var table = initTable[int32, (seq[int32], DecompositionType)]()
  
  for mapping in mappings:
    table[mapping.codePoint] = (mapping.decomposition, mapping.type)
  
  return table

# Create composition mappings from decomposition mappings
proc createCompositionMappings(mappings: seq[DecompositionMapping]): seq[CompositionMapping] =
  result = @[]
  
  for mapping in mappings:
    # Only canonical decompositions can be recomposed
    if mapping.type == Canonical and mapping.decomposition.len == 2:
      result.add(CompositionMapping(
        first: mapping.decomposition[0],
        second: mapping.decomposition[1],
        composed: mapping.codePoint
      ))
  
  return result

# Create a table for quick lookup of composition mappings
proc createCompositionTable(mappings: seq[CompositionMapping]): 
    Table[(int32, int32), int32] =
  var table = initTable[(int32, int32), int32]()
  
  for mapping in mappings:
    table[(mapping.first, mapping.second)] = mapping.composed
  
  return table

# Apply canonical decomposition
proc canonicalDecompose(text: string, decompositionTable: Table[int32, (seq[int32], DecompositionType)]): seq[Rune] =
  var result: seq[Rune] = @[]
  
  for r in text.toRunes:
    let cp = r.int32
    
    if decompositionTable.hasKey(cp) and decompositionTable[cp][1] == Canonical:
      # This character has a canonical decomposition
      let decomposition = decompositionTable[cp][0]
      
      # Recursively decompose each element
      for d in decomposition:
        let dRune = d.Rune
        let subDecomposed = canonicalDecompose($dRune, decompositionTable)
        result.add(subDecomposed)
    else:
      # No decomposition, add as is
      result.add(r)
  
  return result

# Apply compatibility decomposition
proc compatibilityDecompose(text: string, decompositionTable: Table[int32, (seq[int32], DecompositionType)]): seq[Rune] =
  var result: seq[Rune] = @[]
  
  for r in text.toRunes:
    let cp = r.int32
    
    if decompositionTable.hasKey(cp):
      # This character has a decomposition (canonical or compatibility)
      let decomposition = decompositionTable[cp][0]
      
      # Recursively decompose each element
      for d in decomposition:
        let dRune = d.Rune
        let subDecomposed = compatibilityDecompose($dRune, decompositionTable)
        result.add(subDecomposed)
    else:
      # No decomposition, add as is
      result.add(r)
  
  return result

# Sort combining marks according to canonical ordering
proc sortCombiningMarks(chars: seq[Rune]): seq[Rune] =
  # Simplified version that assumes everything is sorted correctly
  # In reality, would sort by canonical combining class
  return chars

# Apply canonical composition
proc canonicalCompose(chars: seq[Rune], compositionTable: Table[(int32, int32), int32]): seq[Rune] =
  if chars.len <= 1:
    return chars
  
  var result: seq[Rune] = @[]
  var starterPos = 0
  
  while starterPos < chars.len:
    result.add(chars[starterPos])
    var composed = false
    
    # Try to compose this character with the next
    if starterPos + 1 < chars.len:
      let pair = (chars[starterPos].int32, chars[starterPos+1].int32)
      
      if compositionTable.hasKey(pair):
        # These two characters can be composed
        let composedChar = compositionTable[pair].Rune
        result[result.high] = composedChar
        starterPos += 2
        composed = true
    
    if not composed:
      starterPos += 1
  
  return result

# Apply normalization to text
proc normalize(text: string, form: NormalizationForm, 
              decompositionTable: Table[int32, (seq[int32], DecompositionType)],
              compositionTable: Table[(int32, int32), int32]): string =
  var result: seq[Rune]
  
  case form:
    of NFD:
      # Canonical decomposition
      result = canonicalDecompose(text, decompositionTable)
      # Sort by canonical combining class
      result = sortCombiningMarks(result)
      
    of NFC:
      # Canonical decomposition
      result = canonicalDecompose(text, decompositionTable)
      # Sort by canonical combining class
      result = sortCombiningMarks(result)
      # Canonical composition
      result = canonicalCompose(result, compositionTable)
      
    of NFKD:
      # Compatibility decomposition
      result = compatibilityDecompose(text, decompositionTable)
      # Sort by canonical combining class
      result = sortCombiningMarks(result)
      
    of NFKC:
      # Compatibility decomposition
      result = compatibilityDecompose(text, decompositionTable)
      # Sort by canonical combining class
      result = sortCombiningMarks(result)
      # Canonical composition
      result = canonicalCompose(result, compositionTable)
  
  # Convert back to string
  var strResult = ""
  for r in result:
    strResult.add(toUTF8(r))
  
  return strResult

# Analyze normalization of a string
proc analyzeNormalization(text: string, 
                         decompositionTable: Table[int32, (seq[int32], DecompositionType)],
                         compositionTable: Table[(int32, int32), int32]): tuple[nfd, nfc, nfkd, nfkc: string] =
  # Normalize to all forms
  let nfd = normalize(text, NFD, decompositionTable, compositionTable)
  let nfc = normalize(text, NFC, decompositionTable, compositionTable)
  let nfkd = normalize(text, NFKD, decompositionTable, compositionTable)
  let nfkc = normalize(text, NFKC, decompositionTable, compositionTable)
  
  return (nfd, nfc, nfkd, nfkc)

# Format code points for display
proc formatCodePoints(text: string): string =
  var result = ""
  
  for r in text.toRunes:
    if result.len > 0:
      result.add(" ")
    result.add("U+" & toHex(int(r), 4))
  
  return result

# Demonstrate canonical equivalence
proc demonstrateCanonicalEquivalence(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Canonical Equivalence Examples:", Style(attrs: {AttrBold}))
  
  # Load decomposition mappings
  let decompositionMappings = loadDecompositionMappings()
  let decompositionTable = createDecompositionTable(decompositionMappings)
  let compositionMappings = createCompositionMappings(decompositionMappings)
  let compositionTable = createCompositionTable(compositionMappings)
  
  let examples = @[
    ("é", "e\u0301", "Precomposed vs. decomposed"),
    ("ñ", "n\u0303", "Precomposed vs. decomposed"),
    ("Å", "A\u030A", "Precomposed vs. decomposed"),
    ("한글", "\u1112\u1161\u11AB\u1100\u1173\u11AF", "Hangul syllables")
  ]
  
  var yPos = y + 1
  
  for i, example in examples:
    let form1 = example[0]
    let form2 = example[1]
    let description = example[2]
    
    buffer.print(x, yPos, "Example " & $(i+1) & ": " & description)
    yPos += 1
    
    buffer.print(x + 2, yPos, "Form 1: \"" & form1 & "\" (" & formatCodePoints(form1) & ")")
    yPos += 1
    
    buffer.print(x + 2, yPos, "Form 2: \"" & form2 & "\" (" & formatCodePoints(form2) & ")")
    yPos += 1
    
    # Normalize both forms
    let norm1 = analyzeNormalization(form1, decompositionTable, compositionTable)
    let norm2 = analyzeNormalization(form2, decompositionTable, compositionTable)
    
    # Check equivalence
    let nfdEquivalent = norm1.nfd == norm2.nfd
    let nfcEquivalent = norm1.nfc == norm2.nfc
    
    let equivalenceStyle = if nfdEquivalent and nfcEquivalent: 
                            Style(fg: ColorGreen)
                          else: 
                            Style(fg: ColorRed)
    
    buffer.print(x + 2, yPos, "Canonically equivalent: " & 
                (if nfdEquivalent and nfcEquivalent: "Yes" else: "No"), equivalenceStyle)
    yPos += 1
    
    # Show normalized forms
    buffer.print(x + 2, yPos, "NFD Form 1: " & formatCodePoints(norm1.nfd))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFD Form 2: " & formatCodePoints(norm2.nfd))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFC Form 1: " & formatCodePoints(norm1.nfc))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFC Form 2: " & formatCodePoints(norm2.nfc))
    yPos += 2
  
  return

# Demonstrate compatibility equivalence
proc demonstrateCompatibilityEquivalence(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Compatibility Equivalence Examples:", Style(attrs: {AttrBold}))
  
  # Load decomposition mappings
  let decompositionMappings = loadDecompositionMappings()
  let decompositionTable = createDecompositionTable(decompositionMappings)
  let compositionMappings = createCompositionMappings(decompositionMappings)
  let compositionTable = createCompositionTable(compositionMappings)
  
  let examples = @[
    ("ℌ", "H", "Mathematical script H vs. H"),
    ("①", "1", "Circled digit vs. digit"),
    ("ｔｅｘｔ", "text", "Fullwidth vs. normal width"),
    ("½", "1/2", "Fraction vs. sequence")
  ]
  
  var yPos = y + 1
  
  for i, example in examples:
    let form1 = example[0]
    let form2 = example[1]
    let description = example[2]
    
    buffer.print(x, yPos, "Example " & $(i+1) & ": " & description)
    yPos += 1
    
    buffer.print(x + 2, yPos, "Form 1: \"" & form1 & "\" (" & formatCodePoints(form1) & ")")
    yPos += 1
    
    buffer.print(x + 2, yPos, "Form 2: \"" & form2 & "\" (" & formatCodePoints(form2) & ")")
    yPos += 1
    
    # Normalize both forms
    let norm1 = analyzeNormalization(form1, decompositionTable, compositionTable)
    let norm2 = analyzeNormalization(form2, decompositionTable, compositionTable)
    
    # Check equivalence
    let nfkdEquivalent = norm1.nfkd == norm2.nfkd
    let nfkcEquivalent = norm1.nfkc == norm2.nfkc
    
    let equivalenceStyle = if nfkdEquivalent or nfkcEquivalent: 
                            Style(fg: ColorGreen)
                          else: 
                            Style(fg: ColorRed)
    
    buffer.print(x + 2, yPos, "Compatibility equivalent: " & 
                (if nfkdEquivalent or nfkcEquivalent: "Yes" else: "No"), equivalenceStyle)
    yPos += 1
    
    # Show normalized forms
    buffer.print(x + 2, yPos, "NFKD Form 1: " & formatCodePoints(norm1.nfkd))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFKD Form 2: " & formatCodePoints(norm2.nfkd))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFKC Form 1: " & formatCodePoints(norm1.nfkc))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFKC Form 2: " & formatCodePoints(norm2.nfkc))
    yPos += 2
  
  return

# Demonstrate normalization forms
proc demonstrateNormalizationForms(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Normalization Forms Examples:", Style(attrs: {AttrBold}))
  
  # Load decomposition mappings
  let decompositionMappings = loadDecompositionMappings()
  let decompositionTable = createDecompositionTable(decompositionMappings)
  let compositionMappings = createCompositionMappings(decompositionMappings)
  let compositionTable = createCompositionTable(compositionMappings)
  
  let examples = @[
    "café",
    "Héllo Wörld",
    "①⒉₃",
    "Z͑ͫ̓ͪ̂ͫ̽͏̴̙̤̞͉͚̯̞̠͍A̴̵̜̰͔ͫ͗͢L̠ͨͧͩ͘G̴̻͈͍͔̹̑͗̎̅͛́Ǫ̵̹̻̝̳͂̌̌͘",
    "จะประชุม"
  ]
  
  var yPos = y + 1
  
  for i, example in examples:
    buffer.print(x, yPos, "Example " & $(i+1) & ": \"" & example & "\"")
    yPos += 1
    
    buffer.print(x + 2, yPos, "Original: " & formatCodePoints(example))
    yPos += 1
    
    # Apply all normalization forms
    let forms = analyzeNormalization(example, decompositionTable, compositionTable)
    
    buffer.print(x + 2, yPos, "NFD: " & formatCodePoints(forms.nfd))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFC: " & formatCodePoints(forms.nfc))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFKD: " & formatCodePoints(forms.nfkd))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFKC: " & formatCodePoints(forms.nfkc))
    yPos += 2
  
  return

# Demonstrate normalization applications
proc demonstrateNormalizationApplications(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Normalization Applications:", Style(attrs: {AttrBold}))
  
  # Load decomposition mappings
  let decompositionMappings = loadDecompositionMappings()
  let decompositionTable = createDecompositionTable(decompositionMappings)
  let compositionMappings = createCompositionMappings(decompositionMappings)
  let compositionTable = createCompositionTable(compositionMappings)
  
  let applications = @[
    ("String Comparison", "Resume", "Résumé", "Converting to NFC before comparison can handle accents"),
    ("User Input", "cafè", "café", "Normalizing to NFC provides consistent storage"),
    ("Search", "Cafe", "Café", "Using NFD allows accent-insensitive searching"),
    ("Identifiers", "𝕏", "X", "Using NFKC prevents spoofing with mathematical symbols")
  ]
  
  var yPos = y + 1
  
  for app in applications:
    let title = app[0]
    let input1 = app[1]
    let input2 = app[2]
    let description = app[3]
    
    buffer.print(x, yPos, title & ":", Style(attrs: {AttrBold}))
    yPos += 1
    
    buffer.print(x + 2, yPos, "Input 1: \"" & input1 & "\"")
    yPos += 1
    
    buffer.print(x + 2, yPos, "Input 2: \"" & input2 & "\"")
    yPos += 1
    
    let forms1 = analyzeNormalization(input1, decompositionTable, compositionTable)
    let forms2 = analyzeNormalization(input2, decompositionTable, compositionTable)
    
    buffer.print(x + 2, yPos, "NFC Comparison: " & 
                (if forms1.nfc == forms2.nfc: "Match" else: "No Match"))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFD Comparison: " & 
                (if forms1.nfd == forms2.nfd: "Match" else: "No Match"))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFKC Comparison: " & 
                (if forms1.nfkc == forms2.nfkc: "Match" else: "No Match"))
    yPos += 1
    
    buffer.print(x + 2, yPos, "NFKD Comparison: " & 
                (if forms1.nfkd == forms2.nfkd: "Match" else: "No Match"))
    yPos += 1
    
    buffer.print(x + 2, yPos, "Application: " & description)
    yPos += 2
  
  return

# Interactive normalization analyzer
proc interactiveNormalizationAnalyzer(buffer: var Buffer, x, y: int, width: int, height: int) =
  # Header
  buffer.print(x, y, "Interactive Unicode Normalization Analyzer:", Style(attrs: {AttrBold}))
  
  # Load decomposition mappings
  let decompositionMappings = loadDecompositionMappings()
  let decompositionTable = createDecompositionTable(decompositionMappings)
  let compositionMappings = createCompositionMappings(decompositionMappings)
  let compositionTable = createCompositionTable(compositionMappings)
  
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
  
  # Draw results area
  let resultsY = inputY + 3
  buffer.print(inputX, resultsY, "Normalization Analysis:", Style(attrs: {AttrBold}))
  
  # Draw initial help text
  buffer.print(inputX + 2, resultsY + 2, "Enter text to analyze its normalization forms")
  buffer.print(inputX, height - 2, "Press ESC to exit")
  
  # Draw buffer initially
  drawBuffer(buffer)
  
  # Set up state for interactive input
  var 
    text = ""
    running = true
  
  proc updateDisplay() =
    # Clear input field
    for j in 0..<38:
      buffer.print(inputX + 13 + j, inputY, " ")
    
    # Display current text
    buffer.print(inputX + 13, inputY, text)
    
    # Clear results area
    for i in 0..<20:
      buffer.print(inputX + 2, resultsY + 2 + i, " ".repeat(width - inputX - 4))
    
    # Process and display results
    if text.len > 0:
      buffer.print(inputX + 2, resultsY + 2, "Original text: \"" & text & "\"")
      buffer.print(inputX + 2, resultsY + 3, "Code points: " & formatCodePoints(text))
      
      # Apply normalization
      let forms = analyzeNormalization(text, decompositionTable, compositionTable)
      
      buffer.print(inputX + 2, resultsY + 5, "NFD (Canonical Decomposition):")
      buffer.print(inputX + 4, resultsY + 6, "\"" & forms.nfd & "\"")
      buffer.print(inputX + 4, resultsY + 7, "Code points: " & formatCodePoints(forms.nfd))
      
      buffer.print(inputX + 2, resultsY + 9, "NFC (Canonical Composition):")
      buffer.print(inputX + 4, resultsY + 10, "\"" & forms.nfc & "\"")
      buffer.print(inputX + 4, resultsY + 11, "Code points: " & formatCodePoints(forms.nfc))
      
      buffer.print(inputX + 2, resultsY + 13, "NFKD (Compatibility Decomposition):")
      buffer.print(inputX + 4, resultsY + 14, "\"" & forms.nfkd & "\"")
      buffer.print(inputX + 4, resultsY + 15, "Code points: " & formatCodePoints(forms.nfkd))
      
      buffer.print(inputX + 2, resultsY + 17, "NFKC (Compatibility Composition):")
      buffer.print(inputX + 4, resultsY + 18, "\"" & forms.nfkc & "\"")
      buffer.print(inputX + 4, resultsY + 19, "Code points: " & formatCodePoints(forms.nfkc))
      
      # Show form equivalence
      if forms.nfd == forms.nfc:
        buffer.print(inputX + 2, resultsY + 21, "Note: Text is already in canonical normal form")
      
      if forms.nfkd == forms.nfkc:
        buffer.print(inputX + 2, resultsY + 22, "Note: Text is already in compatibility normal form")
      
      if forms.nfd == text:
        buffer.print(inputX + 2, resultsY + 23, "Note: Text is already in NFD form")
      
      if forms.nfc == text:
        buffer.print(inputX + 2, resultsY + 23, "Note: Text is already in NFC form")
      
      if forms.nfkd == text:
        buffer.print(inputX + 2, resultsY + 24, "Note: Text is already in NFKD form")
      
      if forms.nfkc == text:
        buffer.print(inputX + 2, resultsY + 24, "Note: Text is already in NFKC form")
    
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
          # Add character to text
          if key.ch != 0:
            let ch = $key.ch
            text.add(ch)
            updateDisplay()
          
      of EventResize:
        # Handle resize event
        let (newWidth, newHeight) = raw.getTerminalSize()
        buffer = newBuffer(newWidth, newHeight)
        clearScreen()
        
        # Redraw everything (simplified)
        interactiveNormalizationAnalyzer(buffer, x, y, newWidth, newHeight)
        
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
    buffer.print(2, 1, "Unicode Normalization Forms", titleStyle)
    
    # Description
    buffer.print(2, 3, "Demonstration of the four Unicode normalization forms and their uses")
    
    # Section styles
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Section 1: Normalization forms
    buffer.print(2, 5, "1. Unicode Normalization Forms", sectionStyle)
    
    buffer.print(4, 7, "The four normalization forms:")
    buffer.print(4, 8, "- NFD: Canonical Decomposition")
    buffer.print(4, 9, "- NFC: Canonical Decomposition followed by Canonical Composition")
    buffer.print(4, 10, "- NFKD: Compatibility Decomposition")
    buffer.print(4, 11, "- NFKC: Compatibility Decomposition followed by Canonical Composition")
    
    demonstrateNormalizationForms(buffer, 4, 13)
    
    # Section 2: Canonical equivalence
    buffer.print(2, 40, "2. Canonical Equivalence", sectionStyle)
    
    buffer.print(4, 42, "Canonical equivalence means characters represent the same abstract character:")
    buffer.print(4, 43, "- Precomposed characters vs. base + combining mark")
    buffer.print(4, 44, "- Different sequences of combining marks")
    buffer.print(4, 45, "- Different encoding of the same character")
    
    demonstrateCanonicalEquivalence(buffer, 4, 47)
    
    # Section 3: Compatibility equivalence
    buffer.print(2, 65, "3. Compatibility Equivalence", sectionStyle)
    
    buffer.print(4, 67, "Compatibility equivalence includes canonical equivalence plus:")
    buffer.print(4, 68, "- Font variants (fullwidth/halfwidth forms)")
    buffer.print(4, 69, "- Positional variants (initial/final forms)")
    buffer.print(4, 70, "- Circled/superscript/subscript forms")
    buffer.print(4, 71, "- Other formatting differences")
    
    demonstrateCompatibilityEquivalence(buffer, 4, 73)
    
    # Section 4: Normalization applications
    buffer.print(2, 95, "4. Practical Applications", sectionStyle)
    
    buffer.print(4, 97, "Practical applications of normalization:")
    buffer.print(4, 98, "- String comparison and sorting")
    buffer.print(4, 99, "- Case-insensitive and accent-insensitive searching")
    buffer.print(4, 100, "- Security (preventing spoofing)")
    buffer.print(4, 101, "- Consistent data storage")
    
    demonstrateNormalizationApplications(buffer, 4, 103)
    
    # Section 5: Interactive analyzer
    buffer.print(2, 130, "5. Interactive Normalization Analyzer", sectionStyle)
    
    buffer.print(4, 132, "Press any key to start the interactive analyzer, or ESC to exit")
    
    # Draw buffer
    drawBuffer(buffer)
    
    # Wait for key before starting interactive part
    let event = input.pollEvent()
    
    if event.kind != EventKey or event.key.key != KeyEscape:
      clearScreen()
      buffer = newBuffer(width, height)
      interactiveNormalizationAnalyzer(buffer, 2, 5, width - 4, height - 7)

when isMainModule:
  main()