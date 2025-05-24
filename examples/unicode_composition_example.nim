# unicode_composition_example.nim
## Unicode Normalization, Composition, and Decomposition
## 
## This example demonstrates Unicode normalization forms, composition,
## decomposition, and provides utilities for working with these operations
## in terminal applications.

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/sequtils

type
  NormalizationForm = enum
    NFD,  # Canonical Decomposition
    NFC,  # Canonical Decomposition followed by Canonical Composition
    NFKD, # Compatibility Decomposition
    NFKC  # Compatibility Decomposition followed by Canonical Composition
    
  DecompositionTag = enum
    None,         # No decomposition
    Canonical,    # Canonical decomposition
    Font,         # Font variant
    NoBreak,      # No-break version of a space or hyphen
    Initial,      # Initial presentation form
    Medial,       # Medial presentation form
    Final,        # Final presentation form
    Isolated,     # Isolated presentation form
    Circle,       # Encircled form
    Super,        # Superscript form
    Sub,          # Subscript form
    Vertical,     # Vertical layout presentation form
    Wide,         # Wide (or zenkaku) compatibility character
    Narrow,       # Narrow (or hankaku) compatibility character
    Small,        # Small variant form
    Square,       # CJK squared font variant
    Fraction,     # Vulgar fraction form
    Compat        # Otherwise unspecified compatibility character

# Unicode decomposition mapping (simplified)
var decompositionMap = {
  # Latin letters with diacritics (decompose to base + combining mark)
  "á".toRunes[0]: @["a".toRunes[0], "\u0301".toRunes[0]],
  "é".toRunes[0]: @["e".toRunes[0], "\u0301".toRunes[0]],
  "í".toRunes[0]: @["i".toRunes[0], "\u0301".toRunes[0]],
  "ó".toRunes[0]: @["o".toRunes[0], "\u0301".toRunes[0]],
  "ú".toRunes[0]: @["u".toRunes[0], "\u0301".toRunes[0]],
  "ñ".toRunes[0]: @["n".toRunes[0], "\u0303".toRunes[0]],
  "ü".toRunes[0]: @["u".toRunes[0], "\u0308".toRunes[0]],
  
  # Selected compatibility decompositions
  "①".toRunes[0]: @["1".toRunes[0]],  # Circled 1 -> 1
  "ｆ".toRunes[0]: @["f".toRunes[0]],  # Fullwidth f -> f
  "℀".toRunes[0]: @["a".toRunes[0], "/".toRunes[0], "c".toRunes[0]],  # Account of -> a/c
  
  # Add more mappings as needed...
}.toTable()

# Unicode composition mapping (simplified inverse of decomposition)
var compositionMap = initTable[seq[Rune], Rune]()

# Initialize the composition map from the decomposition map
proc initCompositionMap() =
  for composed, decomposed in decompositionMap.pairs:
    # Only map canonical compositions (typically two characters)
    if decomposed.len == 2:
      compositionMap[decomposed] = composed

# Perform canonical decomposition (NFD)
proc canonicalDecomposition(input: string): string =
  var result = ""
  
  for r in input.toRunes:
    if r in decompositionMap:
      # This character has a decomposition
      let decomposed = decompositionMap[r]
      for dr in decomposed:
        result.add(toUTF8(dr))
    else:
      # No decomposition
      result.add(toUTF8(r))
  
  return result

# Perform canonical composition (NFC)
proc canonicalComposition(input: string): string =
  # First perform canonical decomposition
  let decomposed = canonicalDecomposition(input)
  let runes = decomposed.toRunes
  
  var result: seq[Rune] = @[]
  var i = 0
  
  while i < runes.len:
    if i < runes.len - 1:
      # Try to compose this character with the next
      let pair = @[runes[i], runes[i+1]]
      
      if pair in compositionMap:
        # Composition is possible
        result.add(compositionMap[pair])
        i += 2
        continue
    
    # No composition possible, keep the character
    result.add(runes[i])
    i += 1
  
  # Convert back to string
  var resultStr = ""
  for r in result:
    resultStr.add(toUTF8(r))
  
  return resultStr

