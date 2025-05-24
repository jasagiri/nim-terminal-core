# unicode_performance_strategies.nim
## Performance Optimization Strategies for Unicode Processing
##
## This example demonstrates advanced techniques for optimizing
## Unicode text processing in terminal applications, including
## caching strategies, partial processing, and incremental updates.

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/times
import std/algorithm
import std/math
import std/sequtils
import std/os

type
  UnicodeCache = object
    widthCache: Table[string, int]
    graphemeCache: Table[string, seq[GraphemeCluster]]
    segmentCache: Table[string, seq[string]]
    textDirectionCache: Table[string, TextDirection]
    cacheHits: int
    cacheMisses: int

  TextDirection = enum
    LeftToRight, RightToLeft

# Initialize a global cache
var globalCache = UnicodeCache(
  widthCache: initTable[string, int](),
  graphemeCache: initTable[string, seq[GraphemeCluster]](),
  segmentCache: initTable[string, seq[string]](),
  textDirectionCache: initTable[string, TextDirection](),
  cacheHits: 0,
  cacheMisses: 0
)

# Advanced Technique 1: Multi-level caching strategy
proc getDisplayWidthCached(text: string): int =
  ## Calculates display width with multi-level caching
  ## 1. Check exact string cache first (fastest)
  ## 2. Check for cached segments (medium)
  ## 3. Calculate from scratch (slowest)
  
  # Level 1: Direct cache hit
  if text in globalCache.widthCache:
    globalCache.cacheHits += 1
    return globalCache.widthCache[text]
  
  globalCache.cacheMisses += 1
  
  # Level 2: Check if we have cached segments
  let textLen = text.len
  if textLen > 20:
    # Try to find cached segments that make up this string
    var segmentStart = 0
    var totalWidth = 0
    var uncachedParts: seq[tuple[start, finish: int]] = @[]
    
    while segmentStart < textLen:
      let segmentEnd = min(segmentStart + 20, textLen)
      let segment = text[segmentStart..<segmentEnd]
      
      if segment in globalCache.widthCache:
        globalCache.cacheHits += 1
        totalWidth += globalCache.widthCache[segment]
      else:
        uncachedParts.add((segmentStart, segmentEnd))
      
      segmentStart = segmentEnd
    
    # If we have uncached parts, calculate them
    if uncachedParts.len > 0:
      for part in uncachedParts:
        let segment = text[part.start..<part.finish]
        let width = displayWidth(segment)
        globalCache.widthCache[segment] = width
        totalWidth += width
    
    # Cache the entire string for future reference
    globalCache.widthCache[text] = totalWidth
    return totalWidth
  
  # Level 3: Calculate from scratch
  let width = displayWidth(text)
  globalCache.widthCache[text] = width
  return width

# Advanced Technique 2: Partial text processing
proc getVisibleTextWidth(text: string, startPos, visibleWidth: int): int =
  ## Calculates width of only the visible portion of text
  ## This avoids processing the entire string when only part is visible
  
  if text.len == 0 or visibleWidth <= 0:
    return 0
  
  let clusters = unicode_utils.splitIntoGraphemeClusters(text)
  var currentPos = 0
  var currentWidth = 0
  
  # Skip clusters until we reach the start position
  var clusterIdx = 0
  while clusterIdx < clusters.len:
    let cluster = clusters[clusterIdx]
    if currentPos >= startPos:
      break
      
    for r in cluster.codePoints:
      currentPos += toUTF8(r).len
    
    currentWidth += cluster.width
    clusterIdx += 1
  
  # Calculate width of visible portion
  var visibleTextWidth = 0
  var processedWidth = 0
  
  while clusterIdx < clusters.len and processedWidth < visibleWidth:
    let cluster = clusters[clusterIdx]
    processedWidth += cluster.width
    
    if processedWidth <= visibleWidth:
      visibleTextWidth += cluster.width
    
    clusterIdx += 1
  
  return visibleTextWidth

