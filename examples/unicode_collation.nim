# unicode_collation.nim
## Unicode Collation Algorithm Implementation
##
## This example demonstrates the Unicode Collation Algorithm (UCA)
## for linguistically correct string comparison and sorting across
## different languages and scripts.

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/algorithm
import std/sequtils
import std/times

type
  CollationLevel = enum
    Primary = 1,   # Base character differences (e.g., 'a' vs 'b')
    Secondary = 2, # Accent differences (e.g., 'a' vs 'á') 
    Tertiary = 3,  # Case differences (e.g., 'a' vs 'A')
    Quaternary = 4 # Punctuation differences and other distinctions
    
  CollationElement = object
    primary: uint32
    secondary: uint16
    tertiary: uint16
    quaternary: uint16
    
  CollationKey = object
    elements: seq[CollationElement]
    
  CollationOptions = object
    strength: CollationLevel           # Comparison level
    caseFirst: CaseFirstOption         # Whether uppercase sorts first
    ignorePunctuation: bool            # Whether to ignore punctuation
    numericOrdering: bool              # Whether to sort numbers numerically
    locale: string                     # Locale identifier (e.g., "en", "fr", "ja")
    
  CaseFirstOption = enum
    CaseFirstUpper,    # Uppercase sorts before lowercase
    CaseFirstLower,    # Lowercase sorts before uppercase
    CaseFirstOff       # No special case handling
    
  CollatorImpl = object
    options: CollationOptions
    weightTable: Table[Rune, seq[CollationElement]]
    locale: string
    tailoringRules: Table[string, string]  # Locale-specific tailoring rules

