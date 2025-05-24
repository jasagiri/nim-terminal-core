# unicode_identifiers.nim
## Unicode Identifiers and Security
## 
## This example demonstrates Unicode identifier validation,
## normalization, and security considerations including confusables
## detection and bidirectional controls.

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/algorithm

# Unicode identifier types as defined in UTS #31 and UAX #31
type
  IdentifierStatus = enum
    Valid,             # Valid identifier
    InvalidStart,      # Invalid start character
    InvalidContinue,   # Invalid continuation character
    ConfusableSpoofing,# Contains confusable characters
    MixedScripts,      # Contains mixed scripts (potentially suspicious)
    BidirectionalIssue,# Contains problematic bidirectional characters
    NormalizationIssue,# Not in the required normalization form
    EmptyIdentifier,   # Empty identifier
    RestrictedChar     # Contains restricted characters
    
  IdentifierType = enum
    ProgrammingLanguage, # Follows Unicode Annex #31 (identifier syntax)
    Domain,             # Domain name (IDN)
    Username,           # Username identifier
    Custom              # Custom identifier rules
    
  IdentifierProfile = object
    idType: IdentifierType   # Type of identifier
    allowedStartChars: set[range[0..255]]  # ASCII-only allowed start chars
    allowedContChars: set[range[0..255]]   # ASCII-only allowed continuation chars
    allowedScripts: seq[string]  # Allowed scripts
    normalizationForm: string    # Required normalization form
    caseSensitive: bool          # Whether case matters
    allowEmoji: bool             # Whether emoji are allowed
    restrictedChars: seq[Rune]   # Explicitly restricted characters
    requireNFC: bool             # Require NFC form
    mixedScriptCheck: bool       # Check for suspicious mixed scripts
    confusableCheck: bool        # Check for confusable characters
    bidiCheck: bool              # Check for bidirectional issues

# Create default identifier profiles
proc defaultProgrammingLanguageProfile(): IdentifierProfile =
  # Default profile for most programming languages
  result = IdentifierProfile(
    idType: ProgrammingLanguage,
    # Allow ASCII letters and underscore for start
    allowedStartChars: {'A'..'Z', 'a'..'z', '_'},
    # Allow ASCII letters, digits, and underscore for continuation
    allowedContChars: {'A'..'Z', 'a'..'z', '0'..'9', '_'},
    allowedScripts: @["Latin", "Common"],
    normalizationForm: "NFC",
    caseSensitive: true,
    allowEmoji: false,
    restrictedChars: @[],
    requireNFC: true,
    mixedScriptCheck: false,  # Most languages only allow ASCII anyway
    confusableCheck: false,
    bidiCheck: false
  )

proc defaultDomainProfile(): IdentifierProfile =
  # Default profile for domain names (IDNA2008-like)
  result = IdentifierProfile(
    idType: Domain,
    allowedStartChars: {'A'..'Z', 'a'..'z', '0'..'9'},
    allowedContChars: {'A'..'Z', 'a'..'z', '0'..'9', '-', '.'},
    allowedScripts: @[],  # All scripts allowed with restrictions
    normalizationForm: "NFC",
    caseSensitive: false,
    allowEmoji: false,
    restrictedChars: @[],  # Actual IDNA has many more restrictions
    requireNFC: true,
    mixedScriptCheck: true,
    confusableCheck: true,
    bidiCheck: true
  )

proc defaultUsernameProfile(): IdentifierProfile =
  # Default profile for usernames
  result = IdentifierProfile(
    idType: Username,
    allowedStartChars: {'A'..'Z', 'a'..'z'},
    allowedContChars: {'A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.'},
    allowedScripts: @["Latin", "Common"],
    normalizationForm: "NFKC",
    caseSensitive: false,
    allowEmoji: false,
    restrictedChars: @[],
    requireNFC: true,
    mixedScriptCheck: true,
    confusableCheck: true,
    bidiCheck: true
  )