# Advanced Technique 3: Lazy evaluation with generators
iterator graphemeClusters(text: string): GraphemeCluster =
  ## Generates grapheme clusters on-demand without processing the whole string
  
  if text.len == 0:
    return
  
  var currentCluster = GraphemeCluster(codePoints: @[], width: 0)
  var runes = toRunes(text)
  var i = 0
  
  while i < runes.len:
    let r = runes[i]
    
    # Start a new cluster if needed
    if currentCluster.codePoints.len == 0:
      currentCluster = GraphemeCluster(
        codePoints: @[r],
        width: runeWidth(r),
        isEmoji: detectEmojiPresentation(r) == EmojiGraphic
      )
    else:
      # Check if this rune is an extender
      if unicode_utils.isExtender(r):
        # Add to current cluster
        currentCluster.codePoints.add(r)
        # Update properties
        let width = runeWidth(r)
        if width > 0:
          currentCluster.width += width
      else:
        # Finish current cluster and yield it
        yield currentCluster
        currentCluster = GraphemeCluster(
          codePoints: @[r],
          width: runeWidth(r),
          isEmoji: detectEmojiPresentation(r) == EmojiGraphic
        )
    
    i += 1
  
  # Yield the last cluster if there is one
  if currentCluster.codePoints.len > 0:
    yield currentCluster

# Advanced Technique 4: Region-based processing
type
  TextRegion = object
    text: string
    startPos: int
    endPos: int
    processingState: int  # 0=unprocessed, 1=partially processed, 2=fully processed
    lastModified: float   # Timestamp of last modification

  RegionalTextProcessor = object
    regions: seq[TextRegion]
    regionSize: int
    cacheEnabled: bool

proc newRegionalProcessor(regionSize: int = 100, cacheEnabled: bool = true): RegionalTextProcessor =
  ## Creates a new regional text processor
  result.regionSize = regionSize
  result.cacheEnabled = cacheEnabled
  result.regions = @[]

proc setText(processor: var RegionalTextProcessor, text: string) =
  ## Sets text and divides it into regions for efficient processing
  
  processor.regions = @[]
  
  # Divide text into regions
  var pos = 0
  while pos < text.len:
    let endPos = min(pos + processor.regionSize, text.len)
    processor.regions.add(TextRegion(
      text: text[pos..<endPos],
      startPos: pos,
      endPos: endPos,
      processingState: 0,
      lastModified: epochTime()
    ))
    pos = endPos

proc processRegion(processor: var RegionalTextProcessor, regionIdx: int) =
  ## Process a specific region of text
  
  if regionIdx < 0 or regionIdx >= processor.regions.len:
    return
    
  var region = processor.regions[regionIdx]
  
  # Skip if already processed and caching is enabled
  if processor.cacheEnabled and region.processingState == 2:
    return
  
  # Process the region
  if not (region.text in globalCache.graphemeCache):
    globalCache.graphemeCache[region.text] = unicode_utils.splitIntoGraphemeClusters(region.text)
  
  if not (region.text in globalCache.widthCache):
    globalCache.widthCache[region.text] = displayWidth(region.text)
  
  # Mark as processed
  region.processingState = 2
  processor.regions[regionIdx] = region

proc getTextAtPosition(processor: var RegionalTextProcessor, pos: int, length: int): string =
  ## Gets text at position, processing only the necessary regions
  
  if pos < 0 or processor.regions.len == 0:
    return ""
  
  # Find which regions we need
  var startRegion = -1
  var endRegion = -1
  
  for i, region in processor.regions:
    if pos >= region.startPos and pos < region.endPos:
      startRegion = i
    
    if pos + length > region.startPos and pos + length <= region.endPos:
      endRegion = i
  
  if startRegion == -1:
    return ""
  
  if endRegion == -1:
    endRegion = processor.regions.high
  
  # Process required regions
  for i in startRegion..endRegion:
    processor.processRegion(i)
  
  # Collect text from regions
  var result = ""
  for i in startRegion..endRegion:
    let region = processor.regions[i]
    
    # Calculate overlap with region
    let overlapStart = max(pos - region.startPos, 0)
    let overlapEnd = min(pos + length - region.startPos, region.text.len)
    
    if overlapStart < overlapEnd:
      result.add(region.text[overlapStart..<overlapEnd])
  
  return result