# Simple collation weight data structure for demonstration
# In a real implementation, this would be loaded from the CLDR/ICU data files
proc initWeightTable(): Table[Rune, seq[CollationElement]] =
  result = initTable[Rune, seq[CollationElement]]()
  
  # Basic Latin weights
  # Simplified weights for demonstration - real weights would be derived from DUCET
  var weight: uint32 = 0x1000  # Starting weight for Latin
  for c in 'a'..'z':
    let r = c.Rune
    var element = CollationElement(
      primary: weight,
      secondary: 0x0020, # Default secondary weight
      tertiary: 0x0002,  # Lowercase tertiary weight
      quaternary: 0
    )
    result[r] = @[element]
    weight += 0x0010  # Increment by 16 for each letter
  
  # Uppercase Latin
  weight = 0x1000  # Reset to same as lowercase
  for c in 'A'..'Z':
    let r = c.Rune
    var element = CollationElement(
      primary: weight,
      secondary: 0x0020, # Same secondary weight as lowercase
      tertiary: 0x0008,  # Uppercase tertiary weight (higher than lowercase)
      quaternary: 0
    )
    result[r] = @[element]
    weight += 0x0010
  
  # Latin accented characters
  # Each accented character has the same primary weight as its base letter,
  # but a higher secondary weight to distinguish accents
  let accentedChars = {
    'á'.Rune: ('a'.Rune, 0x0040'u16), 'à'.Rune: ('a'.Rune, 0x0050'u16),
    'é'.Rune: ('e'.Rune, 0x0040'u16), 'è'.Rune: ('e'.Rune, 0x0050'u16),
    'í'.Rune: ('i'.Rune, 0x0040'u16), 'ì'.Rune: ('i'.Rune, 0x0050'u16),
    'ó'.Rune: ('o'.Rune, 0x0040'u16), 'ò'.Rune: ('o'.Rune, 0x0050'u16),
    'ú'.Rune: ('u'.Rune, 0x0040'u16), 'ù'.Rune: ('u'.Rune, 0x0050'u16),
    'ñ'.Rune: ('n'.Rune, 0x0060'u16), 'ö'.Rune: ('o'.Rune, 0x0070'u16),
    'Á'.Rune: ('A'.Rune, 0x0040'u16), 'À'.Rune: ('A'.Rune, 0x0050'u16),
    'É'.Rune: ('E'.Rune, 0x0040'u16), 'È'.Rune: ('E'.Rune, 0x0050'u16),
    'ç'.Rune: ('c'.Rune, 0x0080'u16), 'Ç'.Rune: ('C'.Rune, 0x0080'u16)
  }
  
  for accent, data in accentedChars.pairs:
    let baseChar = data[0]
    let secondaryWeight = data[1]
    let baseElement = result[baseChar][0]
    
    var element = CollationElement(
      primary: baseElement.primary,
      secondary: secondaryWeight,
      tertiary: baseElement.tertiary,  # Preserve case
      quaternary: 0
    )
    result[accent] = @[element]
  
  # Digits
  weight = 0x0300  # Weight for digits
  for c in '0'..'9':
    let r = c.Rune
    var element = CollationElement(
      primary: weight,
      secondary: 0x0020,
      tertiary: 0x0002,
      quaternary: 0
    )
    result[r] = @[element]
    weight += 0x0010
  
  # Punctuation and symbols
  let punctuation = {
    ' '.Rune: 0x0200'u32, ','.Rune: 0x0205'u32, '.'.Rune: 0x0210'u32,
    ';'.Rune: 0x0215'u32, ':'.Rune: 0x0220'u32, '!'.Rune: 0x0225'u32,
    '?'.Rune: 0x0230'u32, '\''.Rune: 0x0235'u32, '"'.Rune: 0x0240'u32,
    '('.Rune: 0x0245'u32, ')'.Rune: 0x0250'u32, '['.Rune: 0x0255'u32,
    ']'.Rune: 0x0260'u32, '{'.Rune: 0x0265'u32, '}'.Rune: 0x0270'u32,
    '-'.Rune: 0x0275'u32, '_'.Rune: 0x0280'u32, '/'.Rune: 0x0285'u32,
    '\\'.Rune: 0x0290'u32, '@'.Rune: 0x0295'u32, '#'.Rune: 0x0300'u32,
    '$'.Rune: 0x0305'u32, '%'.Rune: 0x0310'u32, '&'.Rune: 0x0315'u32,
    '*'.Rune: 0x0320'u32, '+'.Rune: 0x0325'u32, '='.Rune: 0x0330'u32,
    '<'.Rune: 0x0335'u32, '>'.Rune: 0x0340'u32, '^'.Rune: 0x0345'u32,
    '~'.Rune: 0x0350'u32, '|'.Rune: 0x0355'u32, '`'.Rune: 0x0360'u32
  }
  
  for p, w in punctuation.pairs:
    var element = CollationElement(
      primary: w,
      secondary: 0x0020,
      tertiary: 0x0002,
      quaternary: 0x0001  # Punctuation gets a quaternary weight
    )
    result[p] = @[element]
  
  # Simple CJK weights (very simplified)
  let cjkChars = {
    '你'.Rune: 0x8000'u32, '好'.Rune: 0x8010'u32, '世'.Rune: 0x8020'u32,
    '界'.Rune: 0x8030'u32, '中'.Rune: 0x8040'u32, '文'.Rune: 0x8050'u32,
    '日'.Rune: 0x8060'u32, '本'.Rune: 0x8070'u32, '語'.Rune: 0x8080'u32,
    '한'.Rune: 0x8090'u32, '국'.Rune: 0x80A0'u32, '어'.Rune: 0x80B0'u32
  }
  
  for c, w in cjkChars.pairs:
    var element = CollationElement(
      primary: w,
      secondary: 0x0020,
      tertiary: 0x0002,
      quaternary: 0
    )
    result[c] = @[element]
  
  # Arabic/Hebrew (simplified)
  let rtlChars = {
    'أ'.Rune: 0x9000'u32, 'ب'.Rune: 0x9010'u32, 'ت'.Rune: 0x9020'u32,
    'ث'.Rune: 0x9030'u32, 'ج'.Rune: 0x9040'u32, 'ح'.Rune: 0x9050'u32,
    'א'.Rune: 0x9500'u32, 'ב'.Rune: 0x9510'u32, 'ג'.Rune: 0x9520'u32,
    'ד'.Rune: 0x9530'u32, 'ה'.Rune: 0x9540'u32, 'ו'.Rune: 0x9550'u32
  }
  
  for c, w in rtlChars.pairs:
    var element = CollationElement(
      primary: w,
      secondary: 0x0020,
      tertiary: 0x0002,
      quaternary: 0
    )
    result[c] = @[element]
  
  return result