# Script detection
# Simplified script detection (in reality would use Unicode character database)
proc detectScript(r: Rune): string =
  let cp = r.int32
  
  if cp <= 0x007F:
    return "Latin"  # ASCII range
  elif cp >= 0x0080 and cp <= 0x00FF:
    return "Latin"  # Latin-1 Supplement
  elif cp >= 0x0100 and cp <= 0x017F:
    return "Latin"  # Latin Extended-A
  elif cp >= 0x0180 and cp <= 0x024F:
    return "Latin"  # Latin Extended-B
  elif cp >= 0x0370 and cp <= 0x03FF:
    return "Greek"
  elif cp >= 0x0400 and cp <= 0x04FF:
    return "Cyrillic"
  elif cp >= 0x0500 and cp <= 0x052F:
    return "Cyrillic"  # Cyrillic Supplement
  elif cp >= 0x0530 and cp <= 0x058F:
    return "Armenian"
  elif cp >= 0x0590 and cp <= 0x05FF:
    return "Hebrew"
  elif cp >= 0x0600 and cp <= 0x06FF:
    return "Arabic"
  elif cp >= 0x0700 and cp <= 0x074F:
    return "Syriac"
  elif cp >= 0x0750 and cp <= 0x077F:
    return "Arabic"  # Arabic Supplement
  elif cp >= 0x0900 and cp <= 0x097F:
    return "Devanagari"
  elif cp >= 0x0980 and cp <= 0x09FF:
    return "Bengali"
  elif cp >= 0x0A00 and cp <= 0x0A7F:
    return "Gurmukhi"
  elif cp >= 0x0A80 and cp <= 0x0AFF:
    return "Gujarati"
  elif cp >= 0x0B00 and cp <= 0x0B7F:
    return "Oriya"
  elif cp >= 0x0B80 and cp <= 0x0BFF:
    return "Tamil"
  elif cp >= 0x0C00 and cp <= 0x0C7F:
    return "Telugu"
  elif cp >= 0x0C80 and cp <= 0x0CFF:
    return "Kannada"
  elif cp >= 0x0D00 and cp <= 0x0D7F:
    return "Malayalam"
  elif cp >= 0x0D80 and cp <= 0x0DFF:
    return "Sinhala"
  elif cp >= 0x0E00 and cp <= 0x0E7F:
    return "Thai"
  elif cp >= 0x0E80 and cp <= 0x0EFF:
    return "Lao"
  elif cp >= 0x0F00 and cp <= 0x0FFF:
    return "Tibetan"
  elif cp >= 0x1000 and cp <= 0x109F:
    return "Myanmar"
  elif cp >= 0x10A0 and cp <= 0x10FF:
    return "Georgian"
  elif cp >= 0x1100 and cp <= 0x11FF:
    return "Hangul"
  elif cp >= 0x1200 and cp <= 0x137F:
    return "Ethiopic"
  elif cp >= 0x13A0 and cp <= 0x13FF:
    return "Cherokee"
  elif cp >= 0x1400 and cp <= 0x167F:
    return "Canadian_Aboriginal"
  elif cp >= 0x1680 and cp <= 0x169F:
    return "Ogham"
  elif cp >= 0x16A0 and cp <= 0x16FF:
    return "Runic"
  elif cp >= 0x1700 and cp <= 0x171F:
    return "Tagalog"
  elif cp >= 0x1720 and cp <= 0x173F:
    return "Hanunoo"
  elif cp >= 0x1740 and cp <= 0x175F:
    return "Buhid"
  elif cp >= 0x1760 and cp <= 0x177F:
    return "Tagbanwa"
  elif cp >= 0x1780 and cp <= 0x17FF:
    return "Khmer"
  elif cp >= 0x1800 and cp <= 0x18AF:
    return "Mongolian"
  elif cp >= 0x1900 and cp <= 0x194F:
    return "Limbu"
  elif cp >= 0x1950 and cp <= 0x197F:
    return "Tai_Le"
  elif cp >= 0x19E0 and cp <= 0x19FF:
    return "Khmer"  # Khmer Symbols
  elif cp >= 0x1D00 and cp <= 0x1D7F:
    return "Latin"  # Phonetic Extensions
  elif cp >= 0x1E00 and cp <= 0x1EFF:
    return "Latin"  # Latin Extended Additional
  elif cp >= 0x1F00 and cp <= 0x1FFF:
    return "Greek"  # Greek Extended
  elif cp >= 0x2000 and cp <= 0x206F:
    return "Common"  # General Punctuation
  elif cp >= 0x2070 and cp <= 0x209F:
    return "Common"  # Superscripts and Subscripts
  elif cp >= 0x20A0 and cp <= 0x20CF:
    return "Common"  # Currency Symbols
  elif cp >= 0x20D0 and cp <= 0x20FF:
    return "Inherited"  # Combining Marks for Symbols
  elif cp >= 0x2100 and cp <= 0x214F:
    return "Common"  # Letterlike Symbols
  elif cp >= 0x2150 and cp <= 0x218F:
    return "Common"  # Number Forms
  elif cp >= 0x2190 and cp <= 0x21FF:
    return "Common"  # Arrows
  elif cp >= 0x2200 and cp <= 0x22FF:
    return "Common"  # Mathematical Operators
  elif cp >= 0x2300 and cp <= 0x23FF:
    return "Common"  # Miscellaneous Technical
  elif cp >= 0x2400 and cp <= 0x243F:
    return "Common"  # Control Pictures
  elif cp >= 0x2440 and cp <= 0x245F:
    return "Common"  # Optical Character Recognition
  elif cp >= 0x2460 and cp <= 0x24FF:
    return "Common"  # Enclosed Alphanumerics
  elif cp >= 0x2500 and cp <= 0x257F:
    return "Common"  # Box Drawing
  elif cp >= 0x2580 and cp <= 0x259F:
    return "Common"  # Block Elements
  elif cp >= 0x25A0 and cp <= 0x25FF:
    return "Common"  # Geometric Shapes
  elif cp >= 0x2600 and cp <= 0x26FF:
    return "Common"  # Miscellaneous Symbols
  elif cp >= 0x2700 and cp <= 0x27BF:
    return "Common"  # Dingbats
  elif cp >= 0x2800 and cp <= 0x28FF:
    return "Braille"  # Braille Patterns
  elif cp >= 0x2E80 and cp <= 0x2EFF:
    return "Han"  # CJK Radicals Supplement
  elif cp >= 0x2F00 and cp <= 0x2FDF:
    return "Han"  # Kangxi Radicals
  elif cp >= 0x2FF0 and cp <= 0x2FFF:
    return "Han"  # Ideographic Description Characters
  elif cp >= 0x3000 and cp <= 0x303F:
    return "Han"  # CJK Symbols and Punctuation
  elif cp >= 0x3040 and cp <= 0x309F:
    return "Hiragana"
  elif cp >= 0x30A0 and cp <= 0x30FF:
    return "Katakana"
  elif cp >= 0x3100 and cp <= 0x312F:
    return "Bopomofo"
  elif cp >= 0x3130 and cp <= 0x318F:
    return "Hangul"  # Hangul Compatibility Jamo
  elif cp >= 0x3190 and cp <= 0x319F:
    return "Han"  # Kanbun
  elif cp >= 0x31A0 and cp <= 0x31BF:
    return "Bopomofo"  # Bopomofo Extended
  elif cp >= 0x31F0 and cp <= 0x31FF:
    return "Katakana"  # Katakana Phonetic Extensions
  elif cp >= 0x3200 and cp <= 0x32FF:
    return "Han"  # Enclosed CJK Letters and Months
  elif cp >= 0x3300 and cp <= 0x33FF:
    return "Han"  # CJK Compatibility
  elif cp >= 0x3400 and cp <= 0x4DBF:
    return "Han"  # CJK Unified Ideographs Extension A
  elif cp >= 0x4DC0 and cp <= 0x4DFF:
    return "Common"  # Yijing Hexagram Symbols
  elif cp >= 0x4E00 and cp <= 0x9FFF:
    return "Han"  # CJK Unified Ideographs
  elif cp >= 0xA000 and cp <= 0xA48F:
    return "Yi"  # Yi Syllables
  elif cp >= 0xA490 and cp <= 0xA4CF:
    return "Yi"  # Yi Radicals
  elif cp >= 0xAC00 and cp <= 0xD7AF:
    return "Hangul"  # Hangul Syllables
  elif cp >= 0xD800 and cp <= 0xDB7F:
    return "Unknown"  # High Surrogates
  elif cp >= 0xDB80 and cp <= 0xDBFF:
    return "Unknown"  # High Private Use Surrogates
  elif cp >= 0xDC00 and cp <= 0xDFFF:
    return "Unknown"  # Low Surrogates
  elif cp >= 0xE000 and cp <= 0xF8FF:
    return "Unknown"  # Private Use Area
  elif cp >= 0xF900 and cp <= 0xFAFF:
    return "Han"  # CJK Compatibility Ideographs
  elif cp >= 0xFB00 and cp <= 0xFB4F:
    return "Latin"  # Alphabetic Presentation Forms (Latin ligatures)
  elif cp >= 0xFB50 and cp <= 0xFDFF:
    return "Arabic"  # Arabic Presentation Forms-A
  elif cp >= 0xFE00 and cp <= 0xFE0F:
    return "Inherited"  # Variation Selectors
  elif cp >= 0xFE10 and cp <= 0xFE1F:
    return "Han"  # Vertical Forms
  elif cp >= 0xFE20 and cp <= 0xFE2F:
    return "Inherited"  # Combining Half Marks
  elif cp >= 0xFE30 and cp <= 0xFE4F:
    return "Han"  # CJK Compatibility Forms
  elif cp >= 0xFE50 and cp <= 0xFE6F:
    return "Common"  # Small Form Variants
  elif cp >= 0xFE70 and cp <= 0xFEFF:
    return "Arabic"  # Arabic Presentation Forms-B
  elif cp >= 0xFF00 and cp <= 0xFFEF:
    return "Common"  # Halfwidth and Fullwidth Forms
  elif cp >= 0xFFF0 and cp <= 0xFFFF:
    return "Common"  # Specials
  elif cp >= 0x10000 and cp <= 0x1007F:
    return "Linear_B"
  elif cp >= 0x10080 and cp <= 0x100FF:
    return "Linear_B"
  elif cp >= 0x10100 and cp <= 0x1013F:
    return "Common"  # Aegean Numbers
  elif cp >= 0x10300 and cp <= 0x1032F:
    return "Old_Italic"
  elif cp >= 0x10330 and cp <= 0x1034F:
    return "Gothic"
  elif cp >= 0x10380 and cp <= 0x1039F:
    return "Ugaritic"
  elif cp >= 0x10400 and cp <= 0x1044F:
    return "Deseret"
  elif cp >= 0x10450 and cp <= 0x1047F:
    return "Shavian"
  elif cp >= 0x10480 and cp <= 0x104AF:
    return "Osmanya"
  elif cp >= 0x10800 and cp <= 0x1083F:
    return "Cypriot"
  elif cp >= 0x1D000 and cp <= 0x1D0FF:
    return "Common"  # Byzantine Musical Symbols
  elif cp >= 0x1D100 and cp <= 0x1D1FF:
    return "Common"  # Musical Symbols
  elif cp >= 0x1D300 and cp <= 0x1D35F:
    return "Common"  # Tai Xuan Jing Symbols
  elif cp >= 0x1D400 and cp <= 0x1D7FF:
    return "Common"  # Mathematical Alphanumeric Symbols
  elif cp >= 0x20000 and cp <= 0x2A6DF:
    return "Han"  # CJK Unified Ideographs Extension B
  elif cp >= 0x2F800 and cp <= 0x2FA1F:
    return "Han"  # CJK Compatibility Ideographs Supplement
  elif cp >= 0xE0000 and cp <= 0xE007F:
    return "Common"  # Tags
  elif cp >= 0xE0100 and cp <= 0xE01EF:
    return "Inherited"  # Variation Selectors Supplement
  elif cp >= 0x1F000 and cp <= 0x1F9FF:
    return "Common"  # Emoji ranges
  else:
    return "Unknown"