# Advanced Technique 5: Incremental update
type
  ChangeOperation = enum
    Insert, Delete, Replace
    
  TextChange = object
    operation: ChangeOperation
    position: int
    oldText: string
    newText: string
    
  IncrementalTextBuffer = object
    text: string
    graphemeClusters: seq[GraphemeCluster]
    widthByPosition: Table[int, int]  # Cumulative width at positions
    changesQueue: seq[TextChange]
    lastProcessed: int

proc newIncrementalBuffer(): IncrementalTextBuffer =
  result.text = ""
  result.graphemeClusters = @[]
  result.widthByPosition = initTable[int, int]()
  result.changesQueue = @[]
  result.lastProcessed = 0

proc applyChanges(buffer: var IncrementalTextBuffer) =
  ## Process all queued changes efficiently
  
  if buffer.changesQueue.len == 0:
    return
    
  # Sort changes by position (descending) so earlier changes don't affect positions for later ones
  buffer.changesQueue.sort(proc(a, b: TextChange): int = b.position - a.position)
  
  var invalidateFromPos = buffer.text.len
  
  # Apply all changes
  for change in buffer.changesQueue:
    # Validate position
    if change.position < 0 or change.position > buffer.text.len:
      continue
      
    case change.operation:
      of Insert:
        buffer.text.insert(change.newText, change.position)
      of Delete:
        if change.position + change.oldText.len <= buffer.text.len:
          buffer.text.delete(change.position, change.position + change.oldText.len - 1)
      of Replace:
        if change.position + change.oldText.len <= buffer.text.len:
          buffer.text.delete(change.position, change.position + change.oldText.len - 1)
          buffer.text.insert(change.newText, change.position)
    
    # Track earliest position that needs reprocessing
    invalidateFromPos = min(invalidateFromPos, change.position)
  
  # Clear change queue
  buffer.changesQueue = @[]
  
  # Invalidate cached data from the earliest changed position
  if invalidateFromPos < buffer.text.len:
    var keysToRemove: seq[int] = @[]
    for pos in buffer.widthByPosition.keys:
      if pos >= invalidateFromPos:
        keysToRemove.add(pos)
    
    for pos in keysToRemove:
      buffer.widthByPosition.del(pos)
    
    # Reprocess grapheme clusters if needed
    buffer.lastProcessed = min(buffer.lastProcessed, invalidateFromPos)
    
    # Recalculate grapheme clusters from invalidated position
    if buffer.lastProcessed < buffer.text.len:
      let newText = buffer.text[buffer.lastProcessed..^1]
      let newClusters = unicode_utils.splitIntoGraphemeClusters(newText)
      
      # Replace clusters from that position
      let clusterPos = buffer.getClusterIndexForPosition(buffer.lastProcessed)
      if clusterPos >= 0:
        buffer.graphemeClusters.delete(clusterPos..buffer.graphemeClusters.high)
        for cluster in newClusters:
          buffer.graphemeClusters.add(cluster)
      else:
        # Just append
        for cluster in newClusters:
          buffer.graphemeClusters.add(cluster)
      
      buffer.lastProcessed = buffer.text.len

proc getClusterIndexForPosition(buffer: IncrementalTextBuffer, position: int): int =
  ## Finds grapheme cluster index for a given text position
  
  if position <= 0:
    return 0
    
  if position >= buffer.text.len:
    return buffer.graphemeClusters.len
  
  var currentPos = 0
  for i, cluster in buffer.graphemeClusters:
    if currentPos >= position:
      return i
      
    for r in cluster.codePoints:
      currentPos += toUTF8(r).len
  
  return buffer.graphemeClusters.len

