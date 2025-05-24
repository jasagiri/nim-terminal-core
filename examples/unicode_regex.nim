# unicode_regex.nim
## Unicode-aware Regular Expressions
## 
## This example demonstrates Unicode-aware regular expression functionality,
## including Unicode character classes, grapheme cluster matching,
## bidirectional text handling, and case folding across scripts.

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/algorithm
import std/sequtils

# Define Unicode regex pattern types
type
  UnicodeRegexPattern = ref object
    source: string            # Original pattern string
    compiled: seq[RegexNode]  # Compiled pattern

  RegexNodeKind = enum
    Literal,     # Literal character
    CharClass,   # Character class like \p{Letter}
    Quantifier,  # *, +, ?, {n,m}
    Group,       # Capturing group ( )
    Alternation, # |
    Assertion,   # ^, $, \b, etc.
    Any,         # .
    BackRef      # \1, \2, etc.
    
  RegexNode = object
    case kind: RegexNodeKind
      of Literal:
        codePoint: Rune
      of CharClass:
        charClass: UnicodeCharClass
        negated: bool
      of Quantifier:
        min, max: int          # Repetition counts
        greedy: bool           # Greedy or reluctant
        inner: seq[RegexNode]  # The item being repeated
      of Group:
        groupNumber: int
        groupContents: seq[RegexNode]
      of Alternation:
        alternatives: seq[seq[RegexNode]]
      of Assertion:
        assertionType: AssertionKind
      of Any:
        dotMatchesNewline: bool
      of BackRef:
        refNumber: int
        
  AssertionKind = enum
    StartOfString,    # ^
    EndOfString,      # $
    WordBoundary,     # \b
    NotWordBoundary,  # \B
    LookAhead,        # (?=...)
    NegLookAhead,     # (?!...)
    LookBehind,       # (?<=...)
    NegLookBehind     # (?<!...)

  # Unicode character classes
  UnicodeCharClass = enum
    Letter,          # \p{L} - any kind of letter from any language
    LowercaseLetter, # \p{Ll} - lowercase letter
    UppercaseLetter, # \p{Lu} - uppercase letter
    TitlecaseLetter, # \p{Lt} - digraphic letter with first part uppercase
    Number,          # \p{N} - any kind of numeric character
    Digit,           # \p{Nd} - decimal digit
    Punctuation,     # \p{P} - any kind of punctuation
    Symbol,          # \p{S} - math symbols, currency signs, etc.
    Mark,            # \p{M} - accents and other diacritical marks
    Separator,       # \p{Z} - spaces, line seps, paragraph seps
    Control,         # \p{C} - C0 and C1 control codes, format characters
    WhiteSpace,      # \p{White_Space} - whitespace characters
    AlphaNumeric,    # \p{Alphanumeric} - letters and numbers
    Emoji,           # \p{Emoji} - emoji characters
    
  # Match result
  UnicodeRegexMatch = object
    matched: bool
    matchedString: string
    startPos: int
    endPos: int
    captures: seq[string]

# Helper functions for Unicode character class detection
proc isInCharClass(r: Rune, charClass: UnicodeCharClass): bool =
  case charClass:
    of Letter:
      return r.isAlpha
    of LowercaseLetter:
      return r.isLower
    of UppercaseLetter:
      return r.isUpper
    of TitlecaseLetter:
      # Simplified - real implementation would check Unicode database
      return false
    of Number:
      return r.isDigit
    of Digit:
      return r.isDigit
    of Punctuation:
      # Simplified - only checks ASCII punctuation
      let cp = r.int32
      return (cp >= 33 and cp <= 47) or
             (cp >= 58 and cp <= 64) or
             (cp >= 91 and cp <= 96) or
             (cp >= 123 and cp <= 126)
    of Symbol:
      # Simplified - only checks common symbols
      let cp = r.int32
      return (cp >= 0x20A0 and cp <= 0x20CF) or  # Currency symbols
             (cp >= 0x2100 and cp <= 0x214F) or  # Letterlike symbols
             (cp >= 0x2190 and cp <= 0x21FF) or  # Arrows
             (cp >= 0x2200 and cp <= 0x22FF) or  # Mathematical operators
             (cp >= 0x2300 and cp <= 0x23FF) or  # Miscellaneous technical
             (cp >= 0x2600 and cp <= 0x26FF) or  # Miscellaneous symbols
             (cp >= 0x2700 and cp <= 0x27BF)     # Dingbats
    of Mark:
      # Simplified - checks for common combining marks
      return (r.int32 >= 0x0300 and r.int32 <= 0x036F)  # Combining diacritical marks
    of Separator:
      return r.isSpace
    of Control:
      let cp = r.int32
      return (cp <= 0x001F) or (cp >= 0x007F and cp <= 0x009F)
    of WhiteSpace:
      return r.isSpace
    of AlphaNumeric:
      return r.isAlpha or r.isDigit
    of Emoji:
      # Simplified - checks for emoji ranges
      let cp = r.int32
      return (cp >= 0x1F300 and cp <= 0x1F64F) or  # Miscellaneous Symbols and Pictographs
             (cp >= 0x1F680 and cp <= 0x1F6FF) or  # Transport and Map Symbols
             (cp >= 0x1F700 and cp <= 0x1F77F) or  # Alchemical Symbols
             (cp >= 0x1F780 and cp <= 0x1F7FF) or  # Geometric Shapes Extended
             (cp >= 0x1F800 and cp <= 0x1F8FF) or  # Supplemental Arrows-C
             (cp >= 0x1F900 and cp <= 0x1F9FF) or  # Supplemental Symbols and Pictographs
             (cp >= 0x1FA00 and cp <= 0x1FA6F) or  # Chess Symbols
             (cp >= 0x1FA70 and cp <= 0x1FAFF)     # Symbols and Pictographs Extended-A