# Detect all scripts in a string
proc detectScripts(text: string): seq[string] =
  var scripts = initTable[string, int]()
  
  for r in text.toRunes:
    let script = detectScript(r)
    if script != "Common" and script != "Inherited" and script != "Unknown":
      if scripts.hasKey(script):
        scripts[script] += 1
      else:
        scripts[script] = 1
  
  # Get unique scripts
  for script, count in scripts.pairs:
    result.add(script)
  
  return result

# Confusable character detection
# In a real implementation, this would use data from the Unicode confusables.txt file
proc getConfusablePairs(): Table[Rune, seq[Rune]] =
  var confusables = initTable[Rune, seq[Rune]]()
  
  # Latin letters that look like Cyrillic
  confusables['a'.Rune] = @['а'.Rune]  # Cyrillic 'а'
  confusables['e'.Rune] = @['е'.Rune]  # Cyrillic 'е'
  confusables['o'.Rune] = @['о'.Rune]  # Cyrillic 'о'
  confusables['p'.Rune] = @['р'.Rune]  # Cyrillic 'р'
  confusables['c'.Rune] = @['с'.Rune]  # Cyrillic 'с'
  confusables['x'.Rune] = @['х'.Rune]  # Cyrillic 'х'
  
  # Latin letters that look like Greek
  confusables['A'.Rune] = @['Α'.Rune]  # Greek 'Α'
  confusables['B'.Rune] = @['Β'.Rune]  # Greek 'Β'
  confusables['E'.Rune] = @['Ε'.Rune]  # Greek 'Ε'
  confusables['H'.Rune] = @['Η'.Rune]  # Greek 'Η'
  confusables['I'.Rune] = @['Ι'.Rune]  # Greek 'Ι'
  confusables['K'.Rune] = @['Κ'.Rune]  # Greek 'Κ'
  confusables['M'.Rune] = @['Μ'.Rune]  # Greek 'Μ'
  confusables['N'.Rune] = @['Ν'.Rune]  # Greek 'Ν'
  confusables['O'.Rune] = @['Ο'.Rune]  # Greek 'Ο'
  confusables['P'.Rune] = @['Ρ'.Rune]  # Greek 'Ρ'
  confusables['T'.Rune] = @['Τ'.Rune]  # Greek 'Τ'
  confusables['X'.Rune] = @['Χ'.Rune]  # Greek 'Χ'
  confusables['Y'.Rune] = @['Υ'.Rune]  # Greek 'Υ'
  
  # Other confusables
  confusables['l'.Rune] = @['1'.Rune, 'I'.Rune, '|'.Rune]  # digit 1, uppercase I, pipe
  confusables['1'.Rune] = @['l'.Rune, 'I'.Rune, '|'.Rune]  # lowercase l, uppercase I, pipe
  confusables['O'.Rune] = @['0'.Rune]  # digit 0
  confusables['0'.Rune] = @['O'.Rune]  # uppercase O
  
  # Symbols that might be confused
  confusables['-'.Rune] = @['−'.Rune, '‐'.Rune, '‑'.Rune, '‒'.Rune, '–'.Rune, '—'.Rune]  # various dashes
  confusables['.'.Rune] = @['·'.Rune, '․'.Rune, '。'.Rune, '・'.Rune]  # various dots
  
  # Make the mapping bidirectional 
  var additionalMappings = initTable[Rune, seq[Rune]]()
  for original, confusableList in confusables.pairs:
    for confusable in confusableList:
      if additionalMappings.hasKey(confusable):
        if not additionalMappings[confusable].contains(original):
          additionalMappings[confusable].add(original)
      else:
        additionalMappings[confusable] = @[original]
  
  # Merge additional mappings
  for confusable, originalList in additionalMappings.pairs:
    if confusables.hasKey(confusable):
      for original in originalList:
        if not confusables[confusable].contains(original):
          confusables[confusable].add(original)
    else:
      confusables[confusable] = originalList
  
  return confusables