# Convert to a specific normalization form
proc normalize(input: string, form: NormalizationForm): string =
  case form:
    of NFD:
      return canonicalDecomposition(input)
    of NFC:
      return canonicalComposition(input)
    of NFKD, NFKC:
      # These would require full compatibility decomposition tables
      # Simplified implementation for example purposes
      return input

# Display a string's code points and descriptions
proc analyzeString(buffer: var Buffer, x, y: int, input: string, style: Style = Style()) =
  let runes = input.toRunes
  
  buffer.print(x, y, "String: " & input, style)
  buffer.print(x, y+1, "Length: " & $input.len & " bytes, " & $runes.len & " code points")
  buffer.print(x, y+2, "Code points:")
  
  for i, r in runes:
    let codePoint = "U+" & toHex(int(r), 4)
    let category = getCategory(r)
    
    # Get simple description
    var desc = ""
    if r in decompositionMap:
      desc = "Has decomposition"
    elif int(r) < 128:
      desc = "ASCII"
    elif int(r) >= 0x0300 and int(r) <= 0x036F:
      desc = "Combining mark"
    else:
      desc = "Unicode character"
    
    buffer.print(x+2, y+3+i, codePoint & " " & toUTF8(r) & " (" & $category & ") - " & desc)

# Display decomposition and composition examples
proc showNormalizationExample(buffer: var Buffer, x, y: int, input: string) =
  buffer.print(x, y, "Original: " & "\"" & input & "\"")
  
  let nfd = normalize(input, NFD)
  let nfc = normalize(input, NFC)
  
  buffer.print(x, y+1, "NFD: " & "\"" & nfd & "\"")
  buffer.print(x, y+2, "NFC: " & "\"" & nfc & "\"")
  
  # Show code points for each
  buffer.print(x, y+4, "Original code points:")
  for i, r in input.toRunes:
    buffer.print(x+2, y+5+i, "U+" & toHex(int(r), 4) & " " & toUTF8(r))
  
  buffer.print(x, y+10, "NFD code points:")
  for i, r in nfd.toRunes:
    buffer.print(x+2, y+11+i, "U+" & toHex(int(r), 4) & " " & toUTF8(r))