# Unicode case-insensitive comparison
proc unicodeEqualCaseInsensitive(a, b: Rune): bool =
  return unicode.toLower(a) == unicode.toLower(b)

# Basic regex parser for demonstration purposes
proc parseUnicodeRegex(pattern: string): UnicodeRegexPattern =
  result = UnicodeRegexPattern(source: pattern)
  
  # Simplified parsing - this would be much more complex in a real implementation
  var nodes: seq[RegexNode] = @[]
  let runes = pattern.toRunes
  var i = 0
  
  while i < runes.len:
    let r = runes[i]
    
    if r == '.'.Rune:
      # Any character
      nodes.add(RegexNode(kind: Any, dotMatchesNewline: false))
      i += 1
      
    elif r == '^'.Rune:
      # Start of string assertion
      nodes.add(RegexNode(kind: Assertion, assertionType: StartOfString))
      i += 1
      
    elif r == '$'.Rune:
      # End of string assertion
      nodes.add(RegexNode(kind: Assertion, assertionType: EndOfString))
      i += 1
      
    elif r == '['.Rune:
      # Character class
      i += 1
      var negated = false
      if i < runes.len and runes[i] == '^'.Rune:
        negated = true
        i += 1
        
      # TODO: Parse character class contents
      # This is simplified, just handling negated literal character classes
      var charClass = Letter  # Default
      nodes.add(RegexNode(kind: CharClass, charClass: charClass, negated: negated))
      
      # Skip to the closing bracket
      while i < runes.len and runes[i] != ']'.Rune:
        i += 1
      if i < runes.len:
        i += 1  # Skip the closing bracket
    
    elif r == '\\'.Rune:
      # Escape sequences
      i += 1
      if i >= runes.len:
        # Error: incomplete escape
        break
        
      let escapeChar = runes[i]
      
      if escapeChar == 'p'.Rune:
        # Unicode property
        i += 1
        if i < runes.len and runes[i] == '{'.Rune:
          i += 1
          var propName = ""
          
          # Read property name
          while i < runes.len and runes[i] != '}'.Rune:
            propName.add($runes[i])
            i += 1
            
          if i < runes.len:
            i += 1  # Skip closing brace
            
          # Map property to character class
          var charClass: UnicodeCharClass
          case propName:
            of "L", "Letter":
              charClass = Letter
            of "Ll", "Lowercase_Letter":
              charClass = LowercaseLetter
            of "Lu", "Uppercase_Letter":
              charClass = UppercaseLetter
            of "N", "Number":
              charClass = Number
            of "Nd", "Decimal_Number", "Digit":
              charClass = Digit
            of "P", "Punctuation":
              charClass = Punctuation
            of "S", "Symbol":
              charClass = Symbol
            of "M", "Mark":
              charClass = Mark
            of "Z", "Separator":
              charClass = Separator
            of "C", "Control":
              charClass = Control
            of "White_Space", "Space":
              charClass = WhiteSpace
            of "Emoji":
              charClass = Emoji
            else:
              # Default to Letter for unknown properties
              charClass = Letter
              
          nodes.add(RegexNode(kind: CharClass, charClass: charClass, negated: false))
        
      elif escapeChar == 'P'.Rune:
        # Negated Unicode property
        i += 1
        if i < runes.len and runes[i] == '{'.Rune:
          i += 1
          var propName = ""
          
          # Read property name
          while i < runes.len and runes[i] != '}'.Rune:
            propName.add($runes[i])
            i += 1
            
          if i < runes.len:
            i += 1  # Skip closing brace
            
          # Map property to character class (negated)
          var charClass: UnicodeCharClass
          case propName:
            of "L", "Letter":
              charClass = Letter
            of "Ll", "Lowercase_Letter":
              charClass = LowercaseLetter
            of "Lu", "Uppercase_Letter":
              charClass = UppercaseLetter
            of "N", "Number":
              charClass = Number
            of "Nd", "Decimal_Number", "Digit":
              charClass = Digit
            of "P", "Punctuation":
              charClass = Punctuation
            of "S", "Symbol":
              charClass = Symbol
            of "M", "Mark":
              charClass = Mark
            of "Z", "Separator":
              charClass = Separator
            of "C", "Control":
              charClass = Control
            of "White_Space", "Space":
              charClass = WhiteSpace
            of "Emoji":
              charClass = Emoji
            else:
              # Default to Letter for unknown properties
              charClass = Letter
              
          nodes.add(RegexNode(kind: CharClass, charClass: charClass, negated: true))
          
      elif escapeChar == 'd'.Rune:
        # Digit
        nodes.add(RegexNode(kind: CharClass, charClass: Digit, negated: false))
        i += 1
      elif escapeChar == 'D'.Rune:
        # Not Digit
        nodes.add(RegexNode(kind: CharClass, charClass: Digit, negated: true))
        i += 1
      elif escapeChar == 'w'.Rune:
        # Word character
        nodes.add(RegexNode(kind: CharClass, charClass: AlphaNumeric, negated: false))
        i += 1
      elif escapeChar == 'W'.Rune:
        # Not word character
        nodes.add(RegexNode(kind: CharClass, charClass: AlphaNumeric, negated: true))
        i += 1
      elif escapeChar == 's'.Rune:
        # Whitespace
        nodes.add(RegexNode(kind: CharClass, charClass: WhiteSpace, negated: false))
        i += 1
      elif escapeChar == 'S'.Rune:
        # Not whitespace
        nodes.add(RegexNode(kind: CharClass, charClass: WhiteSpace, negated: true))
        i += 1
      elif escapeChar == 'b'.Rune:
        # Word boundary
        nodes.add(RegexNode(kind: Assertion, assertionType: WordBoundary))
        i += 1
      elif escapeChar == 'B'.Rune:
        # Not word boundary
        nodes.add(RegexNode(kind: Assertion, assertionType: NotWordBoundary))
        i += 1
      else:
        # Treat as literal character
        nodes.add(RegexNode(kind: Literal, codePoint: escapeChar))
        i += 1
    
    elif r == '*'.Rune:
      # Zero or more
      if nodes.len > 0:
        let lastNode = nodes[^1]
        nodes.delete(nodes.high)
        nodes.add(RegexNode(
          kind: Quantifier,
          min: 0,
          max: high(int),
          greedy: true,
          inner: @[lastNode]
        ))
      i += 1
      
    elif r == '+'.Rune:
      # One or more
      if nodes.len > 0:
        let lastNode = nodes[^1]
        nodes.delete(nodes.high)
        nodes.add(RegexNode(
          kind: Quantifier,
          min: 1,
          max: high(int),
          greedy: true,
          inner: @[lastNode]
        ))
      i += 1
      
    elif r == '?'.Rune:
      # Zero or one
      if nodes.len > 0:
        let lastNode = nodes[^1]
        nodes.delete(nodes.high)
        nodes.add(RegexNode(
          kind: Quantifier,
          min: 0,
          max: 1,
          greedy: true,
          inner: @[lastNode]
        ))
      i += 1
      
    elif r == '('.Rune:
      # Group start
      i += 1
      # This is simplified - doesn't handle nested groups properly
      var groupContents: seq[RegexNode] = @[]
      var groupLevel = 1
      
      while i < runes.len and groupLevel > 0:
        if runes[i] == '('.Rune:
          groupLevel += 1
        elif runes[i] == ')'.Rune:
          groupLevel -= 1
          if groupLevel == 0:
            break
        
        # Add to group contents
        groupContents.add(RegexNode(kind: Literal, codePoint: runes[i]))
        i += 1
      
      if i < runes.len:
        i += 1  # Skip closing parenthesis
        
      # Add the group node
      nodes.add(RegexNode(
        kind: Group,
        groupNumber: 1,  # Simplified - would track group numbers
        groupContents: groupContents
      ))
      
    elif r == '|'.Rune:
      # Alternation
      # Simplified - doesn't handle complex alternations
      i += 1
      
    else:
      # Literal character
      nodes.add(RegexNode(kind: Literal, codePoint: r))
      i += 1
  
  result.compiled = nodes