# Check for confusable characters in two strings
proc detectConfusables(a, b: string): bool =
  let confusablePairs = getConfusablePairs()
  
  if a.len != b.len:
    return false
  
  let aRunes = a.toRunes
  let bRunes = b.toRunes
  
  for i in 0..<aRunes.len:
    let aRune = aRunes[i]
    let bRune = bRunes[i]
    
    if aRune == bRune:
      continue
    
    # Check if they are confusable
    if confusablePairs.hasKey(aRune) and confusablePairs[aRune].contains(bRune):
      return true
      
    if confusablePairs.hasKey(bRune) and confusablePairs[bRune].contains(aRune):
      return true
  
  return false

# Check for confusables within a string (mixed-script confusables)
proc containsConfusables(text: string): bool =
  let scripts = detectScripts(text)
  
  # If only one script, no mixed-script confusables
  if scripts.len <= 1:
    return false
  
  # Check for mixed-script confusables
  let confusablePairs = getConfusablePairs()
  let runes = text.toRunes
  
  for i, r in runes:
    if confusablePairs.hasKey(r):
      for confusable in confusablePairs[r]:
        let confusableScript = detectScript(confusable)
        let runeScript = detectScript(r)
        
        if confusableScript != runeScript and
           confusableScript != "Common" and confusableScript != "Inherited" and
           runeScript != "Common" and runeScript != "Inherited":
          return true
  
  return false

# Check for bidirectional control characters which can be misused
proc containsProblematicBidiChars(text: string): bool =
  for r in text.toRunes:
    let cp = r.int32
    
    # Check for RLO, LRO, RLE, LRE, PDF
    if cp == 0x202E or  # RIGHT-TO-LEFT OVERRIDE
       cp == 0x202D or  # LEFT-TO-RIGHT OVERRIDE
       cp == 0x202B or  # RIGHT-TO-LEFT EMBEDDING
       cp == 0x202A or  # LEFT-TO-RIGHT EMBEDDING
       cp == 0x202C:    # POP DIRECTIONAL FORMATTING
      return true
      
    # Check for RLI, LRI, FSI, PDI
    if cp == 0x2067 or  # RIGHT-TO-LEFT ISOLATE
       cp == 0x2066 or  # LEFT-TO-RIGHT ISOLATE
       cp == 0x2068 or  # FIRST STRONG ISOLATE
       cp == 0x2069:    # POP DIRECTIONAL ISOLATE
      return true
  
  return false

# Check if a character is valid as a start character for the given profile
proc isValidStartChar(profile: IdentifierProfile, r: Rune): bool =
  let cp = r.int32
  
  # Check ASCII first (more common and faster)
  if cp <= 0xFF:
    let c = cp.char
    return c in profile.allowedStartChars
  
  # Apply Unicode identifier rules (simplified)
  # In reality, would check UAX #31 ID_Start property
  let category = unicode.getCategory(r)
  
  case profile.idType:
    of ProgrammingLanguage:
      # Most programming languages allow Unicode letters
      return category in {CatLu, CatLl, CatLt, CatLm, CatLo}
      
    of Domain:
      # Domain names allow letters and digits
      return category in {CatLu, CatLl, CatLt, CatLm, CatLo, CatNd}
      
    of Username:
      # Usernames typically allow letters
      return category in {CatLu, CatLl, CatLt, CatLm, CatLo}
      
    of Custom:
      # Default to just letters for custom profiles
      return category in {CatLu, CatLl, CatLt, CatLm, CatLo}

# Check if a character is valid as a continuation character for the given profile
proc isValidContChar(profile: IdentifierProfile, r: Rune): bool =
  let cp = r.int32
  
  # Check ASCII first (more common and faster)
  if cp <= 0xFF:
    let c = cp.char
    return c in profile.allowedContChars
  
  # Apply Unicode identifier rules (simplified)
  # In reality, would check UAX #31 ID_Continue property
  let category = unicode.getCategory(r)
  
  case profile.idType:
    of ProgrammingLanguage:
      # Most programming languages allow Unicode letters and numbers
      return category in {CatLu, CatLl, CatLt, CatLm, CatLo, CatNd, CatNl, CatNo, CatMn, CatMc, CatPc}
      
    of Domain:
      # Domain names allow letters, digits and hyphen
      return category in {CatLu, CatLl, CatLt, CatLm, CatLo, CatNd, CatPd}
      
    of Username:
      # Usernames typically allow letters, digits, and some punctuation
      return category in {CatLu, CatLl, CatLt, CatLm, CatLo, CatNd, CatPd, CatPc}
      
    of Custom:
      # Default to letters and numbers for custom profiles
      return category in {CatLu, CatLl, CatLt, CatLm, CatLo, CatNd, CatNl, CatNo, CatMn, CatMc, CatPc}

# Check if a string contains restricted characters
proc containsRestrictedChars(profile: IdentifierProfile, text: string): bool =
  for r in text.toRunes:
    if profile.restrictedChars.contains(r):
      return true
  
  return false

# Check if a string uses the required normalization form
proc hasCorrectNormalization(text: string, requiredForm: string): bool =
  # In a real implementation, would normalize the string and compare
  # For this example, we'll just assume NFC is always correct
  return true

# Validate an identifier according to the given profile
proc validateIdentifier(text: string, profile: IdentifierProfile): IdentifierStatus =
  if text.len == 0:
    return EmptyIdentifier
    
  # Check normalization form if required
  if profile.requireNFC and not hasCorrectNormalization(text, profile.normalizationForm):
    return NormalizationIssue
  
  # Check for bidirectional issues
  if profile.bidiCheck and containsProblematicBidiChars(text):
    return BidirectionalIssue
  
  # Check for restricted characters
  if containsRestrictedChars(profile, text):
    return RestrictedChar
  
  # Check for mixed scripts if requested
  if profile.mixedScriptCheck:
    let scripts = detectScripts(text)
    
    # If more than one script and allowedScripts is specified
    if scripts.len > 1 and profile.allowedScripts.len > 0:
      var allowed = true
      for script in scripts:
        if not profile.allowedScripts.contains(script):
          allowed = false
          break
      
      if not allowed:
        return MixedScripts
  
  # Check for confusables if requested
  if profile.confusableCheck and containsConfusables(text):
    return ConfusableSpoofing
  
  # Check each character
  let runes = text.toRunes
  
  # Check first character
  if runes.len > 0 and not isValidStartChar(profile, runes[0]):
    return InvalidStart
  
  # Check remaining characters
  for i in 1..<runes.len:
    if not isValidContChar(profile, runes[i]):
      return InvalidContinue
  
  # All checks passed
  return Valid