# Initialize locale-specific tailoring rules
proc initTailoringRules(): Table[string, string] =
  result = initTable[string, string]()
  
  # Spanish sorting ("ch" and "ll" traditionally treated as separate letters)
  result["es"] = """
# Spanish tailoring rules
# ch sorts after c
&c<ch<<<Ch<<<CH
# ll sorts after l
&l<ll<<<Ll<<<LL
# ñ sorts after n
&n<ñ<<<Ñ
"""

  # German sorting (ä, ö, ü after a, o, u respectively)
  result["de"] = """
# German tailoring rules
# ä sorts with ae
&ae<<ä<<<Ä
# ö sorts with oe
&oe<<ö<<<Ö
# ü sorts with ue
&ue<<ü<<<Ü
# ß sorts as ss
&ss<<ß
"""

  # Swedish sorting (å, ä, ö at end of alphabet)
  result["sv"] = """
# Swedish tailoring rules
# z is followed by å, ä, ö
&z<å<<<Å<ä<<<Ä<ö<<<Ö
"""

  # French sorting (accents sorted from back to front in reverse order)
  result["fr"] = """
# French tailoring rules
# accented characters are compared from right to left
&a<à<<<À<â<<<Â<ä<<<Ä<æ<<<Æ
&e<é<<<É<è<<<È<ê<<<Ê<ë<<<Ë<œ<<<Œ
&i<î<<<Î<ï<<<Ï
&o<ô<<<Ô<ö<<<Ö
&u<ù<<<Ù<û<<<Û<ü<<<Ü
&c<ç<<<Ç
"""

  return result

# Create a collator with specific options
proc newCollator(options: CollationOptions = CollationOptions()): CollatorImpl =
  var collator = CollatorImpl()
  
  # Set default options if not specified
  collator.options = options
  if collator.options.strength == CollationLevel(0):
    collator.options.strength = Tertiary
  if collator.options.locale == "":
    collator.options.locale = "en"
    
  # Load weight table
  collator.weightTable = initWeightTable()
  
  # Load tailoring rules
  collator.tailoringRules = initTailoringRules()
  
  return collator

# Generate a collation key for a string
proc getCollationKey(collator: CollatorImpl, s: string): CollationKey =
  result = CollationKey(elements: @[])
  let runes = s.toRunes
  
  for r in runes:
    # Handle unassigned characters
    if not collator.weightTable.hasKey(r):
      var defaultElement = CollationElement(
        primary: uint32(r) + 0xE0000, # Offset to avoid conflicting with defined weights
        secondary: 0x0020,
        tertiary: 0x0002,
        quaternary: 0
      )
      result.elements.add(defaultElement)
      continue
      
    # Get the defined weights for this character
    let elements = collator.weightTable[r]
    for elem in elements:
      result.elements.add(elem)
  
  return result

# Compare collation keys at the specified level
proc compareKeys(key1, key2: CollationKey, strength: CollationLevel): int =
  let minLen = min(key1.elements.len, key2.elements.len)
  
  # Compare primary weights
  var i = 0
  while i < minLen:
    if key1.elements[i].primary < key2.elements[i].primary:
      return -1
    elif key1.elements[i].primary > key2.elements[i].primary:
      return 1
    i += 1
  
  # If primary weights are equal and we only care about primary level
  if strength == Primary:
    if key1.elements.len < key2.elements.len:
      return -1
    elif key1.elements.len > key2.elements.len:
      return 1
    else:
      return 0
  
  # Compare secondary weights if requested
  i = 0
  while i < minLen:
    if key1.elements[i].secondary < key2.elements[i].secondary:
      return -1
    elif key1.elements[i].secondary > key2.elements[i].secondary:
      return 1
    i += 1
    
  # If secondary weights are equal and we only care up to secondary
  if strength == Secondary:
    if key1.elements.len < key2.elements.len:
      return -1
    elif key1.elements.len > key2.elements.len:
      return 1
    else:
      return 0
  
  # Compare tertiary weights if requested
  i = 0
  while i < minLen:
    if key1.elements[i].tertiary < key2.elements[i].tertiary:
      return -1
    elif key1.elements[i].tertiary > key2.elements[i].tertiary:
      return 1
    i += 1
    
  # If tertiary weights are equal and we only care up to tertiary
  if strength == Tertiary:
    if key1.elements.len < key2.elements.len:
      return -1
    elif key1.elements.len > key2.elements.len:
      return 1
    else:
      return 0
  
  # Compare quaternary weights if requested
  i = 0
  while i < minLen:
    if key1.elements[i].quaternary < key2.elements[i].quaternary:
      return -1
    elif key1.elements[i].quaternary > key2.elements[i].quaternary:
      return 1
    i += 1
    
  # Compare lengths for final determination
  if key1.elements.len < key2.elements.len:
    return -1
  elif key1.elements.len > key2.elements.len:
    return 1
  
  # Completely identical
  return 0

