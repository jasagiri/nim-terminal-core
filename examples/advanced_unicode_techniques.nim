# advanced_unicode_techniques.nim
## Advanced Unicode Techniques for Terminal Applications
## 
## This example demonstrates sophisticated Unicode text handling techniques
## including intelligent text truncation, composite character building,
## columnar text layout, fuzzy text matching, and performance optimizations.

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/algorithm
import std/times
import std/math
import std/sequtils

# Advanced Unicode technique: Intelligent text truncation
proc smartTruncate(text: string, maxWidth: int, ellipsis: string = "…"): string =
  ## Truncates text at grapheme cluster boundaries while respecting 
  ## the visual width constraints and adding an ellipsis if needed
  
  if maxWidth <= 0:
    return ""
  
  let clusters = unicode_utils.splitIntoGraphemeClusters(text)
  let ellipsisWidth = displayWidth(ellipsis)
  
  # If the text fits, return it as is
  let textWidth = clusters.foldl(a + b.width, 0)
  if textWidth <= maxWidth:
    return text
  
  # Calculate how many clusters we can include
  var currentWidth = 0
  var lastIndex = -1
  
  for i, cluster in clusters:
    # Account for ellipsis in width calculation
    if currentWidth + cluster.width + ellipsisWidth <= maxWidth:
      currentWidth += cluster.width
      lastIndex = i
    else:
      break
  
  # If we can't even fit one character plus ellipsis
  if lastIndex < 0:
    # Just return ellipsis if it fits, otherwise empty string
    return if ellipsisWidth <= maxWidth: ellipsis else: ""
  
  # Construct result from grapheme clusters
  var result = ""
  for i in 0..lastIndex:
    for r in clusters[i].codePoints:
      result.add(toUTF8(r))
  
  # Add ellipsis
  result.add(ellipsis)
  return result

# Advanced Unicode technique: Composite character building
proc buildCompositeChar(base: string, diacritics: seq[string]): string =
  ## Builds a custom composite character by combining a base character
  ## with multiple diacritic marks
  
  result = base
  for mark in diacritics:
    result.add(mark)
  return result

# Advanced Unicode technique: Find nearest word boundary
proc findNearestWordBoundary(text: string, position: int, forward: bool = true): int =
  ## Finds the nearest word boundary (respecting grapheme clusters)
  ## from the given byte position in the direction specified
  
  if text.len == 0:
    return 0
    
  let clusters = unicode_utils.splitIntoGraphemeClusters(text)
  var clusterBoundaries: seq[int] = @[0]  # Start of string
  var currentPos = 0
  
  # Calculate byte positions of all cluster boundaries
  for cluster in clusters:
    for r in cluster.codePoints:
      currentPos += toUTF8(r).len
    clusterBoundaries.add(currentPos)
  
  # Find nearest cluster boundary to position
  var nearestBoundary = 0
  if forward:
    for boundary in clusterBoundaries:
      if boundary > position:
        nearestBoundary = boundary
        break
  else:
    # Go backwards from position
    for i in countdown(clusterBoundaries.high, 0):
      if clusterBoundaries[i] < position:
        nearestBoundary = clusterBoundaries[i]
        break
  
  # Now find word boundary 
  if forward:
    # Find next space or end of string
    var i = nearestBoundary
    while i < text.len:
      let runeSlice = toRunes(text[i..^1])
      if runeSlice.len == 0: break
      if runeSlice[0].isWhiteSpace:
        break
      
      # Move to next cluster boundary
      let nextIndex = clusterBoundaries.find(i) + 1
      if nextIndex >= clusterBoundaries.len:
        i = text.len  # End of string
        break
      i = clusterBoundaries[nextIndex]
    
    return i
  else:
    # Find previous space or start of string
    var i = nearestBoundary
    while i > 0:
      let prevIndex = clusterBoundaries.find(i) - 1
      if prevIndex < 0:
        break
        
      let prevBoundary = clusterBoundaries[prevIndex]
      let runeSlice = toRunes(text[prevBoundary..<i])
      
      if runeSlice.len > 0 and runeSlice[0].isWhiteSpace:
        # Start of word found, move forward to include the word
        return i
      
      i = prevBoundary
    
    return i  # Start of string if no word boundary found