# Display character building
proc showCharacterBuilding(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Character Building with Combining Marks:")
  
  let baseChars = ["a", "e", "i", "o", "u", "n", "A", "O", "U"]
  let combiningMarks = [
    "\u0301", # COMBINING ACUTE ACCENT (é)
    "\u0300", # COMBINING GRAVE ACCENT (è)
    "\u0302", # COMBINING CIRCUMFLEX ACCENT (ê)
    "\u0303", # COMBINING TILDE (ñ)
    "\u0308", # COMBINING DIAERESIS (ü)
    "\u0327", # COMBINING CEDILLA (ç)
    "\u0306", # COMBINING BREVE (ă)
    "\u0307", # COMBINING DOT ABOVE (ȧ)
    "\u0323"  # COMBINING DOT BELOW (ạ)
  ]
  
  let markNames = [
    "Acute (´)",
    "Grave (`)",
    "Circumflex (^)",
    "Tilde (~)",
    "Diaeresis (¨)",
    "Cedilla (¸)",
    "Breve (˘)",
    "Dot Above (˙)",
    "Dot Below (.)"
  ]
  
  # Show a grid of combinations
  for i, base in baseChars:
    buffer.print(x, y+2+i, base & ": ")
    
    for j, mark in combiningMarks:
      if j < 5:  # Limit to 5 per row
        let composite = base & mark
        let description = markNames[j]
        buffer.print(x+4+(j*12), y+2+i, composite & " (" & description & ")")

# Show multi-combining examples
proc showMultiCombiningExamples(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Multiple Combining Marks:")
  
  let examples = [
    ("a\u0301\u0308", "a + acute + diaeresis"),
    ("u\u0308\u0301", "u + diaeresis + acute"),
    ("n\u0303\u0301", "n + tilde + acute"),
    ("o\u0302\u0323", "o + circumflex + dot below"),
    ("e\u0327\u0306", "e + cedilla + breve"),
    ("a\u0307\u0323", "a + dot above + dot below"),
    ("Z\u0307\u0323\u0302", "Z + dot above + dot below + circumflex"),
    ("O\u0303\u0301\u0307", "O + tilde + acute + dot above")
  ]
  
  for i, example in examples:
    let combined = example[0]
    let description = example[1]
    buffer.print(x, y+2+i, combined & " = " & description)
    
    # Show normalization forms
    let nfd = normalize(combined, NFD)
    let nfc = normalize(combined, NFC)
    
    buffer.print(x+30, y+2+i, "NFD: \"" & nfd & "\"  NFC: \"" & nfc & "\"")

# Display Unicode equivalence comparison
proc showEquivalenceComparison(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Unicode Equivalence Comparison:")
  
  let examples = [
    ("é", "e\u0301", "Precomposed é vs. e + ◌́"),
    ("ñ", "n\u0303", "Precomposed ñ vs. n + ◌̃"),
    ("ü", "u\u0308", "Precomposed ü vs. u + ◌̈"),
    ("Å", "A\u030A", "Precomposed Å vs. A + ◌̊"),
    ("℀", "a/c", "Compatibility character ℀ vs. a/c")
  ]
  
  for i, example in examples:
    let form1 = example[0]
    let form2 = example[1]
    let description = example[2]
    
    buffer.print(x, y+2+i, description)
    buffer.print(x+40, y+2+i, "\"" & form1 & "\" vs. \"" & form2 & "\"")
    
    # Check canonical equivalence
    let nfd1 = normalize(form1, NFD)
    let nfd2 = normalize(form2, NFD)
    let equivalent = nfd1 == nfd2
    
    let equivalenceText = if equivalent: "Equivalent" else: "Not equivalent"
    let equivalenceStyle = if equivalent: 
                            Style(fg: ColorGreen) 
                           else: 
                            Style(fg: ColorRed)
    
    buffer.print(x+60, y+2+i, equivalenceText, equivalenceStyle)

# Main example procedure
proc main() =
  # Initialize composition map
  initCompositionMap()
  
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
    buffer.print(2, 1, "Unicode Normalization and Composition", titleStyle)
    
    # Description
    buffer.print(2, 3, "Demonstration of Unicode normalization forms, composition, and decomposition")
    
    # Section styles
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Section 1: String Analysis
    buffer.print(2, 5, "1. Unicode String Analysis", sectionStyle)
    
    # Analyze some strings
    analyzeString(buffer, 4, 7, "Hello")  # ASCII
    analyzeString(buffer, 4, 15, "café")  # Latin with diacritic
    analyzeString(buffer, 40, 7, "café") # Same word but with decomposed e + ◌́
    analyzeString(buffer, 40, 15, "日本語")  # CJK
    
    # Section 2: Normalization Examples
    buffer.print(2, 25, "2. Normalization Examples", sectionStyle)
    
    # Show normalization for different examples
    showNormalizationExample(buffer, 4, 27, "café")  # Latin with diacritic
    showNormalizationExample(buffer, 40, 27, "한글")  # Hangul
    
    # Section 3: Character Building
    buffer.print(2, 45, "3. Character Building", sectionStyle)
    
    # Show character building with combining marks
    showCharacterBuilding(buffer, 4, 47)
    
    # Section 4: Multiple Combining Marks
    buffer.print(2, 60, "4. Multiple Combining Marks", sectionStyle)
    
    # Show examples with multiple combining marks
    showMultiCombiningExamples(buffer, 4, 62)
    
    # Section 5: Unicode Equivalence
    buffer.print(2, 75, "5. Unicode Equivalence", sectionStyle)
    
    # Show equivalence comparison
    showEquivalenceComparison(buffer, 4, 77)
    
    # Draw buffer
    drawBuffer(buffer)
    
    # Wait for keypress before exiting
    buffer.print(2, height - 2, "Press any key to exit...")
    drawBuffer(buffer)
    discard input.pollEvent()

when isMainModule:
  main()