# Compare two strings using the collator
proc compare*(collator: CollatorImpl, a, b: string): int =
  let keyA = collator.getCollationKey(a)
  let keyB = collator.getCollationKey(b)
  return compareKeys(keyA, keyB, collator.options.strength)

# Sort a sequence of strings using the collator
proc sort*(collator: CollatorImpl, strings: var seq[string]) =
  strings.sort(proc(a, b: string): int = collator.compare(a, b))

# Implementation of locale-specific sorting
proc sortWithLocale*(strings: var seq[string], locale: string) =
  let options = CollationOptions(
    strength: Tertiary,
    caseFirst: CaseFirstOff,
    ignorePunctuation: false,
    numericOrdering: true,
    locale: locale
  )
  
  let collator = newCollator(options)
  collator.sort(strings)

# Demonstrate locale-specific sorting
proc demonstrateLocaleSorting(buffer: var Buffer, x, y: int, locale: string, 
                             strings: seq[string], title: string) =
  buffer.print(x, y, title & " (" & locale & "):", Style(attrs: {AttrBold}))
  
  var yPos = y + 1
  
  # Display original order
  buffer.print(x, yPos, "Original order:")
  yPos += 1
  
  for i, s in strings:
    buffer.print(x + 2, yPos + i, $(i+1) & ". " & s)
  
  yPos += strings.len + 1
  
  # Sort and display using locale-specific rules
  var sortedStrings = strings
  sortWithLocale(sortedStrings, locale)
  
  buffer.print(x, yPos, "Sorted order:")
  yPos += 1
  
  for i, s in sortedStrings:
    buffer.print(x + 2, yPos + i, $(i+1) & ". " & s)
  
  return

# Demonstrate difference in collation levels
proc demonstrateCollationLevels(buffer: var Buffer, x, y: int, strings: seq[string]) =
  buffer.print(x, y, "Collation Strength Levels:", Style(attrs: {AttrBold}))
  
  let levelNames = ["Primary (base letters)", 
                   "Secondary (accents)", 
                   "Tertiary (case)", 
                   "Quaternary (punctuation)"]
  
  var yPos = y + 1
  
  # Display original strings
  buffer.print(x, yPos, "Original strings:")
  yPos += 1
  
  for i, s in strings:
    buffer.print(x + 2, yPos + i, $(i+1) & ". " & s)
  
  yPos += strings.len + 1
  
  # Sort at each level
  for level in Primary..Quaternary:
    let options = CollationOptions(
      strength: level,
      caseFirst: CaseFirstOff,
      ignorePunctuation: false,
      numericOrdering: true
    )
    
    let collator = newCollator(options)
    var sortedStrings = strings
    collator.sort(sortedStrings)
    
    buffer.print(x, yPos, "Level " & $int(level) & ": " & levelNames[int(level)-1] & ":")
    yPos += 1
    
    for i, s in sortedStrings:
      buffer.print(x + 2, yPos + i, $(i+1) & ". " & s)
    
    yPos += strings.len + 1
  
  return

