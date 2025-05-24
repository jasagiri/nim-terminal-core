# unicode_benchmark.nim
## Unicode Processing Benchmark
## 
## This example benchmarks various Unicode processing operations
## to demonstrate the performance of the enhanced Unicode support.

import libterminal
import std/unicode
import std/times
import std/strutils
import std/random
import std/algorithm

# Timing utility
proc measureTime(name: string, iterations: int, op: proc()) =
  let start = epochTime()
  for i in 1..iterations:
    op()
  let duration = epochTime() - start
  let perOp = duration * 1000 / iterations.float
  
  echo name & ": " & formatFloat(duration * 1000, ffDecimal, 3) & 
       " ms total, " & formatFloat(perOp, ffDecimal, 6) & 
       " ms per operation (" & $iterations & " iterations)"

# Generate a random Unicode string of mixed scripts
proc generateMixedUnicodeString(length: int): string =
  result = ""
  
  # Define character ranges for different scripts
  let scripts = [
    # Latin
    ('\u0041', '\u007A'),  # Basic Latin (A-z)
    # CJK
    ('\u4E00', '\u9FFF'),  # CJK Unified Ideographs
    # Cyrillic
    ('\u0410', '\u044F'),  # Cyrillic
    # Emoji
    ('\u1F600', '\u1F64F'),  # Emoticons
    # Arabic
    ('\u0600', '\u06FF'),  # Arabic
    # Combining marks
    ('\u0300', '\u036F')   # Combining Diacritical Marks
  ]
  
  # Add characters from different scripts
  for i in 1..length:
    let scriptIdx = rand(0..4)  # Skip combining marks as standalone
    let codePoint = rand(scripts[scriptIdx][0].int..scripts[scriptIdx][1].int)
    
    try:
      # Add the character
      result.add(toUTF8(Rune(codePoint)))
      
      # Occasionally add combining marks
      if rand(1.0) < 0.1 and scriptIdx == 0:  # 10% chance, only for Latin
        let combiningMark = rand(
          scripts[5][0].int..scripts[5][1].int
        )
        result.add(toUTF8(Rune(combiningMark)))
    except:
      # Skip invalid code points
      discard

# Create strings of various scripts
proc createTestStrings(): seq[string] =
  result = @[
    # ASCII only
    "The quick brown fox jumps over the lazy dog",
    # Latin with accents
    "Thé quîck brôwn fòx jûmps øver the làzy dög",
    # Mixed scripts
    "English 日本語 한국어 العربية हिन्दी Русский",
    # Emoji
    "😀 👍 🚀 🌍 🎮 🍕 📱 🐱 🏳️‍🌈 👩‍👩‍👧‍👦",
    # Long mixed text
    generateMixedUnicodeString(1000),
    # Lots of combining characters
    "a\u0301e\u0301i\u0301o\u0301u\u0301n\u0303c\u0327z\u030C",
    # Complex bidirectional
    "Latin مرحبا العربية English שלום עברית 你好 End"
  ]

proc main() =
  # Print header
  echo "==== Unicode Processing Benchmark ===="
  echo "Comparing performance of various Unicode operations"
  echo ""
  
  # Create test data
  randomize()
  let testStrings = createTestStrings()
  
  # Print test strings info
  echo "Test Strings:"
  for i, s in testStrings:
    if s.len > 100:
      echo $(i+1) & ". " & s[0..50] & "... (" & $s.len & " bytes)"
    else:
      echo $(i+1) & ". " & s
  echo ""
  
  # 1. Benchmark Rune conversion and counting
  echo "1. Rune Operations"
  echo "--------------------"
  
  for i, s in testStrings:
    let name = "String " & $(i+1) & " - toRunes"
    let iterations = if s.len > 100: 10000 else: 100000
    measureTime(name, iterations, proc() =
      let runes = toRunes(s)
      discard runes.len
    )
  
  echo ""
  
  # 2. Benchmark Grapheme Cluster processing
  echo "2. Grapheme Cluster Operations"
  echo "--------------------"
  
  for i, s in testStrings:
    let name = "String " & $(i+1) & " - splitIntoGraphemeClusters"
    let iterations = if s.len > 100: 1000 else: 10000
    measureTime(name, iterations, proc() =
      let clusters = unicode_utils.splitIntoGraphemeClusters(s)
      discard clusters.len
    )
  
  echo ""
  
  # 3. Benchmark width calculations
  echo "3. Width Calculation Operations"
  echo "--------------------"
  
  for i, s in testStrings:
    let name = "String " & $(i+1) & " - displayWidth"
    let iterations = if s.len > 100: 5000 else: 50000
    measureTime(name, iterations, proc() =
      discard displayWidth(s)
    )
  
  echo ""
  
  # 4. Compare standard vs. advanced print (by measuring processing time)
  echo "4. Print Processing Comparison"
  echo "--------------------"
  
  # Create a dummy buffer for measurement
  var buffer = newBuffer(80, 24)
  
  for i, s in testStrings:
    let name1 = "String " & $(i+1) & " - standard print"
    let iterations = if s.len > 100: 1000 else: 10000
    measureTime(name1, iterations, proc() =
      # Just measure the processing, not the actual drawing
      var tempBuffer = newBuffer(80, 24)
      tempBuffer.print(0, 0, s)
    )
    
    let name2 = "String " & $(i+1) & " - advanced print"
    measureTime(name2, iterations, proc() =
      # Just measure the processing, not the actual drawing
      var tempBuffer = newBuffer(80, 24)
      tempBuffer.printAdvanced(0, 0, s, Style())
    )
  
  echo ""
  
  # 5. Large-scale test with buffer operations
  echo "5. Large Buffer Operations"
  echo "--------------------"
  
  # Create a large random string
  let largeString = generateMixedUnicodeString(5000)
  let chunks = largeString.distribute(50)
  
  measureTime("Fill large buffer with standard print", 10, proc() =
    var largeBuffer = newBuffer(100, 60)
    var y = 0
    for chunk in chunks:
      if y < 60:
        largeBuffer.print(0, y, chunk)
        y += 1
  )
  
  measureTime("Fill large buffer with advanced print", 10, proc() =
    var largeBuffer = newBuffer(100, 60)
    var y = 0
    for chunk in chunks:
      if y < 60:
        largeBuffer.printAdvanced(0, y, chunk, Style())
        y += 1
  )
  
  echo ""
  echo "Benchmark complete!"
  echo "Press Enter to exit..."
  discard readLine(stdin)

when isMainModule:
  main()