# Advanced Unicode technique: Columnar text layout
proc renderColumnarText(buffer: var Buffer, x, y: int, columns: seq[seq[string]], 
                        columnWidths: seq[int], columnSpacing: int = 2,
                        headerStyle: Style = Style(), rowStyles: seq[Style] = @[]) =
  ## Renders multi-column text with proper Unicode alignment and optional styling
  
  let defaultStyle = Style()
  let numRows = columns[0].len
  let numCols = columns.len
  
  # Determine styles for each row
  var styles = newSeq[Style](numRows)
  for i in 0..<numRows:
    if i < rowStyles.len:
      styles[i] = rowStyles[i]
    else:
      styles[i] = defaultStyle
  
  # Iterate through rows
  for row in 0..<numRows:
    var currentX = x
    
    # Iterate through columns
    for col in 0..<numCols:
      let text = if col < columns.len and row < columns[col].len: columns[col][row] else: ""
      let colWidth = if col < columnWidths.len: columnWidths[col] else: displayWidth(text)
      
      # Get the appropriate style
      let style = if row == 0: headerStyle else: styles[row]
      
      # Print text with proper alignment
      if text.len > 0:
        # Truncate if necessary
        let processedText = smartTruncate(text, colWidth)
        buffer.printAdvanced(currentX, y + row, processedText, style)
      
      # Move to next column position
      currentX += colWidth + columnSpacing
      
# Advanced Unicode technique: Fuzzy text matching
type
  FuzzyMatch = object
    text: string
    score: int

proc fuzzyMatchUnicode(pattern: string, text: string): FuzzyMatch =
  ## Performs Unicode-aware fuzzy matching between a pattern and text
  ## Returns the match score (higher is better)
  
  if pattern.len == 0:
    return FuzzyMatch(text: text, score: 0)
  
  if text.len == 0:
    return FuzzyMatch(text: text, score: 0)
  
  # Convert to lowercase for case-insensitive matching
  let patternRunes = toRunes(pattern.toLower())
  let textRunes = toRunes(text.toLower())
  
  var score = 0
  var patternPos = 0
  var consecutiveMatches = 0
  var lastMatchPos = -1
  
  # Iterate through each character in the text
  for i, r in textRunes:
    # If this character matches the current pattern position
    if patternPos < patternRunes.len and r == patternRunes[patternPos]:
      # Increment score based on match quality
      score += 10  # Base score for a match
      
      # Bonus for consecutive matches
      if lastMatchPos == i - 1:
        consecutiveMatches += 1
        score += consecutiveMatches * 5
      else:
        consecutiveMatches = 1
      
      # Bonus for matching at start of word
      if i == 0 or textRunes[i-1].isWhiteSpace:
        score += 25
        
      # Bonus for matching uppercase letter (acronym match)
      if i < text.len and text[i].isUpperAscii():
        score += 15
      
      # Move to next pattern character
      patternPos += 1
      lastMatchPos = i
      
      # If we matched the entire pattern
      if patternPos >= patternRunes.len:
        # Bonus for complete match
        score += 50
        
        # Penalty for longer texts (prefer shorter matches)
        score -= (textRunes.len - patternRunes.len) div 3
        break
  
  # If we didn't match the complete pattern
  if patternPos < patternRunes.len:
    score = 0  # No partial matches
    
  return FuzzyMatch(text: text, score: score)

proc fuzzySearchUnicode(pattern: string, candidates: seq[string]): seq[FuzzyMatch] =
  ## Searches for pattern in a list of candidates using fuzzy matching
  ## Returns sorted results (best matches first)
  
  result = @[]
  
  for candidate in candidates:
    let match = fuzzyMatchUnicode(pattern, candidate)
    if match.score > 0:
      result.add(match)
  
  # Sort by score (descending)
  result.sort(proc(a, b: FuzzyMatch): int = b.score - a.score)