proc queueInsert(buffer: var IncrementalTextBuffer, position: int, text: string) =
  buffer.changesQueue.add(TextChange(
    operation: Insert,
    position: position,
    newText: text,
    oldText: ""
  ))

proc queueDelete(buffer: var IncrementalTextBuffer, position: int, length: int) =
  if position < 0 or position >= buffer.text.len or length <= 0:
    return
    
  let endPos = min(position + length, buffer.text.len)
  buffer.changesQueue.add(TextChange(
    operation: Delete,
    position: position,
    oldText: buffer.text[position..<endPos],
    newText: ""
  ))

proc queueReplace(buffer: var IncrementalTextBuffer, position: int, length: int, text: string) =
  if position < 0 or position >= buffer.text.len or length <= 0:
    return
    
  let endPos = min(position + length, buffer.text.len)
  buffer.changesQueue.add(TextChange(
    operation: Replace,
    position: position,
    oldText: buffer.text[position..<endPos],
    newText: text
  ))

proc getWidth(buffer: var IncrementalTextBuffer, position: int): int =
  ## Gets cumulative width at position with incremental calculation
  
  if position <= 0:
    return 0
    
  if position >= buffer.text.len:
    # Make sure all changes are applied
    buffer.applyChanges()
    
    # Process all text if needed
    if buffer.lastProcessed < buffer.text.len:
      discard buffer.getWidth(buffer.text.len - 1)
    
    # Get total width
    return buffer.getClusterWidth(0, buffer.graphemeClusters.len)
  
  # Check if already cached
  if position in buffer.widthByPosition:
    return buffer.widthByPosition[position]
  
  # Find nearest cached position before this one
  var nearestPos = 0
  var nearestWidth = 0
  
  for pos, width in buffer.widthByPosition.pairs:
    if pos <= position and pos > nearestPos:
      nearestPos = pos
      nearestWidth = width
  
  # Apply any pending changes
  buffer.applyChanges()
  
  # Calculate width from nearest cached position
  if nearestPos < position:
    let remainingText = buffer.text[nearestPos..<position]
    let remainingWidth = displayWidth(remainingText)
    let totalWidth = nearestWidth + remainingWidth
    
    # Cache the result
    buffer.widthByPosition[position] = totalWidth
    return totalWidth
  else:
    # Calculate from start
    let width = displayWidth(buffer.text[0..<position])
    buffer.widthByPosition[position] = width
    return width

proc getClusterWidth(buffer: IncrementalTextBuffer, startCluster, endCluster: int): int =
  ## Gets total width of a range of clusters
  
  if startCluster >= endCluster:
    return 0
    
  if startCluster < 0:
    return 0
    
  if endCluster > buffer.graphemeClusters.len:
    return 0
  
  var width = 0
  for i in startCluster..<endCluster:
    width += buffer.graphemeClusters[i].width
  
  return width

# Benchmarking functions
proc runBenchmark(name: string, iterations: int, fn: proc()) =
  let startTime = epochTime()
  
  for i in 0..<iterations:
    fn()
  
  let endTime = epochTime()
  let totalTime = endTime - startTime
  let timePerIteration = totalTime / iterations.float * 1000  # ms
  
  echo name, ": ", formatFloat(timePerIteration, ffDecimal, 2), " ms per iteration"

proc generateTestText(size: int): string =
  ## Generates mixed Unicode test text of specified size
  
  let asciiChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  let unicodeChars = ["你", "好", "こ", "ん", "に", "ち", "は", "안", "녕", "하", "세", "요"]
  let emoji = ["😀", "👍", "🚀", "🌍", "🎮", "🍕", "📱", "🐱"]
  let combining = ["\u0301", "\u0300", "\u0302", "\u0308", "\u0303"]  # accents
  
  var result = ""
  var i = 0
  
  while result.len < size:
    # Mix ASCII (70%), Unicode (20%), emoji (5%), combining chars (5%)
    let r = rand(100)
    
    if r < 70:
      # ASCII
      result.add(asciiChars[rand(asciiChars.high)])
    elif r < 90:
      # Unicode
      result.add(unicodeChars[rand(unicodeChars.high)])
    elif r < 95:
      # Emoji
      result.add(emoji[rand(emoji.high)])
    else:
      # Combining
      if result.len > 0:
        result.add(combining[rand(combining.high)])
    
    i += 1
  
  return result