# Get a description of the identifier status
proc getStatusDescription(status: IdentifierStatus): string =
  case status:
    of Valid:
      return "Valid identifier"
    of InvalidStart:
      return "Invalid start character"
    of InvalidContinue:
      return "Invalid continuation character"
    of ConfusableSpoofing:
      return "Contains confusable characters (potential spoofing)"
    of MixedScripts:
      return "Contains mixed scripts (suspicious)"
    of BidirectionalIssue:
      return "Contains problematic bidirectional characters"
    of NormalizationIssue:
      return "Not in required normalization form"
    of EmptyIdentifier:
      return "Empty identifier"
    of RestrictedChar:
      return "Contains restricted characters"

# Format a rune for display
proc formatRune(r: Rune): string =
  return "U+" & toHex(int(r), 4) & " '" & $r & "'"

# Demonstrate identifier validation
proc demonstrateIdentifierValidation(buffer: var Buffer, x, y: int, profile: IdentifierProfile) =
  let profileName = case profile.idType:
    of ProgrammingLanguage: "Programming Language"
    of Domain: "Domain Name"
    of Username: "Username"
    of Custom: "Custom"
  
  buffer.print(x, y, profileName & " Identifier Rules:", Style(attrs: {AttrBold}))
  
  # Show key profile settings
  buffer.print(x, y+1, "• Normalization: " & profile.normalizationForm)
  buffer.print(x, y+1, "• Case sensitive: " & (if profile.caseSensitive: "Yes" else: "No"))
  buffer.print(x, y+2, "• Allowed ASCII start: " & $profile.allowedStartChars)
  buffer.print(x, y+3, "• Allowed ASCII continue: " & $profile.allowedContChars)
  buffer.print(x, y+4, "• Confusable check: " & (if profile.confusableCheck: "Yes" else: "No"))
  buffer.print(x, y+5, "• Mixed script check: " & (if profile.mixedScriptCheck: "Yes" else: "No"))
  buffer.print(x, y+6, "• Bidi check: " & (if profile.bidiCheck: "Yes" else: "No"))
  
  # Examples to test
  let examples = case profile.idType:
    of ProgrammingLanguage:
      @[
        "validName",
        "valid_name_2",
        "_startWithUnderscore",
        "1InvalidStart",
        "résumé",
        "шеллы",
        "a-b",
        "café",
        "cafĕ",
        "varíable",
        "Ωmega",
        "你好world",
        "i⁇nvalid",
        "аpple",  # Cyrillic 'а'
        "\u202Ehidden\u202C"
      ]
    of Domain:
      @[
        "example.com",
        "sub-domain.example.com",
        "xn--d1acufc.xn--p1ai",  # пример.рф in Punycode
        "help.café",
        "help.cafĕ",
        "a..com",
        "a_b.com",
        "例子.卷筒纸",
        "аpple.com",  # Cyrillic 'а'
        "foo.cоm",  # Cyrillic 'о'
        "foo.\u202Emoc.bar",  # Reversed "com"
        "-.com",
        "a b.com",
        "a\u2068b.com",  # First Strong Isolate
        "exa\u0300mple.com"  # NFD form
      ]
    of Username:
      @[
        "johndoe",
        "john.doe",
        "john_doe",
        "john-doe",
        "jöhndöe",
        "john123",
        "_john",
        "john doe",
        "аdam",  # Cyrillic 'а'
        "adаm",  # Latin 'a' + Cyrillic 'а' + Latin 'm'
        "ωhite",
        "j*doe",
        "xX_l33t_Xx",
        "admin\u202Erotartsinimdauser",  # Hidden "administrator"
        "1234567"
      ]
    of Custom:
      @[
        "custom_example",
        "CUSTOM",
        "123abc",
        "!invalid"
      ]
  
  # Validate each example
  var yPos = y + 8
  
  for example in examples:
    let status = validateIdentifier(example, profile)
    let statusDesc = getStatusDescription(status)
    
    let statusStyle = case status:
      of Valid: Style(fg: ColorGreen)
      else: Style(fg: ColorRed)
    
    buffer.print(x, yPos, "\"" & example & "\":")
    buffer.print(x + 2, yPos + 1, statusDesc, statusStyle)
    
    # Show script information
    let scripts = detectScripts(example)
    var scriptStr = "Scripts: "
    for i, script in scripts:
      if i > 0:
        scriptStr.add(", ")
      scriptStr.add(script)
    
    buffer.print(x + 2, yPos + 2, scriptStr)
    
    # For invalid identifiers, show more details
    if status != Valid:
      case status:
        of InvalidStart:
          let firstRune = example.toRunes[0]
          buffer.print(x + 2, yPos + 3, "Start character: " & formatRune(firstRune))
          
        of InvalidContinue:
          # Find the first invalid continuation character
          let runes = example.toRunes
          for i in 1..<runes.len:
            if not isValidContChar(profile, runes[i]):
              buffer.print(x + 2, yPos + 3, "Invalid character: " & formatRune(runes[i]))
              break
        
        of ConfusableSpoofing:
          buffer.print(x + 2, yPos + 3, "Contains confusable characters")
          
          # Try to identify confusables
          let confusablePairs = getConfusablePairs()
          let runes = example.toRunes
          for r in runes:
            if confusablePairs.hasKey(r):
              var confusableStr = "Character " & formatRune(r) & " similar to: "
              for i, similar in confusablePairs[r]:
                if i > 0:
                  confusableStr.add(", ")
                confusableStr.add(formatRune(similar))
              
              buffer.print(x + 4, yPos + 4, confusableStr)
              break
        
        of MixedScripts:
          buffer.print(x + 2, yPos + 3, "Suspicious mixed scripts")
          
        of BidirectionalIssue:
          buffer.print(x + 2, yPos + 3, "Contains bidirectional controls")
          
          # Show the bidirectional control characters
          let runes = example.toRunes
          for r in runes:
            let cp = r.int32
            if cp >= 0x2066 and cp <= 0x2069 or cp >= 0x202A and cp <= 0x202E:
              buffer.print(x + 4, yPos + 4, "Bidi control: " & formatRune(r))
        
        of NormalizationIssue:
          buffer.print(x + 2, yPos + 3, "Not in " & profile.normalizationForm & " form")
          
        of EmptyIdentifier:
          buffer.print(x + 2, yPos + 3, "Empty identifier")
          
        of RestrictedChar:
          buffer.print(x + 2, yPos + 3, "Contains restricted characters")
          
        else:
          discard
    
    yPos += 5  # Increment by 5 lines for each example
  
  return