# Advanced Unicode technique: Highlighting matched text parts
proc highlightMatches(text: string, pattern: string, 
                      highlightStyle: Style = Style(fg: ColorYellow, attrs: {AttrBold})): 
                      tuple[text: string, positions: seq[int]] =
  ## Finds and returns positions where pattern matches in text
  ## for highlighting purposes, respecting grapheme clusters
  
  if pattern.len == 0 or text.len == 0:
    return (text, @[])
  
  let patternRunes = toRunes(pattern.toLower())
  let textRunes = toRunes(text.toLower())
  var positions: seq[int] = @[]
  var patternPos = 0
  
  # Find matching positions
  for i, r in textRunes:
    if patternPos < patternRunes.len and r == patternRunes[patternPos]:
      positions.add(i)
      patternPos += 1
      
      if patternPos >= patternRunes.len:
        break
  
  # If we didn't match the entire pattern, return empty
  if patternPos < patternRunes.len:
    return (text, @[])
    
  return (text, positions)

# Performance optimization: Grapheme cluster cache
var graphemeCache = initTable[string, seq[GraphemeCluster]]()

proc getCachedGraphemeClusters(text: string): seq[GraphemeCluster] =
  ## Gets grapheme clusters with caching for performance
  
  if text in graphemeCache:
    return graphemeCache[text]
  
  let clusters = unicode_utils.splitIntoGraphemeClusters(text)
  graphemeCache[text] = clusters
  return clusters

# Performance optimization: Incremental unicode processing
type
  IncrementalUnicodeBuffer = object
    text: string
    clusters: seq[GraphemeCluster]
    lastProcessedPosition: int
    widthCache: Table[int, int]  # Position -> cumulative width

proc newIncrementalBuffer(): IncrementalUnicodeBuffer =
  result.text = ""
  result.clusters = @[]
  result.lastProcessedPosition = 0
  result.widthCache = initTable[int, int]()

proc append(buffer: var IncrementalUnicodeBuffer, text: string) =
  ## Appends text to the buffer and processes only new content
  
  if text.len == 0:
    return
    
  let oldLength = buffer.text.len
  buffer.text.add(text)
  
  # Process only the newly added text
  let newClusters = unicode_utils.splitIntoGraphemeClusters(buffer.text[oldLength..^1])
  
  # Update cumulative width information
  var currentWidth = 0
  if oldLength > 0 and oldLength in buffer.widthCache:
    currentWidth = buffer.widthCache[oldLength]
  
  # Add new clusters to buffer
  for cluster in newClusters:
    buffer.clusters.add(cluster)
    currentWidth += cluster.width
    buffer.widthCache[buffer.text.len] = currentWidth
  
  buffer.lastProcessedPosition = buffer.text.len

proc insert(buffer: var IncrementalUnicodeBuffer, position: int, text: string) =
  ## Inserts text at specified position and efficiently updates
  
  if position < 0 or position > buffer.text.len:
    return
    
  # Insert the new text
  buffer.text.insert(text, position)
  
  # Reprocess from insertion point
  # This is more efficient than reprocessing the entire string
  let newText = buffer.text[position..^1]
  let newClusters = unicode_utils.splitIntoGraphemeClusters(newText)
  
  # Replace clusters after position
  let positionClusterIndex = buffer.getCumulativeBytePosition(position)
  if positionClusterIndex >= 0:
    buffer.clusters.delete(positionClusterIndex..buffer.clusters.high)
    for cluster in newClusters:
      buffer.clusters.add(cluster)
  
  # Invalidate width cache for positions after insertion
  var positionsToRemove: seq[int] = @[]
  for pos in buffer.widthCache.keys:
    if pos >= position:
      positionsToRemove.add(pos)
  
  for pos in positionsToRemove:
    buffer.widthCache.del(pos)
  
  # Update position tracker
  buffer.lastProcessedPosition = buffer.text.len

proc getCumulativeBytePosition(buffer: IncrementalUnicodeBuffer, clusterIndex: int): int =
  ## Gets byte position in the string for a given cluster index
  
  if clusterIndex < 0 or clusterIndex >= buffer.clusters.len:
    return -1
    
  var pos = 0
  for i in 0..<clusterIndex:
    for r in buffer.clusters[i].codePoints:
      pos += toUTF8(r).len
      
  return pos