# Basic regex matching implementation
proc match(regex: UnicodeRegexPattern, text: string, 
           caseSensitive: bool = true): UnicodeRegexMatch =
  var match = UnicodeRegexMatch(
    matched: false,
    matchedString: "",
    startPos: -1,
    endPos: -1,
    captures: @[]
  )
  
  # Simplified matcher that only works for basic patterns
  # A real implementation would be much more complex
  let runes = text.toRunes
  
  # Try to find a match starting at each position
  for startPos in 0..<runes.len:
    var currentPos = startPos
    var matched = true
    var i = 0
    
    while i < regex.compiled.len and currentPos < runes.len:
      let node = regex.compiled[i]
      
      case node.kind:
        of Literal:
          # Match literal character
          if caseSensitive:
            if runes[currentPos] != node.codePoint:
              matched = false
              break
          else:
            if not unicodeEqualCaseInsensitive(runes[currentPos], node.codePoint):
              matched = false
              break
          currentPos += 1
          
        of CharClass:
          # Match character class
          let inClass = isInCharClass(runes[currentPos], node.charClass)
          if (inClass and node.negated) or (not inClass and not node.negated):
            matched = false
            break
          currentPos += 1
          
        of Any:
          # Match any character
          if node.dotMatchesNewline or runes[currentPos] != '\n'.Rune:
            currentPos += 1
          else:
            matched = false
            break
          
        of Assertion:
          # Handle assertions
          case node.assertionType:
            of StartOfString:
              if currentPos != 0:
                matched = false
                break
            of EndOfString:
              if currentPos != runes.len:
                matched = false
                break
            of WordBoundary:
              let prevIsWord = (currentPos > 0 and isInCharClass(runes[currentPos-1], AlphaNumeric))
              let currIsWord = (currentPos < runes.len and isInCharClass(runes[currentPos], AlphaNumeric))
              if prevIsWord == currIsWord:
                matched = false
                break
            of NotWordBoundary:
              let prevIsWord = (currentPos > 0 and isInCharClass(runes[currentPos-1], AlphaNumeric))
              let currIsWord = (currentPos < runes.len and isInCharClass(runes[currentPos], AlphaNumeric))
              if prevIsWord != currIsWord:
                matched = false
                break
            else:
              # Not implemented
              discard
          
        of Quantifier:
          # Handle quantifiers (simplified)
          var count = 0
          var innerPos = currentPos
          
          # Try to match the inner pattern as many times as possible
          while count < node.max and innerPos < runes.len:
            var innerMatched = true
            var tempPos = innerPos
            
            # Try to match the inner pattern once
            for innerNode in node.inner:
              case innerNode.kind:
                of Literal:
                  # Match literal character
                  if caseSensitive:
                    if tempPos >= runes.len or runes[tempPos] != innerNode.codePoint:
                      innerMatched = false
                      break
                  else:
                    if tempPos >= runes.len or 
                       not unicodeEqualCaseInsensitive(runes[tempPos], innerNode.codePoint):
                      innerMatched = false
                      break
                  tempPos += 1
                  
                of CharClass:
                  # Match character class
                  if tempPos >= runes.len:
                    innerMatched = false
                    break
                    
                  let inClass = isInCharClass(runes[tempPos], innerNode.charClass)
                  if (inClass and innerNode.negated) or (not inClass and not innerNode.negated):
                    innerMatched = false
                    break
                  tempPos += 1
                  
                of Any:
                  # Match any character
                  if tempPos >= runes.len:
                    innerMatched = false
                    break
                    
                  if innerNode.dotMatchesNewline or runes[tempPos] != '\n'.Rune:
                    tempPos += 1
                  else:
                    innerMatched = false
                    break
                    
                else:
                  # Not implemented
                  innerMatched = false
                  break
            
            if not innerMatched:
              break
              
            innerPos = tempPos
            count += 1
          
          # Check if we matched enough times
          if count < node.min:
            matched = false
            break
            
          currentPos = innerPos
          
        of Group, Alternation, BackRef:
          # Not implemented in this simplified example
          matched = false
          break
      
      i += 1
    
    if matched:
      # We found a match
      match.matched = true
      match.startPos = startPos
      match.endPos = currentPos
      match.matchedString = text.substr(startPos, currentPos - 1)
      break
  
  return match