# Visualize collation elements for a string
proc visualizeCollationElements(buffer: var Buffer, x, y: int, s: string) =
  buffer.print(x, y, "Collation Elements for \"" & s & "\":", Style(attrs: {AttrBold}))
  
  let collator = newCollator()
  let key = collator.getCollationKey(s)
  let runes = s.toRunes
  
  var yPos = y + 1
  buffer.print(x, yPos, "Char | Primary    | Secondary | Tertiary  | Quaternary")
  yPos += 1
  buffer.print(x, yPos, "-----+------------+-----------+-----------+------------")
  yPos += 1
  
  for i, r in runes:
    if i < key.elements.len:
      let elem = key.elements[i]
      let charStr = $r
      
      # Format weights as hex
      let primaryHex = "0x" & toHex(int(elem.primary), 8)
      let secondaryHex = "0x" & toHex(int(elem.secondary), 4)
      let tertiaryHex = "0x" & toHex(int(elem.tertiary), 4)
      let quaternaryHex = "0x" & toHex(int(elem.quaternary), 4)
      
      # Format as table row
      let row = charStr.alignLeft(5) & "| " & 
                primaryHex.alignLeft(10) & " | " & 
                secondaryHex.alignLeft(9) & " | " & 
                tertiaryHex.alignLeft(9) & " | " & 
                quaternaryHex
                
      buffer.print(x, yPos + i, row)

# Numerically-aware comparison
proc compareNumerically(collator: CollatorImpl, a, b: string): int =
  let runes1 = a.toRunes
  let runes2 = b.toRunes
  
  var i = 0
  var j = 0
  
  while i < runes1.len and j < runes2.len:
    let r1 = runes1[i]
    let r2 = runes2[j]
    
    # Both are digits - compare as numbers
    if r1.isDigit and r2.isDigit:
      # Extract consecutive digits as numbers
      var num1 = ""
      var num2 = ""
      
      while i < runes1.len and runes1[i].isDigit:
        num1.add($runes1[i])
        i += 1
      
      while j < runes2.len and runes2[j].isDigit:
        num2.add($runes2[j])
        j += 1
      
      # Compare as integers
      let val1 = parseInt(num1)
      let val2 = parseInt(num2)
      
      if val1 < val2: return -1
      if val1 > val2: return 1
      # If equal, continue to next characters
    else:
      # Compare individual characters
      let elemA = if collator.weightTable.hasKey(r1): 
                   collator.weightTable[r1][0]
                 else:
                   CollationElement(primary: uint32(r1) + 0xE0000)
      
      let elemB = if collator.weightTable.hasKey(r2): 
                   collator.weightTable[r2][0]
                 else:
                   CollationElement(primary: uint32(r2) + 0xE0000)
      
      # Compare primary weights
      if elemA.primary < elemB.primary: return -1
      if elemA.primary > elemB.primary: return 1
      
      # If equal, move to next characters
      i += 1
      j += 1
  
  # Check if one string is a prefix of the other
  if i < runes1.len: return 1
  if j < runes2.len: return -1
  
  # Equal strings
  return 0