# Main example
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
    buffer.print(2, 1, "Unicode Performance Optimization Strategies", titleStyle)
    
    # Description
    buffer.print(2, 3, "Benchmarking different techniques for efficient Unicode text processing")
    
    # Section styles
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Generate test data
    let smallText = generateTestText(100)
    let mediumText = generateTestText(1000)
    let largeText = generateTestText(10000)
    
    # Section 1: Caching Strategies
    buffer.print(2, 5, "1. Multi-level Caching Strategies", sectionStyle)
    
    # Initialize cache stats
    globalCache.cacheHits = 0
    globalCache.cacheMisses = 0
    
    # Benchmark standard width calculation vs cached
    buffer.print(4, 7, "Standard vs Cached Width Calculation (10000 iterations):")
    
    # Standard calculation
    var standardTime = 0.0
    runBenchmark("Standard width calculation", 10000, proc() =
      discard displayWidth(mediumText)
    )
    
    # Cached calculation
    globalCache.widthCache.clear()  # Start with empty cache
    runBenchmark("Cached width calculation", 10000, proc() =
      discard getDisplayWidthCached(mediumText)
    )
    
    # Show cache stats
    buffer.print(4, 10, "Cache hits: " & $globalCache.cacheHits)
    buffer.print(4, 11, "Cache misses: " & $globalCache.cacheMisses)
    buffer.print(4, 12, "Hit ratio: " & formatFloat(globalCache.cacheHits.float / 
                                       (globalCache.cacheHits + globalCache.cacheMisses).float * 100, 
                                       ffDecimal, 2) & "%")
    
    # Section 2: Partial Processing
    buffer.print(2, 14, "2. Partial Text Processing", sectionStyle)
    
    # Benchmark full vs partial processing
    buffer.print(4, 16, "Full vs Partial Text Processing (1000 iterations):")
    
    # Full processing
    runBenchmark("Full text width calculation", 1000, proc() =
      discard displayWidth(largeText)
    )
    
    # Partial processing (visible portion only)
    let visibleWidth = min(80, width - 10)
    runBenchmark("Visible portion only", 1000, proc() =
      discard getVisibleTextWidth(largeText, 0, visibleWidth)
    )
    
    # Section 3: Incremental Updates
    buffer.print(2, 20, "3. Incremental Text Updates", sectionStyle)
    
    # Create buffers for comparison
    var standardBuffer = ""
    var incrementalBuffer = newIncrementalBuffer()
    
    buffer.print(4, 22, "Standard vs Incremental Updates (1000 small changes):")
    
    # Standard approach
    runBenchmark("Standard text manipulation", 1000, proc() =
      standardBuffer = mediumText
      for i in 0..<10:
        let pos = rand(standardBuffer.high)
        standardBuffer.insert("X", pos)
      discard displayWidth(standardBuffer)
    )
    
    # Incremental approach
    runBenchmark("Incremental text buffer", 1000, proc() =
      incrementalBuffer = newIncrementalBuffer()
      incrementalBuffer.text = mediumText
      
      for i in 0..<10:
        let pos = rand(mediumText.high)
        incrementalBuffer.queueInsert(pos, "X")
      
      incrementalBuffer.applyChanges()
      discard incrementalBuffer.getWidth(incrementalBuffer.text.len)
    )
    
    # Section 4: Region-based Processing
    buffer.print(2, 26, "4. Region-based Text Processing", sectionStyle)
    
    # Create processors
    var regionalProcessor = newRegionalProcessor(regionSize = 100)
    regionalProcessor.setText(largeText)
    
    buffer.print(4, 28, "Full vs Regional Processing (1000 random accesses):")
    
    # Standard random access
    runBenchmark("Standard random access", 1000, proc() =
      for i in 0..<10:
        let pos = rand(largeText.high - 20)
        let segment = largeText[pos..<(pos+20)]
        discard displayWidth(segment)
    )
    
    # Regional processing
    runBenchmark("Regional processing", 1000, proc() =
      for i in 0..<10:
        let pos = rand(largeText.high - 20)
        discard regionalProcessor.getTextAtPosition(pos, 20)
    )
    
    # Section 5: Lazy Evaluation
    buffer.print(2, 32, "5. Lazy Evaluation with Generators", sectionStyle)
    
    buffer.print(4, 34, "Eager vs Lazy Evaluation (1000 iterations):")
    
    # Eager evaluation
    runBenchmark("Eager (process all)", 1000, proc() =
      let clusters = unicode_utils.splitIntoGraphemeClusters(largeText)
      for cluster in clusters:
        if cluster.width > 1:  # Just do something to prevent optimization
          discard cluster.width
    )
    
    # Lazy evaluation 
    runBenchmark("Lazy (process on-demand)", 1000, proc() =
      for cluster in graphemeClusters(largeText):
        if cluster.width > 1:  # Just do something to prevent optimization
          discard cluster.width
    )
    
    # Section 6: Complex Benchmark Scenario
    buffer.print(2, 38, "6. Real-world Scenario: Text Editor", sectionStyle)
    
    buffer.print(4, 40, "Simulating text editor operations with different strategies:")
    
    # Scenario setup
    const NUM_OPERATIONS = 1000
    const NUM_ITERATIONS = 5
    
    # Standard approach
    runBenchmark("Standard implementation", NUM_ITERATIONS, proc() =
      var text = mediumText
      
      for i in 0..<NUM_OPERATIONS:
        # Randomly insert, delete, or get width
        let op = rand(2)  # 0=insert, 1=delete, 2=width
        
        case op:
          of 0:  # Insert
            let pos = rand(text.high)
            text.insert("X", pos)
          of 1:  # Delete
            if text.len > 1:
              let pos = rand(text.high)
              text.delete(pos..pos)
          else:  # Get width
            let width = displayWidth(text)
    )
    
    # Optimized approach
    runBenchmark("Optimized implementation", NUM_ITERATIONS, proc() =
      var buffer = newIncrementalBuffer()
      buffer.text = mediumText
      
      for i in 0..<NUM_OPERATIONS:
        # Randomly insert, delete, or get width
        let op = rand(2)  # 0=insert, 1=delete, 2=width
        
        case op:
          of 0:  # Insert
            let pos = rand(buffer.text.high)
            buffer.queueInsert(pos, "X")
          of 1:  # Delete
            if buffer.text.len > 1:
              let pos = rand(buffer.text.high)
              buffer.queueDelete(pos, 1)
          else:  # Get width
            discard buffer.getWidth(buffer.text.len)
            
        # Periodically apply changes
        if i mod 10 == 0:
          buffer.applyChanges()
    )
    
    # Section 7: Key Insights
    buffer.print(2, 45, "7. Key Performance Insights", sectionStyle)
    
    let insights = @[
      "• Cache both grapheme clusters and text widths for repeated operations",
      "• Process only visible text portions when handling large documents",
      "• Use incremental updates to avoid reprocessing unchanged text",
      "• Divide text into regions for efficient partial processing",
      "• Defer expensive operations with lazy evaluation",
      "• Batch related text changes before reprocessing",
      "• Prioritize hot paths for optimization (80/20 rule)",
      "• When possible, store pre-computed values rather than recalculating"
    ]
    
    for i, insight in insights:
      buffer.print(4, 47 + i, insight)
    
    # Final draw and wait for key
    drawBuffer(buffer)
    buffer.print(2, height - 2, "Press any key to exit...")
    drawBuffer(buffer)
    discard input.pollEvent()

when isMainModule:
  # Seed random number generator
  randomize()
  main()