proc getDisplayWidth(buffer: IncrementalUnicodeBuffer, startPos, endPos: int): int =
  ## Gets display width between two positions with caching
  
  if startPos >= endPos:
    return 0
    
  if endPos in buffer.widthCache and startPos in buffer.widthCache:
    return buffer.widthCache[endPos] - buffer.widthCache[startPos]
  
  # Calculate and cache widths if needed
  return displayWidth(buffer.text[startPos..<endPos])

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
    buffer.print(2, 1, "Advanced Unicode Techniques", titleStyle)
    
    # Description
    buffer.print(2, 3, "Demonstration of sophisticated Unicode handling techniques")
    
    # Section styles
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Section 1: Intelligent Text Truncation
    buffer.print(2, 5, "1. Intelligent Text Truncation", sectionStyle)
    
    let longText1 = "Regular English text that will be truncated intelligently."
    let longText2 = "Mixed scripts: English, 日本語, العربية, and Emoji 🚀✨"
    let longText3 = "Complex grapheme clusters: Z̴̢̫̝͕̪̩̒͋͒a̸̻̞̐͒̾͑̄̊l̵̢̲̞̯̩͚̩͍̑̓͌g̴̨̝̜̞̖̿̔̀͂̎͘ō̵̺̂̋̌̈́̃̐͐̅̎̕͝ text example"
    
    # Different truncation widths
    for i, width in [20, 15, 10]:
      buffer.print(4, 7 + i*2, "Width " & $width & ":")
      buffer.printAdvanced(16, 7 + i*2, "\"" & smartTruncate(longText1, width) & "\"", Style())
    
    for i, width in [20, 15, 10]:
      buffer.print(4, 13 + i*2, "Width " & $width & " (mixed):")
      buffer.printAdvanced(24, 13 + i*2, "\"" & smartTruncate(longText2, width) & "\"", Style())
    
    for i, width in [25, 15, 10]:
      buffer.print(4, 19 + i*2, "Width " & $width & " (complex):")
      buffer.printAdvanced(26, 19 + i*2, "\"" & smartTruncate(longText3, width) & "\"", Style())
    
    # Section 2: Composite Character Building
    buffer.print(2, 25, "2. Composite Character Building", sectionStyle)
    
    let baseChars = ["a", "e", "i", "o", "u", "n", "A", "E", "O"]
    let diacritics = [
      @["\u0301"],  # acute
      @["\u0300"],  # grave
      @["\u0302"],  # circumflex
      @["\u0308"],  # diaeresis
      @["\u0303"],  # tilde
      @["\u0301", "\u0308"],  # acute + diaeresis
      @["\u0302", "\u0303"],  # circumflex + tilde
      @["\u0306", "\u0301"],  # breve + acute
      @["\u0327", "\u0301"]   # cedilla + acute
    ]
    
    # Create a grid of composite characters
    buffer.print(4, 27, "Building custom composite characters:")
    for i, base in baseChars:
      for j, marks in diacritics:
        if i*diacritics.len + j < 20:  # Limit number of examples
          let x = 6 + (i * 5)
          let y = 29 + j
          let composite = buildCompositeChar(base, marks)
          buffer.printAdvanced(x, y, composite, Style())
          let marksDesc = marks.join("+")
          buffer.print(x + 2, y, "= " & base & " + " & marksDesc)
    
    # Section 3: Columnar Text Layout
    buffer.print(2, 39, "3. Unicode-aware Columnar Layout", sectionStyle)
    
    # Create column data with mixed scripts
    let columns = @[
      @["Name", "John Smith", "张伟", "सुरेश शर्मा", "محمد علي", "🦄 Unicorn"],
      @["Location", "New York", "北京", "मुंबई", "القاهرة", "🌈 Rainbow"],
      @["Profession", "Engineer", "医生", "शिक्षक", "مهندس", "✨ Magic"]
    ]
    
    let columnWidths = @[15, 12, 15]
    let headerStyle = Style(fg: ColorWhite, bg: ColorBlue, attrs: {AttrBold})
    let rowStyles = @[
      Style(),  # Header row is handled separately
      Style(fg: ColorDefault),
      Style(fg: ColorDefault),
      Style(fg: ColorDefault),
      Style(fg: ColorDefault),
      Style(fg: ColorMagenta)
    ]
    
    buffer.print(4, 41, "Properly aligned multi-script table:")
    renderColumnarText(buffer, 4, 43, columns, columnWidths, 2, headerStyle, rowStyles)
    
    # Section 4: Fuzzy Text Matching
    buffer.print(2, 50, "4. Unicode-aware Fuzzy Matching", sectionStyle)
    
    let candidates = @[
      "Apple", 
      "Banana", 
      "Cherry", 
      "Dragon Fruit", 
      "Elderberry",
      "谷歌搜索", 
      "अमेज़न", 
      "مايكروسوفت",
      "Быстрый поиск",
      "Unicode Text Editor 📝",
      "Emoji 🚀 Rocket"
    ]
    
    let searchPatterns = @["apl", "ban", "uni", "龙", "🚀"]
    
    for i, pattern in searchPatterns:
      buffer.print(4, 52 + i*3, "Search for \"" & pattern & "\":")
      let matches = fuzzySearchUnicode(pattern, candidates)
      
      for j, match in matches:
        if j < 3:  # Show top 3 matches
          let result = match.text & " (score: " & $match.score & ")"
          buffer.print(8, 53 + i*3 + j, result)
      
      if matches.len == 0:
        buffer.print(8, 53 + i*3, "No matches found")
    
    # Section 5: Performance Optimizations
    buffer.print(2, 68, "5. Performance Optimizations", sectionStyle)
    
    # Create a performance test with and without caching
    buffer.print(4, 70, "Unicode processing performance:")
    
    let testTexts = @[
      "Simple ASCII text only",
      "Mixed text with emoji 🚀 and CJK 你好",
      "Complex clusters: Z̴̗̞̚a̴̟̘̔̈l̸̺̲̽g̴̖̈̔ỏ̶̘̙ text with 👨‍👩‍👧‍👦 family emoji"
    ]
    
    # Benchmark non-cached vs cached processing
    var startTime = epochTime()
    var iterations = 100
    
    # Non-cached performance
    for i in 0..<iterations:
      for text in testTexts:
        discard unicode_utils.splitIntoGraphemeClusters(text)
        discard displayWidth(text)
    
    let nonCachedTime = epochTime() - startTime
    
    # Clear cache for fairness
    graphemeCache.clear()
    
    # Cached performance
    startTime = epochTime()
    for i in 0..<iterations:
      for text in testTexts:
        discard getCachedGraphemeClusters(text)
        discard displayWidth(text)
    
    let cachedTime = epochTime() - startTime
    let speedup = nonCachedTime / cachedTime
    
    buffer.print(6, 72, "Non-cached: " & formatFloat(nonCachedTime * 1000, ffDecimal, 2) & " ms")
    buffer.print(6, 73, "Cached: " & formatFloat(cachedTime * 1000, ffDecimal, 2) & " ms")
    buffer.print(6, 74, "Speedup: " & formatFloat(speedup, ffDecimal, 2) & "x faster")
    
    # Incremental processing example
    buffer.print(4, 76, "Incremental processing:")
    
    var incBuffer = newIncrementalBuffer()
    startTime = epochTime()
    
    # Add text incrementally
    for i in 0..<100:
      incBuffer.append("Text" & $i & " ")
    
    let incTime = epochTime() - startTime
    
    # Full processing for comparison
    startTime = epochTime()
    var fullText = ""
    for i in 0..<100:
      fullText.add("Text" & $i & " ")
    
    discard unicode_utils.splitIntoGraphemeClusters(fullText)
    let fullTime = epochTime() - startTime
    
    let incSpeedup = fullTime / incTime
    
    buffer.print(6, 78, "Full processing: " & formatFloat(fullTime * 1000, ffDecimal, 2) & " ms")
    buffer.print(6, 79, "Incremental: " & formatFloat(incTime * 1000, ffDecimal, 2) & " ms")
    buffer.print(6, 80, "Speedup: " & formatFloat(incSpeedup, ffDecimal, 2) & "x faster")
    
    # Final draw and wait for key
    drawBuffer(buffer)
    buffer.print(2, height - 2, "Press any key to exit...")
    drawBuffer(buffer)
    discard input.pollEvent()

when isMainModule:
  main()