# Demonstrate numeric ordering
proc demonstrateNumericOrdering(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Numeric Ordering:", Style(attrs: {AttrBold}))
  
  let strings = @[
    "file1.txt", "file10.txt", "file2.txt", "file20.txt", "file3.txt",
    "A-1", "A-2", "A-10", "A-20", "B-1", "B-10",
    "Section 1", "Section 2", "Section 10", "Section 20",
    "Chapter 1.1", "Chapter 1.2", "Chapter 1.10", "Chapter 2.1"
  ]
  
  var yPos = y + 1
  
  # Display original order
  buffer.print(x, yPos, "Original order:")
  yPos += 1
  
  for i, s in strings:
    buffer.print(x + 2, yPos + i, $(i+1) & ". " & s)
  
  yPos += strings.len + 1
  
  # Standard lexicographical sort
  var lexicoStrings = strings
  lexicoStrings.sort()
  
  buffer.print(x, yPos, "Lexicographical sort:")
  yPos += 1
  
  for i, s in lexicoStrings:
    buffer.print(x + 2, yPos + i, $(i+1) & ". " & s)
  
  yPos += strings.len + 1
  
  # Numeric-aware sort
  var numericStrings = strings
  let options = CollationOptions(
    strength: Tertiary,
    numericOrdering: true
  )
  let collator = newCollator(options)
  
  numericStrings.sort(proc(a, b: string): int = collator.compareNumerically(a, b))
  
  buffer.print(x, yPos, "Numeric-aware sort:")
  yPos += 1
  
  for i, s in numericStrings:
    buffer.print(x + 2, yPos + i, $(i+1) & ". " & s)

# Interactive collation tester
proc interactiveCollationTester(buffer: var Buffer, x, y: int, width: int, height: int) =
  # Header
  buffer.print(x, y, "Interactive Collation Tester:", Style(attrs: {AttrBold}))
  
  # Draw input areas
  let inputX = x + 2
  let inputY = y + 2
  
  # Draw text input areas
  buffer.print(inputX, inputY, "String 1: ")
  buffer.print(inputX, inputY + 2, "String 2: ")
  
  # Draw input boxes
  for i in 0..1:
    let boxY = inputY + i*2
    
    # Draw horizontal lines
    for j in 0..<30:
      buffer.print(inputX + 10 + j, boxY, "─")
      buffer.print(inputX + 10 + j, boxY + 1, "─")
    
    # Draw vertical lines
    buffer.print(inputX + 10 - 1, boxY, "┌")
    buffer.print(inputX + 10 - 1, boxY + 1, "└")
    buffer.print(inputX + 10 + 30, boxY, "┐")
    buffer.print(inputX + 10 + 30, boxY + 1, "┘")
    
    # Draw vertical lines
    for j in 0..0:
      buffer.print(inputX + 10 - 1, boxY + j, "│")
      buffer.print(inputX + 10 + 30, boxY + j, "│")
  
  # Draw options area
  let optionsY = inputY + 5
  buffer.print(inputX, optionsY, "Options:", Style(attrs: {AttrBold}))
  
  buffer.print(inputX + 2, optionsY + 1, "Strength: (1) Primary, (2) Secondary, (3) Tertiary, (4) Quaternary")
  buffer.print(inputX + 2, optionsY + 2, "Locale: (e) English, (s) Spanish, (f) French, (g) German, (w) Swedish")
  buffer.print(inputX + 2, optionsY + 3, "Numeric: (n) Toggle numeric ordering")
  
  # Draw results area
  let resultsY = optionsY + 5
  buffer.print(inputX, resultsY, "Comparison Results:", Style(attrs: {AttrBold}))
  
  # Draw initial help text
  buffer.print(inputX + 2, resultsY + 2, "Enter two strings and set options to see comparison results")
  buffer.print(inputX, height - 2, "Press ESC to exit, TAB to switch between inputs")
  
  # Draw buffer initially
  drawBuffer(buffer)
  
  # Set up state for interactive input
  var 
    string1 = ""
    string2 = ""
    currentField = 0  # 0 for string1, 1 for string2
    strength = Tertiary
    locale = "en"
    numericOrdering = false
    running = true
  
  proc updateDisplay() =
    # Clear input fields
    for i in 0..1:
      let boxY = inputY + i*2
      for j in 0..<28:
        buffer.print(inputX + 11 + j, boxY, " ")
    
    # Display current values
    buffer.print(inputX + 11, inputY, string1)
    buffer.print(inputX + 11, inputY + 2, string2)
    
    # Highlight current field
    let boxY = inputY + currentField*2
    let fieldText = if currentField == 0: string1 else: string2
    buffer.print(inputX + 11, boxY, fieldText, Style(bg: ColorBlue))
    
    # Show current options
    let strengthStr = case strength:
      of Primary: "Primary"
      of Secondary: "Secondary"
      of Tertiary: "Tertiary"
      of Quaternary: "Quaternary"
    
    let localeStr = locale.toUpperAscii()
    let numericStr = if numericOrdering: "On" else: "Off"
    
    buffer.print(inputX + 15, optionsY + 1, strengthStr, Style(fg: ColorGreen))
    buffer.print(inputX + 15, optionsY + 2, localeStr, Style(fg: ColorGreen))
    buffer.print(inputX + 15, optionsY + 3, numericStr, Style(fg: ColorGreen))
    
    # Calculate and show comparison results
    let options = CollationOptions(
      strength: strength,
      locale: locale,
      numericOrdering: numericOrdering
    )
    
    let collator = newCollator(options)
    
    # Clear results area
    for i in 0..<10:
      buffer.print(inputX + 2, resultsY + 2 + i, " ".repeat(width - inputX - 4))
    
    # Show basic comparison
    let compareResult = collator.compare(string1, string2)
    let compareStr = case compareResult:
      of -1: "\"" & string1 & "\" comes BEFORE \"" & string2 & "\""
      of 0: "\"" & string1 & "\" is EQUAL TO \"" & string2 & "\""
      of 1: "\"" & string1 & "\" comes AFTER \"" & string2 & "\""
      else: "Error"
    
    buffer.print(inputX + 2, resultsY + 2, compareStr)
    
    # Show collation keys
    let key1 = collator.getCollationKey(string1)
    let key2 = collator.getCollationKey(string2)
    
    buffer.print(inputX + 2, resultsY + 4, "Collation analysis:")
    
    if string1.len > 0 and string2.len > 0:
      let runes1 = string1.toRunes
      let runes2 = string2.toRunes
      
      buffer.print(inputX + 2, resultsY + 5, "String 1 weights:")
      var row = ""
      for i, r in runes1:
        if i < key1.elements.len:
          let elem = key1.elements[i]
          row.add($r & ":" & toHex(int(elem.primary), 4) & " ")
      buffer.print(inputX + 4, resultsY + 6, row)
      
      buffer.print(inputX + 2, resultsY + 7, "String 2 weights:")
      row = ""
      for i, r in runes2:
        if i < key2.elements.len:
          let elem = key2.elements[i]
          row.add($r & ":" & toHex(int(elem.primary), 4) & " ")
      buffer.print(inputX + 4, resultsY + 8, row)
      
      # Find the first difference
      var diffPos = min(key1.elements.len, key2.elements.len)
      var diffLevel = "equal"
      var diffWeight1 = 0'u32
      var diffWeight2 = 0'u32
      
      for i in 0..<min(key1.elements.len, key2.elements.len):
        let elem1 = key1.elements[i]
        let elem2 = key2.elements[i]
        
        if elem1.primary != elem2.primary:
          diffPos = i
          diffLevel = "primary"
          diffWeight1 = elem1.primary
          diffWeight2 = elem2.primary
          break
        elif elem1.secondary != elem2.secondary and strength.int >= Secondary.int:
          diffPos = i
          diffLevel = "secondary"
          diffWeight1 = elem1.secondary.uint32
          diffWeight2 = elem2.secondary.uint32
          break
        elif elem1.tertiary != elem2.tertiary and strength.int >= Tertiary.int:
          diffPos = i
          diffLevel = "tertiary"
          diffWeight1 = elem1.tertiary.uint32
          diffWeight2 = elem2.tertiary.uint32
          break
        elif elem1.quaternary != elem2.quaternary and strength.int >= Quaternary.int:
          diffPos = i
          diffLevel = "quaternary"
          diffWeight1 = elem1.quaternary.uint32
          diffWeight2 = elem2.quaternary.uint32
          break
      
      if diffLevel != "equal":
        buffer.print(inputX + 2, resultsY + 10, "First difference at position " & $diffPos & 
                  " (" & diffLevel & " level): " & toHex(int(diffWeight1), 4) & 
                  " vs " & toHex(int(diffWeight2), 4))
      else:
        if key1.elements.len != key2.elements.len:
          buffer.print(inputX + 2, resultsY + 10, "Strings differ in length: " & 
                    $key1.elements.len & " vs " & $key2.elements.len)
        else:
          buffer.print(inputX + 2, resultsY + 10, "Strings are exactly equal at all levels")
    
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
          
        elif key.key == KeyTab:
          currentField = 1 - currentField  # Toggle between 0 and 1
          updateDisplay()
          
        elif key.key == KeyBackspace:
          # Handle backspace
          if currentField == 0 and string1.len > 0:
            string1.setLen(max(0, string1.len - 1))
          elif currentField == 1 and string2.len > 0:
            string2.setLen(max(0, string2.len - 1))
          updateDisplay()
          
        elif key.key == KeyEnter:
          # Validate and update
          updateDisplay()
          
        else:
          # Handle numeric keys for strength
          if key.ch >= '1'.Rune and key.ch <= '4'.Rune:
            strength = CollationLevel(int(key.ch) - int('0'.Rune))
            updateDisplay()
            
          # Handle locale selection
          elif key.ch == 'e'.Rune:
            locale = "en"
            updateDisplay()
          elif key.ch == 's'.Rune:
            locale = "es"
            updateDisplay()
          elif key.ch == 'f'.Rune:
            locale = "fr"
            updateDisplay()
          elif key.ch == 'g'.Rune:
            locale = "de"
            updateDisplay()
          elif key.ch == 'w'.Rune:
            locale = "sv"
            updateDisplay()
            
          # Toggle numeric ordering
          elif key.ch == 'n'.Rune:
            numericOrdering = not numericOrdering
            updateDisplay()
            
          # Add character to current field
          elif key.ch != 0 and key.ch <= 127.Rune:  # Basic ASCII support
            let ch = $key.ch
            if currentField == 0:
              string1.add(ch)
            else:
              string2.add(ch)
            updateDisplay()
          
      of EventResize:
        # Handle resize event
        let (newWidth, newHeight) = raw.getTerminalSize()
        buffer = newBuffer(newWidth, newHeight)
        clearScreen()
        
        # Redraw everything (simplified)
        interactiveCollationTester(buffer, x, y, newWidth, newHeight)
        
      else:
        discard

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
    buffer.print(2, 1, "Unicode Collation Algorithm Implementation", titleStyle)
    
    # Description
    buffer.print(2, 3, "Demonstration of linguistically correct string comparison and sorting")
    
    # Section styles
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Section 1: Locale-specific sorting
    buffer.print(2, 5, "1. Locale-specific Sorting", sectionStyle)
    
    # Spanish example (traditional sorting with ch, ll, ñ)
    let spanishWords = @[
      "año", "anochecer", "añorar", 
      "Chile", "cimientos", "cuñado", 
      "loco", "loro", "luz", "lluvia", "lámpara",
      "niño", "nido", "ñandú",
      "chaleco", "chorizo", "cuchara"
    ]
    
    demonstrateLocaleSorting(buffer, 4, 7, "es", spanishWords, "Spanish Sorting")
    
    # German example (traditional sorting with umlauts)
    let germanWords = @[
      "Apfel", "Äpfel", "Arbeit", "Büro", 
      "Buch", "Zoo", "Zug", "Über", "Oper",
      "Österreich", "Offenheit", "Universität", 
      "Ufer", "Übung", "Straße", "Strasse"
    ]
    
    demonstrateLocaleSorting(buffer, 40, 7, "de", germanWords, "German Sorting")
    
    # Section 2: Collation Levels
    buffer.print(2, 32, "2. Collation Strength Levels", sectionStyle)
    
    let levelExamples = @[
      "Apple", "apple", "APPLE", 
      "cafe", "café", "cafè", "CAFE", "CAFÉ",
      "role", "rôle", "roles",
      "coop", "co-op", "co-operative", 
      "Blackbird", "black bird", "black-bird"
    ]
    
    demonstrateCollationLevels(buffer, 4, 34, levelExamples)
    
    # Section 3: Visualize Collation Elements
    buffer.print(2, 60, "3. Collation Element Visualization", sectionStyle)
    
    visualizeCollationElements(buffer, 4, 62, "café")
    visualizeCollationElements(buffer, 4, 68, "Cafe")
    visualizeCollationElements(buffer, 40, 62, "España")
    visualizeCollationElements(buffer, 40, 68, "123")
    
    # Section 4: Numeric Ordering
    buffer.print(2, 75, "4. Numeric Ordering", sectionStyle)
    
    demonstrateNumericOrdering(buffer, 4, 77)
    
    # Section 5: Interactive Tester
    buffer.print(2, 100, "5. Interactive Collation Tester", sectionStyle)
    
    buffer.print(4, 102, "Press any key to start the interactive tester, or ESC to exit")
    
    # Draw buffer
    drawBuffer(buffer)
    
    # Wait for key before starting interactive part
    let event = input.pollEvent()
    
    if event.kind != EventKey or event.key.key != KeyEscape:
      clearScreen()
      buffer = newBuffer(width, height)
      interactiveCollationTester(buffer, 2, 5, width - 4, height - 7)

when isMainModule:
  main()