# Demonstrate comparison of similar identifiers
proc demonstrateConfusableComparison(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Confusable Identifier Comparison:", Style(attrs: {AttrBold}))
  
  let pairs = @[
    ("apple", "аpple"),  # Latin vs Cyrillic 'a'
    ("google", "gооgle"),  # Latin vs Cyrillic 'o'
    ("paypal", "pаypal"),  # Latin vs Cyrillic 'a'
    ("microsoft", "mіcrosoft"),  # Latin vs Cyrillic 'i'
    ("admin", "admín"),  # Without vs with accent
    ("john.smith", "john․smith"),  # ASCII vs fullwidth dot
    ("user", "úser"),  # Without vs with accent
    ("secure", "sесurе"),  # Latin vs Cyrillic 'e's
    ("login-help", "login‐help"),  # ASCII vs Unicode hyphen
    ("support", "ѕupport")  # Latin vs Cyrillic 's'
  ]
  
  var yPos = y + 1
  
  for pair in pairs:
    let a = pair[0]
    let b = pair[1]
    
    buffer.print(x, yPos, "\"" & a & "\" vs \"" & b & "\"")
    yPos += 1
    
    # Show Unicode representation
    var aRep = "1st: "
    for r in a.toRunes:
      aRep.add("U+" & toHex(int(r), 4) & " ")
    
    var bRep = "2nd: "
    for r in b.toRunes:
      bRep.add("U+" & toHex(int(r), 4) & " ")
    
    buffer.print(x + 2, yPos, aRep)
    yPos += 1
    buffer.print(x + 2, yPos, bRep)
    yPos += 1
    
    # Check if they are confusable
    let confusable = detectConfusables(a, b)
    
    buffer.print(x + 2, yPos, "Confusable: " & (if confusable: "Yes" else: "No"), 
               if confusable: Style(fg: ColorRed) else: Style(fg: ColorGreen))
    yPos += 1
    
    # Show scripts for each
    let aScripts = detectScripts(a)
    let bScripts = detectScripts(b)
    
    var aScriptStr = "1st scripts: "
    for i, script in aScripts:
      if i > 0:
        aScriptStr.add(", ")
      aScriptStr.add(script)
    
    var bScriptStr = "2nd scripts: "
    for i, script in bScripts:
      if i > 0:
        bScriptStr.add(", ")
      bScriptStr.add(script)
    
    buffer.print(x + 2, yPos, aScriptStr)
    yPos += 1
    buffer.print(x + 2, yPos, bScriptStr)
    yPos += 2
  
  return

# Demonstrate script analysis
proc demonstrateScriptAnalysis(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Script Analysis:", Style(attrs: {AttrBold}))
  
  let examples = @[
    ("Hello world", "Basic Latin"),
    ("Привет, мир!", "Cyrillic"),
    ("你好，世界！", "Han (Chinese)"),
    ("こんにちは世界", "Mixed Hiragana and Han"),
    ("안녕하세요 세계", "Hangul (Korean)"),
    ("नमस्ते दुनिया", "Devanagari (Hindi)"),
    ("مرحبا بالعالم", "Arabic"),
    ("שלום עולם", "Hebrew"),
    ("Γειά σου Κόσμε", "Greek"),
    ("Hello მსოფლიო", "Mixed Latin and Georgian"),
    ("ASCII + кириллица + 漢字", "Mixed Latin, Cyrillic, and Han"),
    ("Emoji test 👋🌍", "Latin with Emoji")
  ]
  
  var yPos = y + 1
  
  for example in examples:
    let text = example[0]
    let description = example[1]
    
    buffer.print(x, yPos, "\"" & text & "\" (" & description & ")")
    yPos += 1
    
    # Detect scripts
    let scripts = detectScripts(text)
    
    var scriptStr = "Scripts: "
    for i, script in scripts:
      if i > 0:
        scriptStr.add(", ")
      scriptStr.add(script)
    
    buffer.print(x + 2, yPos, scriptStr)
    yPos += 1
    
    # Analyze each character
    buffer.print(x + 2, yPos, "Character analysis:")
    yPos += 1
    
    let runes = text.toRunes
    for i, r in runes:
      if i < 5:  # Limit to first 5 characters to save space
        let script = detectScript(r)
        buffer.print(x + 4, yPos, formatRune(r) & " - Script: " & script)
        yPos += 1
    
    if runes.len > 5:
      buffer.print(x + 4, yPos, "... and " & $(runes.len - 5) & " more characters")
      yPos += 1
    
    yPos += 1
  
  return

# Demonstrate bidirectional security issues
proc demonstrateBidiSecurity(buffer: var Buffer, x, y: int) =
  buffer.print(x, y, "Bidirectional Text Security:", Style(attrs: {AttrBold}))
  
  let examples = @[
    ("user\u202Eresunoccaym", "Hidden 'myaccount' using RLO (U+202E)"),
    ("hidden\u202Eneddih", "Reverses 'hidden' using RLO"),
    ("safe\u202Dcode\u202Cfile", "Using LRO (U+202D) and PDF (U+202C)"),
    ("innocent\u2067malicious\u2069text", "Using RLI (U+2067) and PDI (U+2069)"),
    ("normal\u2066reversed\u2069text", "Using LRI (U+2066) and PDI (U+2069)"),
    ("first\u2068اختبار\u2069last", "Using FSI (U+2068) for Arabic")
  ]
  
  var yPos = y + 1
  
  for example in examples:
    let text = example[0]
    let description = example[1]
    
    buffer.print(x, yPos, "Example: " & description)
    yPos += 1
    
    buffer.print(x + 2, yPos, "Visual: \"" & text & "\"")
    yPos += 1
    
    # Show Unicode representation
    var codePoints = "Code points: "
    for r in text.toRunes:
      codePoints.add("U+" & toHex(int(r), 4) & " ")
    
    buffer.print(x + 2, yPos, codePoints)
    yPos += 1
    
    # Show which bidirectional controls are used
    buffer.print(x + 2, yPos, "Bidi controls:")
    yPos += 1
    
    let runes = text.toRunes
    for r in runes:
      let cp = r.int32
      if cp == 0x202E:
        buffer.print(x + 4, yPos, "U+202E - RIGHT-TO-LEFT OVERRIDE (RLO)")
        yPos += 1
      elif cp == 0x202D:
        buffer.print(x + 4, yPos, "U+202D - LEFT-TO-RIGHT OVERRIDE (LRO)")
        yPos += 1
      elif cp == 0x202C:
        buffer.print(x + 4, yPos, "U+202C - POP DIRECTIONAL FORMATTING (PDF)")
        yPos += 1
      elif cp == 0x2067:
        buffer.print(x + 4, yPos, "U+2067 - RIGHT-TO-LEFT ISOLATE (RLI)")
        yPos += 1
      elif cp == 0x2066:
        buffer.print(x + 4, yPos, "U+2066 - LEFT-TO-RIGHT ISOLATE (LRI)")
        yPos += 1
      elif cp == 0x2068:
        buffer.print(x + 4, yPos, "U+2068 - FIRST STRONG ISOLATE (FSI)")
        yPos += 1
      elif cp == 0x2069:
        buffer.print(x + 4, yPos, "U+2069 - POP DIRECTIONAL ISOLATE (PDI)")
        yPos += 1
    
    # Show security implications
    let valid = not containsProblematicBidiChars(text)
    buffer.print(x + 2, yPos, "Security check: " & (if valid: "PASS" else: "FAIL"), 
               if valid: Style(fg: ColorGreen) else: Style(fg: ColorRed))
    yPos += 2
  
  return

# Interactive identifier validator
proc interactiveIdentifierValidator(buffer: var Buffer, x, y: int, width: int, height: int) =
  # Header
  buffer.print(x, y, "Interactive Identifier Validator:", Style(attrs: {AttrBold}))
  
  # Draw input area
  let inputX = x + 2
  let inputY = y + 2
  
  # Draw text input area
  buffer.print(inputX, inputY, "Enter identifier: ")
  
  # Draw input box
  # Draw horizontal lines
  for j in 0..<40:
    buffer.print(inputX + 18 + j, inputY, "─")
    buffer.print(inputX + 18 + j, inputY + 1, "─")
  
  # Draw vertical lines
  buffer.print(inputX + 18 - 1, inputY, "┌")
  buffer.print(inputX + 18 - 1, inputY + 1, "└")
  buffer.print(inputX + 18 + 40, inputY, "┐")
  buffer.print(inputX + 18 + 40, inputY + 1, "┘")
  
  # Draw profile selection
  let profileY = inputY + 3
  buffer.print(inputX, profileY, "Profile: (1) Programming Language, (2) Domain, (3) Username")
  
  # Draw results area
  let resultsY = profileY + 2
  buffer.print(inputX, resultsY, "Validation Results:", Style(attrs: {AttrBold}))
  
  # Draw initial help text
  buffer.print(inputX + 2, resultsY + 2, "Enter an identifier to validate")
  buffer.print(inputX, height - 2, "Press ESC to exit")
  
  # Draw buffer initially
  drawBuffer(buffer)
  
  # Set up state for interactive input
  var 
    text = ""
    profileType = ProgrammingLanguage
    running = true
  
  proc updateDisplay() =
    # Clear input field
    for j in 0..<38:
      buffer.print(inputX + 19 + j, inputY, " ")
    
    # Display current text
    buffer.print(inputX + 19, inputY, text)
    
    # Show current profile
    let profileStr = case profileType:
      of ProgrammingLanguage: "Programming Language"
      of Domain: "Domain Name"
      of Username: "Username"
      of Custom: "Custom"
    
    buffer.print(inputX + 60, profileY, profileStr, Style(fg: ColorGreen))
    
    # Clear results area
    for i in 0..<20:
      buffer.print(inputX + 2, resultsY + 2 + i, " ".repeat(width - inputX - 4))
    
    # Process and display results
    if text.len > 0:
      # Get the appropriate profile
      var profile = case profileType:
        of ProgrammingLanguage:
          defaultProgrammingLanguageProfile()
        of Domain:
          defaultDomainProfile()
        of Username:
          defaultUsernameProfile()
        of Custom:
          defaultProgrammingLanguageProfile()  # Default to programming language
      
      # Validate the identifier
      let status = validateIdentifier(text, profile)
      let statusDesc = getStatusDescription(status)
      
      let statusStyle = case status:
        of Valid: Style(fg: ColorGreen)
        else: Style(fg: ColorRed)
      
      buffer.print(inputX + 2, resultsY + 2, "Validation status: " & statusDesc, statusStyle)
      
      # Show Unicode analysis
      buffer.print(inputX + 2, resultsY + 4, "Unicode analysis:")
      
      # Code points
      var codePoints = "Code points: "
      for r in text.toRunes:
        codePoints.add("U+" & toHex(int(r), 4) & " ")
      
      buffer.print(inputX + 4, resultsY + 5, codePoints)
      
      # Scripts
      let scripts = detectScripts(text)
      var scriptStr = "Scripts: "
      for i, script in scripts:
        if i > 0:
          scriptStr.add(", ")
        scriptStr.add(script)
      
      buffer.print(inputX + 4, resultsY + 6, scriptStr)
      
      # Show detailed validation issues if any
      if status != Valid:
        buffer.print(inputX + 2, resultsY + 8, "Validation issues:")
        
        case status:
          of InvalidStart:
            let firstRune = text.toRunes[0]
            buffer.print(inputX + 4, resultsY + 9, "Invalid start character: " & formatRune(firstRune))
            buffer.print(inputX + 4, resultsY + 10, "Allowed ASCII start: " & $profile.allowedStartChars)
            
          of InvalidContinue:
            # Find the first invalid continuation character
            let runes = text.toRunes
            for i in 1..<runes.len:
              if not isValidContChar(profile, runes[i]):
                buffer.print(inputX + 4, resultsY + 9, "Invalid character at position " & $i & ": " & formatRune(runes[i]))
                break
            
            buffer.print(inputX + 4, resultsY + 10, "Allowed ASCII continuation: " & $profile.allowedContChars)
            
          of ConfusableSpoofing:
            buffer.print(inputX + 4, resultsY + 9, "Contains confusable characters (potential spoofing)")
            
            # Try to identify confusables
            let confusablePairs = getConfusablePairs()
            let runes = text.toRunes
            for r in runes:
              if confusablePairs.hasKey(r):
                var confusableStr = "Character " & formatRune(r) & " similar to: "
                for i, similar in confusablePairs[r]:
                  if i > 0:
                    confusableStr.add(", ")
                  confusableStr.add(formatRune(similar))
                
                buffer.print(inputX + 6, resultsY + 10, confusableStr)
                break
            
          of MixedScripts:
            buffer.print(inputX + 4, resultsY + 9, "Contains mixed scripts (potentially suspicious)")
            buffer.print(inputX + 4, resultsY + 10, "Reason: Mixed scripts can be used for spoofing attacks")
            
            if profile.allowedScripts.len > 0:
              var allowedStr = "Allowed scripts: "
              for i, script in profile.allowedScripts:
                if i > 0:
                  allowedStr.add(", ")
                allowedStr.add(script)
              
              buffer.print(inputX + 4, resultsY + 11, allowedStr)
            
          of BidirectionalIssue:
            buffer.print(inputX + 4, resultsY + 9, "Contains bidirectional control characters (security risk)")
            
            # Show the bidirectional control characters
            let runes = text.toRunes
            for i, r in runes:
              let cp = r.int32
              if cp >= 0x2066 and cp <= 0x2069 or cp >= 0x202A and cp <= 0x202E:
                buffer.print(inputX + 6, resultsY + 10 + i, "Position " & $i & ": " & formatRune(r))
            
          of NormalizationIssue:
            buffer.print(inputX + 4, resultsY + 9, "Not in required normalization form (" & profile.normalizationForm & ")")
            buffer.print(inputX + 4, resultsY + 10, "Reason: Different normalization forms can be used for spoofing")
            
          of EmptyIdentifier:
            buffer.print(inputX + 4, resultsY + 9, "Empty identifier is not allowed")
            
          of RestrictedChar:
            buffer.print(inputX + 4, resultsY + 9, "Contains restricted characters")
            
            # Show restricted characters
            let runes = text.toRunes
            for i, r in runes:
              if profile.restrictedChars.contains(r):
                buffer.print(inputX + 6, resultsY + 10 + i, "Position " & $i & ": " & formatRune(r))
            
          else:
            discard
      
      # Security recommendations
      buffer.print(inputX + 2, resultsY + 14, "Security recommendations:")
      
      buffer.print(inputX + 4, resultsY + 15, "• Always normalize identifiers to NFC or NFKC form")
      buffer.print(inputX + 4, resultsY + 16, "• Check for confusable characters when accepting user input")
      buffer.print(inputX + 4, resultsY + 17, "• Be cautious with identifiers using multiple scripts")
      buffer.print(inputX + 4, resultsY + 18, "• Reject identifiers with bidirectional control characters")
      buffer.print(inputX + 4, resultsY + 19, "• Consider using an ASCII-only profile for critical systems")
    
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
          # Handle number keys for profile selection
          if key.ch >= '1'.Rune and key.ch <= '3'.Rune:
            profileType = case int(key.ch) - int('0'.Rune):
              of 1: ProgrammingLanguage
              of 2: Domain
              of 3: Username
              else: ProgrammingLanguage
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
        interactiveIdentifierValidator(buffer, x, y, newWidth, newHeight)
        
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
    buffer.print(2, 1, "Unicode Identifiers and Security", titleStyle)
    
    # Description
    buffer.print(2, 3, "Demonstration of Unicode identifier validation and security considerations")
    
    # Section styles
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Section 1: Programming Language Identifiers
    buffer.print(2, 5, "1. Programming Language Identifiers", sectionStyle)
    
    buffer.print(4, 7, "Programming language identifiers typically follow UAX #31 rules:")
    buffer.print(4, 8, "- Start with letter or underscore")
    buffer.print(4, 9, "- Continue with letters, digits, or underscores")
    buffer.print(4, 10, "- Case-sensitive")
    buffer.print(4, 11, "- NFC normalization recommended")
    
    demonstrateIdentifierValidation(buffer, 4, 13, defaultProgrammingLanguageProfile())
    
    # Section 2: Domain Names
    let domainY = 85  # Approximate position after the previous section
    buffer.print(2, domainY, "2. Domain Name Identifiers", sectionStyle)
    
    buffer.print(4, domainY + 2, "Domain names follow IDNA2008 rules:")
    buffer.print(4, domainY + 3, "- Allow letters, digits, and hyphen")
    buffer.print(4, domainY + 4, "- Case-insensitive")
    buffer.print(4, domainY + 5, "- Strict normalization and security checks")
    buffer.print(4, domainY + 6, "- Many restricted characters and sequences")
    
    demonstrateIdentifierValidation(buffer, 4, domainY + 8, defaultDomainProfile())
    
    # Section 3: Username Identifiers
    let usernameY = 145  # Approximate position after the previous section
    buffer.print(2, usernameY, "3. Username Identifiers", sectionStyle)
    
    buffer.print(4, usernameY + 2, "Username identifiers typically follow these rules:")
    buffer.print(4, usernameY + 3, "- Start with letter")
    buffer.print(4, usernameY + 4, "- Continue with letters, digits, underscore, hyphen, or dot")
    buffer.print(4, usernameY + 5, "- Case-insensitive")
    buffer.print(4, usernameY + 6, "- NFKC normalization recommended")
    buffer.print(4, usernameY + 7, "- Strict security checks for spoofing")
    
    demonstrateIdentifierValidation(buffer, 4, usernameY + 9, defaultUsernameProfile())
    
    # Section 4: Script Analysis
    let scriptY = 200  # Approximate position after the previous section
    buffer.print(2, scriptY, "4. Script Analysis", sectionStyle)
    
    buffer.print(4, scriptY + 2, "Script detection is important for security:")
    buffer.print(4, scriptY + 3, "- Mixed scripts can indicate spoofing attempts")
    buffer.print(4, scriptY + 4, "- Single-script policies reduce security risks")
    buffer.print(4, scriptY + 5, "- Script properties come from the Unicode Character Database")
    
    demonstrateScriptAnalysis(buffer, 4, scriptY + 7)
    
    # Section 5: Confusable Detection
    let confusableY = 240  # Approximate position after the previous section
    buffer.print(2, confusableY, "5. Confusable Detection", sectionStyle)
    
    buffer.print(4, confusableY + 2, "Confusable characters pose security risks:")
    buffer.print(4, confusableY + 3, "- Look similar or identical but have different code points")
    buffer.print(4, confusableY + 4, "- Can be used for spoofing attacks")
    buffer.print(4, confusableY + 5, "- Often span multiple scripts")
    
    demonstrateConfusableComparison(buffer, 4, confusableY + 7)
    
    # Section 6: Bidirectional Text Security
    let bidiY = 280  # Approximate position after the previous section
    buffer.print(2, bidiY, "6. Bidirectional Text Security", sectionStyle)
    
    buffer.print(4, bidiY + 2, "Bidirectional control characters pose risks:")
    buffer.print(4, bidiY + 3, "- Can hide part of an identifier")
    buffer.print(4, bidiY + 4, "- Can make malicious text appear innocent")
    buffer.print(4, bidiY + 5, "- Should be restricted in identifiers")
    
    demonstrateBidiSecurity(buffer, 4, bidiY + 7)
    
    # Section 7: Interactive Validator
    let interactiveY = 330  # Approximate position after the previous section
    buffer.print(2, interactiveY, "7. Interactive Identifier Validator", sectionStyle)
    
    buffer.print(4, interactiveY + 2, "Press any key to start the interactive validator, or ESC to exit")
    
    # Draw buffer
    drawBuffer(buffer)
    
    # Wait for key before starting interactive part
    let event = input.pollEvent()
    
    if event.kind != EventKey or event.key.key != KeyEscape:
      clearScreen()
      buffer = newBuffer(width, height)
      interactiveIdentifierValidator(buffer, 2, 5, width - 4, height - 7)

when isMainModule:
  main()