# Find all matches in a text
proc findAll(regex: UnicodeRegexPattern, text: string, 
             caseSensitive: bool = true): seq[UnicodeRegexMatch] =
  result = @[]
  var startPos = 0
  let textLen = text.len
  
  while startPos < textLen:
    var current = text.substr(startPos)
    let match = regex.match(current, caseSensitive)
    
    if match.matched:
      # Adjust positions to account for offset
      var adjustedMatch = match
      adjustedMatch.startPos += startPos
      adjustedMatch.endPos += startPos
      result.add(adjustedMatch)
      
      # Move to after this match
      startPos = adjustedMatch.endPos
    else:
      # No more matches
      break

# Create a Unicode-aware regular expression
proc newUnicodeRegex(pattern: string): UnicodeRegexPattern =
  return parseUnicodeRegex(pattern)

# Create a demo for Unicode regex pattern matching
proc demonstrateUnicodeRegexBasics(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Basic Unicode Regex Functionality:", Style(attrs: {AttrBold}))
  
  let examples = @[
    ("\\p{Letter}+", "Hello 你好 مرحبا", "Match letters across scripts"),
    ("\\p{Digit}+", "123 ٤٥٦ ৭৮৯", "Match digits across scripts"),
    ("\\p{Emoji}", "Text with emoji: 😀👍🌍", "Match emoji characters"),
    ("\\b\\w+\\b", "Hello, 世界!", "Word boundaries with mixed scripts"),
    ("^\\p{Lu}\\p{Ll}+", "Hello world", "Uppercase followed by lowercase"),
    (".+", "Unicode → UTF-8", "Any character (including symbols)"),
    ("\\p{Script=Han}", "你好 Hello 안녕", "Script-specific matching")
  ]
  
  var yPos = y + 1
  
  for i, example in examples:
    let pattern = example[0]
    let text = example[1]
    let description = example[2]
    
    buffer.print(x, yPos, $i & ". Pattern: " & pattern)
    yPos += 1
    buffer.print(x, yPos, "   Text: " & text)
    yPos += 1
    
    # Parse and match
    let regex = newUnicodeRegex(pattern)
    let match = regex.match(text)
    
    if match.matched:
      buffer.print(x, yPos, "   Match: \"" & match.matchedString & 
                 "\" at positions " & $match.startPos & "-" & $match.endPos)
    else:
      buffer.print(x, yPos, "   No match")
    
    yPos += 1
    buffer.print(x, yPos, "   Purpose: " & description)
    yPos += 2
  
  return

# Demo case-insensitive matching across scripts
proc demonstrateUnicodeCaseInsensitive(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Unicode Case-Insensitive Matching:", Style(attrs: {AttrBold}))
  
  let examples = @[
    ("hello", "HELLO", "ASCII case folding"),
    ("café", "CAFÉ", "Latin accented case folding"),
    ("straße", "STRASSE", "German special case (ß/SS)"),
    ("İstanbul", "istanbul", "Turkish dotted/dotless i"),
    ("μάικ", "ΜΆΙΚ", "Greek case folding"),
    ("привет", "ПРИВЕТ", "Cyrillic case folding")
  ]
  
  var yPos = y + 1
  
  for i, example in examples:
    let pattern = example[0]
    let text = example[1]
    let description = example[2]
    
    buffer.print(x, yPos, $i & ". Pattern: " & pattern)
    yPos += 1
    buffer.print(x, yPos, "   Text: " & text)
    yPos += 1
    
    # Case-sensitive match
    let regex1 = newUnicodeRegex(pattern)
    let match1 = regex1.match(text, true)
    
    buffer.print(x, yPos, "   Case-sensitive: " & 
               (if match1.matched: "Match" else: "No match"))
    yPos += 1
    
    # Case-insensitive match
    let regex2 = newUnicodeRegex(pattern)
    let match2 = regex2.match(text, false)
    
    buffer.print(x, yPos, "   Case-insensitive: " & 
               (if match2.matched: "Match" else: "No match"))
    yPos += 1
    
    buffer.print(x, yPos, "   Note: " & description)
    yPos += 2
  
  return

# Demo grapheme cluster matching
proc demonstrateGraphemeClusterMatching(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Grapheme Cluster Matching:", Style(attrs: {AttrBold}))
  
  let examples = @[
    ("e\u0301", "é", "Combining acute accent"),
    ("n\u0303", "ñ", "Combining tilde"),
    ("a\u0308", "ä", "Combining diaeresis"),
    ("Z\u0302\u0308", "Ẑ̈", "Multiple combining marks"),
    ("👨\u200D👩\u200D👧\u200D👦", "👨‍👩‍👧‍👦", "Family emoji with ZWJ sequences"),
    ("👍\uD83C\uDFFF", "👍🏿", "Emoji with skin tone modifier")
  ]
  
  var yPos = y + 1
  
  for i, example in examples:
    let decomposed = example[0]
    let composed = example[1]
    let description = example[2]
    
    buffer.print(x, yPos, $i & ". Decomposed: " & decomposed & 
               " (" & $decomposed.runeLen & " code points)")
    yPos += 1
    buffer.print(x, yPos, "   Composed: " & composed & 
               " (" & $composed.runeLen & " code points)")
    yPos += 1
    
    # Match decomposed against composed
    let decompRegex = newUnicodeRegex(decomposed)
    let match1 = decompRegex.match(composed)
    
    buffer.print(x, yPos, "   Decomposed → Composed: " & 
               (if match1.matched: "Match" else: "No match"))
    yPos += 1
    
    # Match composed against decomposed
    let compRegex = newUnicodeRegex(composed)
    let match2 = compRegex.match(decomposed)
    
    buffer.print(x, yPos, "   Composed → Decomposed: " & 
               (if match2.matched: "Match" else: "No match"))
    yPos += 1
    
    # Note about canonically equivalent matching
    buffer.print(x, yPos, "   Note: " & description & 
               " (needs normalization for proper matching)")
    yPos += 2
  
  return

# Demo bidirectional text matching
proc demonstrateBidirectionalMatching(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Bidirectional Text Matching:", Style(attrs: {AttrBold}))
  
  let examples = @[
    ("\\bHello\\b", "Hello مرحبا", "English word in mixed text"),
    ("\\p{Script=Arabic}+", "مرحبا بالعالم Hello", "Arabic text in mixed content"),
    ("\\p{Script=Latin}+", "Hello مرحبا World", "Latin text in mixed content"),
    ("^\\p{Script=Arabic}", "مرحبا Hello", "Start of string with RTL text"),
    ("\\p{Script=Latin}$", "مرحبا Hello", "End of string with LTR text"),
    ("\\bمرحبا\\b", "Hello مرحبا", "Arabic word in mixed text")
  ]
  
  var yPos = y + 1
  
  for i, example in examples:
    let pattern = example[0]
    let text = example[1]
    let description = example[2]
    
    buffer.print(x, yPos, $i & ". Pattern: " & pattern)
    yPos += 1
    buffer.print(x, yPos, "   Text: " & text & " (visual display may differ)")
    yPos += 1
    
    # Parse and match
    let regex = newUnicodeRegex(pattern)
    let match = regex.match(text)
    
    if match.matched:
      buffer.print(x, yPos, "   Match: \"" & match.matchedString & 
                 "\" at positions " & $match.startPos & "-" & $match.endPos)
    else:
      buffer.print(x, yPos, "   No match")
    
    yPos += 1
    buffer.print(x, yPos, "   Purpose: " & description)
    yPos += 2
  
  return

# Demo finding all matches
proc demonstrateFindAll(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Finding All Matches:", Style(attrs: {AttrBold}))
  
  let examples = @[
    ("\\p{L}+", "Hello 你好 مرحبا World", "Find all words in mixed scripts"),
    ("\\d+", "Page 123, Line 456, Code 789", "Find all numbers"),
    ("\\p{Emoji}", "Mood today: 😀🙂😐😕😢", "Find all emoji characters"),
    ("\\b\\w{3,}\\b", "The big dog ran to the cat", "Find words with 3+ characters")
  ]
  
  var yPos = y + 1
  
  for i, example in examples:
    let pattern = example[0]
    let text = example[1]
    let description = example[2]
    
    buffer.print(x, yPos, $i & ". Pattern: " & pattern)
    yPos += 1
    buffer.print(x, yPos, "   Text: " & text)
    yPos += 1
    
    # Find all matches
    let regex = newUnicodeRegex(pattern)
    let matches = regex.findAll(text)
    
    buffer.print(x, yPos, "   Matches (" & $matches.len & "):")
    yPos += 1
    
    for j, match in matches:
      buffer.print(x + 4, yPos, $j & ". \"" & match.matchedString & 
                "\" at positions " & $match.startPos & "-" & $match.endPos)
      yPos += 1
    
    buffer.print(x, yPos, "   Purpose: " & description)
    yPos += 2
  
  return

# Demonstrating regex replacements
proc demonstrateReplacement(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Regex Replacements:", Style(attrs: {AttrBold}))
  
  let examples = @[
    ("\\b\\p{L}+\\b", "Hello 你好 مرحبا", "[WORD]", "Replace all words"),
    ("\\p{Emoji}", "Mood: 😀👍🌟", "●", "Replace emojis with dot"),
    ("\\d+", "Page 123, Line 456", "{num}", "Replace numbers with placeholder"),
    ("\\b(\\p{Lu}\\p{Ll}+)\\b", "Hello World", "**$1**", "Emphasize capitalized words")
  ]
  
  var yPos = y + 1
  
  for i, example in examples:
    let pattern = example[0]
    let text = example[1]
    let replacement = example[2]
    let description = example[3]
    
    buffer.print(x, yPos, $i & ". Pattern: " & pattern)
    yPos += 1
    buffer.print(x, yPos, "   Text: " & text)
    yPos += 1
    buffer.print(x, yPos, "   Replacement: " & replacement)
    yPos += 1
    
    # Find all matches and simulate replacement
    let regex = newUnicodeRegex(pattern)
    let matches = regex.findAll(text)
    
    # Simulate replacement (simplified)
    var result = text
    var offset = 0
    
    for match in matches:
      let replLen = replacement.len
      let matchLen = match.endPos - match.startPos
      
      # Apply offset adjustments for previous replacements
      let adjustedStart = match.startPos + offset
      let adjustedEnd = match.endPos + offset
      
      # Replace this match
      result = result[0..<adjustedStart] & replacement & result[adjustedEnd..^1]
      
      # Update offset for subsequent replacements
      offset += replLen - matchLen
    
    buffer.print(x, yPos, "   Result: " & result)
    yPos += 1
    buffer.print(x, yPos, "   Purpose: " & description)
    yPos += 2
  
  return

# Interactive regex tester
proc interactiveRegexTester(buffer: var Buffer, x, y: int, width: int, height: int) =
  # Header
  buffer.print(x, y, "Interactive Unicode Regex Tester:", Style(attrs: {AttrBold}))
  
  # Draw input areas
  let inputX = x + 2
  let inputY = y + 2
  
  # Draw pattern input area
  buffer.print(inputX, inputY, "Pattern: ")
  buffer.print(inputX, inputY + 1, "Text: ")
  
  # Draw input boxes
  for i in 0..1:
    let boxY = inputY + i
    
    # Draw horizontal lines
    for j in 0..<40:
      buffer.print(inputX + 10 + j, boxY, "─")
      buffer.print(inputX + 10 + j, boxY + 1, "─")
    
    # Draw vertical lines
    buffer.print(inputX + 10 - 1, boxY, "┌")
    buffer.print(inputX + 10 - 1, boxY + 1, "└")
    buffer.print(inputX + 10 + 40, boxY, "┐")
    buffer.print(inputX + 10 + 40, boxY + 1, "┘")
    
    # Draw vertical lines
    for j in 0..0:
      buffer.print(inputX + 10 - 1, boxY + j, "│")
      buffer.print(inputX + 10 + 40, boxY + j, "│")
  
  # Draw options area
  let optionsY = inputY + 3
  buffer.print(inputX, optionsY, "Options:", Style(attrs: {AttrBold}))
  
  buffer.print(inputX + 2, optionsY + 1, "(i) Case insensitive")
  buffer.print(inputX + 2, optionsY + 2, "(a) Find all matches")
  
  # Draw results area
  let resultsY = optionsY + 4
  buffer.print(inputX, resultsY, "Results:", Style(attrs: {AttrBold}))
  
  # Draw initial help text
  buffer.print(inputX + 2, resultsY + 2, "Enter a regex pattern and text to test")
  buffer.print(inputX, height - 2, "Press ESC to exit, TAB to switch between inputs")
  
  # Draw buffer initially
  drawBuffer(buffer)
  
  # Set up state for interactive input
  var 
    pattern = ""
    text = ""
    currentField = 0  # 0 for pattern, 1 for text
    caseSensitive = true
    findAll = false
    running = true
  
  proc updateDisplay() =
    # Clear input fields
    for i in 0..1:
      let boxY = inputY + i
      for j in 0..<38:
        buffer.print(inputX + 11 + j, boxY, " ")
    
    # Display current values
    buffer.print(inputX + 11, inputY, pattern)
    buffer.print(inputX + 11, inputY + 1, text)
    
    # Highlight current field
    let boxY = inputY + currentField
    let fieldText = if currentField == 0: pattern else: text
    buffer.print(inputX + 11, boxY, fieldText, Style(bg: ColorBlue))
    
    # Show current options
    let caseStr = if caseSensitive: "Case sensitive" else: "Case insensitive"
    let findAllStr = if findAll: "Find all matches" else: "Find first match"
    
    buffer.print(inputX + 25, optionsY + 1, caseStr, Style(fg: ColorGreen))
    buffer.print(inputX + 25, optionsY + 2, findAllStr, Style(fg: ColorGreen))
    
    # Clear results area
    for i in 0..<15:
      buffer.print(inputX + 2, resultsY + 2 + i, " ".repeat(width - inputX - 4))
    
    # Try to match
    if pattern.len > 0 and text.len > 0:
      let regex = newUnicodeRegex(pattern)
      
      try:
        if findAll:
          let matches = regex.findAll(text, caseSensitive)
          
          if matches.len > 0:
            buffer.print(inputX + 2, resultsY + 2, "Found " & $matches.len & " matches:")
            
            for i, match in matches:
              if i < 10:  # Limit to 10 matches to avoid overflow
                buffer.print(inputX + 4, resultsY + 4 + i*2, "Match " & $(i+1) & ": \"" & 
                          match.matchedString & "\" at positions " & 
                          $match.startPos & "-" & $match.endPos)
                
                # Visualize match in text (if it fits)
                if match.startPos >= 0 and match.endPos <= text.len:
                  var displayText = text
                  displayText.insert("[", match.startPos)
                  displayText.insert("]", match.endPos + 1)  # +1 for the inserted [
                  buffer.print(inputX + 6, resultsY + 5 + i*2, "In context: " & displayText)
          else:
            buffer.print(inputX + 2, resultsY + 2, "No matches found")
        else:
          let match = regex.match(text, caseSensitive)
          
          if match.matched:
            buffer.print(inputX + 2, resultsY + 2, "Match found:")
            buffer.print(inputX + 4, resultsY + 4, "Text: \"" & match.matchedString & 
                       "\" at positions " & $match.startPos & "-" & $match.endPos)
            
            # Visualize match in text
            if match.startPos >= 0 and match.endPos <= text.len:
              var displayText = text
              displayText.insert("[", match.startPos)
              displayText.insert("]", match.endPos + 1)  # +1 for the inserted [
              buffer.print(inputX + 4, resultsY + 6, "In context: " & displayText)
          else:
            buffer.print(inputX + 2, resultsY + 2, "No match found")
      except:
        buffer.print(inputX + 2, resultsY + 2, "Error in regex pattern")
    
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
          if currentField == 0 and pattern.len > 0:
            pattern.setLen(max(0, pattern.len - 1))
          elif currentField == 1 and text.len > 0:
            text.setLen(max(0, text.len - 1))
          updateDisplay()
          
        elif key.key == KeyEnter:
          # Validate and update
          updateDisplay()
          
        else:
          # Handle option toggles
          if key.ch == 'i'.Rune:
            caseSensitive = not caseSensitive
            updateDisplay()
          elif key.ch == 'a'.Rune:
            findAll = not findAll
            updateDisplay()
            
          # Add character to current field
          elif key.ch != 0:
            let ch = $key.ch
            if currentField == 0:
              pattern.add(ch)
            else:
              text.add(ch)
            updateDisplay()
          
      of EventResize:
        # Handle resize event
        let (newWidth, newHeight) = raw.getTerminalSize()
        buffer = newBuffer(newWidth, newHeight)
        clearScreen()
        
        # Redraw everything (simplified)
        interactiveRegexTester(buffer, x, y, newWidth, newHeight)
        
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
    buffer.print(2, 1, "Unicode-aware Regular Expressions", titleStyle)
    
    # Description
    buffer.print(2, 3, "Demonstration of Unicode regex functionality across scripts and languages")
    
    # Section styles
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Section 1: Basic demos
    buffer.print(2, 5, "1. Basic Unicode Regex Features", sectionStyle)
    demonstrateUnicodeRegexBasics(buffer, 4, 7)
    
    # Section 2: Case-insensitive demos
    buffer.print(2, 25, "2. Unicode Case-Insensitive Matching", sectionStyle)
    demonstrateUnicodeCaseInsensitive(buffer, 4, 27)
    
    # Section 3: Grapheme cluster demos
    buffer.print(2, 45, "3. Grapheme Cluster Matching", sectionStyle)
    demonstrateGraphemeClusterMatching(buffer, 4, 47)
    
    # Section 4: Bidirectional text
    buffer.print(2, 65, "4. Bidirectional Text Matching", sectionStyle)
    demonstrateBidirectionalMatching(buffer, 4, 67)
    
    # Section 5: Find all matches
    buffer.print(2, 85, "5. Finding All Matches", sectionStyle)
    demonstrateFindAll(buffer, 4, 87)
    
    # Section 6: Replacements
    buffer.print(2, 105, "6. Regex Replacements", sectionStyle)
    demonstrateReplacement(buffer, 4, 107)
    
    # Section 7: Interactive tester
    buffer.print(2, 125, "7. Interactive Unicode Regex Tester", sectionStyle)
    
    buffer.print(4, 127, "Press any key to start the interactive tester, or ESC to exit")
    
    # Draw buffer
    drawBuffer(buffer)
    
    # Wait for key before starting interactive part
    let event = input.pollEvent()
    
    if event.kind != EventKey or event.key.key != KeyEscape:
      clearScreen()
      buffer = newBuffer(width, height)
      interactiveRegexTester(buffer, 2, 5, width - 4, height - 7)

when isMainModule:
  main()