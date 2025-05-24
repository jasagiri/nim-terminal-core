# unicode_charts_example.nim
## Unicode Charts and Data Visualization
## 
## This example demonstrates using Unicode characters for
## creating charts and data visualizations in the terminal.

import libterminal
import std/unicode
import std/strutils
import std/random
import std/math
import std/algorithm
import std/tables
import std/times

type
  ChartType = enum
    BarChart, LineChart, PieChart, StackedBarChart, HeatMap

  DataPoint = object
    label: string
    value: float
    color: RGBColor
    category: string

  HeatMapData = object
    values: seq[seq[float]]
    rowLabels: seq[string]
    colLabels: seq[string]
    minValue, maxValue: float

# Color utility functions
proc gradientColor(value, minVal, maxVal: float, lowColor, highColor: RGBColor): RGBColor =
  # Create a color gradient between low and high colors
  if maxVal == minVal:
    return lowColor
  
  let ratio = clamp((value - minVal) / (maxVal - minVal), 0.0, 1.0)
  
  result.r = uint8(lowColor.r.float * (1.0 - ratio) + highColor.r.float * ratio)
  result.g = uint8(lowColor.g.float * (1.0 - ratio) + highColor.g.float * ratio)
  result.b = uint8(lowColor.b.float * (1.0 - ratio) + highColor.b.float * ratio)

# Bar chart with Unicode block characters
proc drawBarChart(buffer: var Buffer, x, y, width, height: int, 
                 data: seq[DataPoint], title: string) =
  # Draw title
  let titleStyle = Style(fg: ColorCyan, bg: ColorDefault, attrs: {AttrBold})
  buffer.print(x + (width div 2) - (title.len div 2), y, title, titleStyle)
  
  # Find maximum value for scaling
  var maxValue = 0.0
  for point in data:
    maxValue = max(maxValue, point.value)
  
  # Calculate bar width and spacing
  let maxBarWidth = (width - 10) div data.len
  let barWidth = min(maxBarWidth, 5)
  let spacing = if data.len > 1: (width - 10 - barWidth * data.len) div (data.len - 1) else: 0
  
  # Draw axis
  let axisStyle = Style(fg: ColorWhite, bg: ColorDefault)
  
  # Y-axis
  for i in 0..height-3:
    buffer.print(x, y + 2 + i, "│", axisStyle)
  
  # X-axis
  buffer.print(x, y + height - 1, "└" & "─".repeat(width - 2), axisStyle)
  
  # Draw Y-axis labels
  let labelStyle = Style(fg: ColorYellow, bg: ColorDefault)
  for i in 0..4:
    let labelValue = maxValue * (4 - i) / 4
    let label = fmt"{labelValue:>7.1f}"
    buffer.print(x - 8, y + 2 + i * (height - 3) div 4, label, labelStyle)
  
  # Draw bars
  for i, point in data:
    let barHeight = int((point.value / maxValue) * (height - 3).float)
    let startX = x + 2 + i * (barWidth + spacing)
    
    # Draw bar using Unicode block elements
    for j in 0..<barHeight:
      let yPos = y + height - 2 - j
      # Use full block for bars
      let barChar = "█".repeat(barWidth)
      buffer.printRGB(startX, yPos, barChar, point.color)
    
    # Draw label below the bar
    let labelX = startX + (barWidth div 2) - (point.label.len div 2)
    buffer.print(labelX, y + height, point.label, labelStyle)

# Line chart with Unicode line drawing characters
proc drawLineChart(buffer: var Buffer, x, y, width, height: int, 
                  data: seq[DataPoint], title: string) =
  # Draw title
  let titleStyle = Style(fg: ColorCyan, bg: ColorDefault, attrs: {AttrBold})
  buffer.print(x + (width div 2) - (title.len div 2), y, title, titleStyle)
  
  # Find minimum and maximum value for scaling
  var minValue = float.high
  var maxValue = float.low
  for point in data:
    minValue = min(minValue, point.value)
    maxValue = max(maxValue, point.value)
  
  # Add a small buffer to min/max for better visualization
  let valueRange = maxValue - minValue
  minValue = max(0.0, minValue - valueRange * 0.05)
  maxValue = maxValue + valueRange * 0.05
  
  # Draw axis
  let axisStyle = Style(fg: ColorWhite, bg: ColorDefault)
  
  # Y-axis
  for i in 0..height-3:
    buffer.print(x, y + 2 + i, "│", axisStyle)
  
  # X-axis
  buffer.print(x, y + height - 1, "└" & "─".repeat(width - 2), axisStyle)
  
  # Draw Y-axis labels
  let labelStyle = Style(fg: ColorYellow, bg: ColorDefault)
  for i in 0..4:
    let labelValue = minValue + (maxValue - minValue) * (4 - i) / 4
    let label = fmt"{labelValue:>7.1f}"
    buffer.print(x - 8, y + 2 + i * (height - 3) div 4, label, labelStyle)
  
  # Calculate x-positions for data points
  let xStep = if data.len > 1: (width - 4).float / (data.len - 1).float else: 0.0
  var pointsX: seq[int] = @[]
  var pointsY: seq[int] = @[]
  
  for i, point in data:
    let xPos = x + 2 + int(i.float * xStep)
    let yPos = y + height - 2 - int((point.value - minValue) / (maxValue - minValue) * (height - 3).float)
    pointsX.add(xPos)
    pointsY.add(yPos)
    
    # Draw point
    buffer.printRGB(xPos, yPos, "●", point.color)
    
    # Draw x-axis label (only for some points to avoid clutter)
    if data.len <= 10 or i mod max(1, data.len div 10) == 0:
      let labelPos = xPos - (point.label.len div 2)
      if labelPos >= x + 2 and labelPos + point.label.len <= x + width - 2:
        buffer.print(labelPos, y + height, point.label, labelStyle)
  
  # Draw lines between points
  for i in 0..<pointsX.len-1:
    # Use Bresenham's line algorithm to draw line
    let x0 = pointsX[i]
    let y0 = pointsY[i]
    let x1 = pointsX[i+1]
    let y1 = pointsY[i+1]
    
    let steep = abs(y1 - y0) > abs(x1 - x0)
    
    var lx0 = x0
    var ly0 = y0
    var lx1 = x1
    var ly1 = y1
    
    if steep:
      swap(lx0, ly0)
      swap(lx1, ly1)
    
    if lx0 > lx1:
      swap(lx0, lx1)
      swap(ly0, ly1)
    
    let dx = lx1 - lx0
    let dy = abs(ly1 - ly0)
    var error = dx div 2
    
    var y = ly0
    let ystep = if ly0 < ly1: 1 else: -1
    
    # Create a gradient between the two point colors
    let startColor = data[i].color
    let endColor = data[i+1].color
    
    for x in lx0..lx1:
      let progress = if dx > 0: (x - lx0).float / dx.float else: 0.0
      let lineColor = gradientColor(progress, 0.0, 1.0, startColor, endColor)
      
      if steep:
        # Choose the right line character based on slope
        let lineChar = if abs(x1 - x0) > abs(y1 - y0): "━" else: "┃"
        buffer.printRGB(y, x, lineChar, lineColor)
      else:
        let lineChar = if abs(x1 - x0) > abs(y1 - y0): "━" else: "┃"
        buffer.printRGB(x, y, lineChar, lineColor)
      
      error -= dy
      if error < 0:
        y += ystep
        error += dx

# Pie chart using Unicode block elements
proc drawPieChart(buffer: var Buffer, x, y, width, height: int, 
                 data: seq[DataPoint], title: string) =
  # Draw title
  let titleStyle = Style(fg: ColorCyan, bg: ColorDefault, attrs: {AttrBold})
  buffer.print(x + (width div 2) - (title.len div 2), y, title, titleStyle)
  
  # Find total value for calculating percentages
  var total = 0.0
  for point in data:
    total += point.value
  
  if total <= 0:
    buffer.print(x + 2, y + height div 2, "No data", Style(fg: ColorRed))
    return
  
  # Calculate center and radius of pie
  let centerX = x + width div 2
  let centerY = y + (height - 2) div 2 + 2
  let radius = min(width, height - 4) div 3
  
  # Unicode circle characters for drawing the pie
  let circleChars = "█▓▒░ "
  
  # Draw pie using "pixel" approach with block characters
  for py in 0..<height-2:
    for px in 0..<width:
      # Calculate distance from center
      let dx = (px + x - centerX).float
      let dy = (py + y + 2 - centerY).float
      let distance = sqrt(dx*dx + dy*dy)
      
      if distance <= radius.float:
        # Calculate angle
        var angle = arctan2(dy, dx)
        if angle < 0:
          angle += 2 * PI
        
        # Determine which segment this pixel belongs to
        var currentAngle = 0.0
        var segmentIndex = -1
        
        for i, point in data:
          let segmentAngle = (point.value / total) * (2 * PI)
          if angle >= currentAngle and angle < currentAngle + segmentAngle:
            segmentIndex = i
            break
          currentAngle += segmentAngle
        
        if segmentIndex >= 0:
          let distanceRatio = distance / radius.float
          let charIndex = min(4, int(distanceRatio * 5))
          let c = if charIndex < circleChars.len: circleChars[charIndex] else: ' '
          
          buffer.printRGB(px + x, py + y + 2, $c, data[segmentIndex].color)
  
  # Draw legend
  let legendX = x + width - 20
  let legendStyle = Style(fg: ColorWhite, bg: ColorDefault)
  
  buffer.print(legendX, y + 2, "Legend:", legendStyle)
  
  for i, point in data:
    let percentage = (point.value / total) * 100
    let legendText = fmt"{point.label}: {percentage:.1f}%"
    buffer.printRGB(legendX, y + 4 + i, "■ " & legendText, point.color)

# Stacked bar chart
proc drawStackedBarChart(buffer: var Buffer, x, y, width, height: int, 
                        data: seq[DataPoint], title: string) =
  # Draw title
  let titleStyle = Style(fg: ColorCyan, bg: ColorDefault, attrs: {AttrBold})
  buffer.print(x + (width div 2) - (title.len div 2), y, title, titleStyle)
  
  # Group data by category
  var categories = initTable[string, seq[DataPoint]]()
  for point in data:
    if not categories.hasKey(point.category):
      categories[point.category] = @[]
    categories[point.category].add(point)
  
  # Calculate totals for each category
  var categoryTotals = initTable[string, float]()
  var maxTotal = 0.0
  
  for category, points in categories:
    var total = 0.0
    for point in points:
      total += point.value
    categoryTotals[category] = total
    maxTotal = max(maxTotal, total)
  
  # Calculate bar width and spacing
  let categoryNames = toSeq(categories.keys)
  let maxBarWidth = (width - 10) div categoryNames.len
  let barWidth = min(maxBarWidth, 8)
  let spacing = if categoryNames.len > 1: 
                (width - 10 - barWidth * categoryNames.len) div (categoryNames.len - 1) 
                else: 0
  
  # Draw axis
  let axisStyle = Style(fg: ColorWhite, bg: ColorDefault)
  
  # Y-axis
  for i in 0..height-3:
    buffer.print(x, y + 2 + i, "│", axisStyle)
  
  # X-axis
  buffer.print(x, y + height - 1, "└" & "─".repeat(width - 2), axisStyle)
  
  # Draw Y-axis labels
  let labelStyle = Style(fg: ColorYellow, bg: ColorDefault)
  for i in 0..4:
    let labelValue = maxTotal * (4 - i) / 4
    let label = fmt"{labelValue:>7.1f}"
    buffer.print(x - 8, y + 2 + i * (height - 3) div 4, label, labelStyle)
  
  # Draw bars for each category
  for i, category in categoryNames:
    let points = categories[category]
    let barStartX = x + 2 + i * (barWidth + spacing)
    
    # Sort points by value for better stacking visual
    var sortedPoints = points
    sortedPoints.sort(proc (a, b: DataPoint): int = cmp(b.value, a.value))
    
    # Stack segments within each bar
    var currentHeight = 0
    for point in sortedPoints:
      let segmentHeight = int((point.value / maxTotal) * (height - 3).float)
      let startY = y + height - 2 - currentHeight - segmentHeight
      
      # Draw segment using Unicode block elements
      for j in 0..<segmentHeight:
        let segmentChar = "█".repeat(barWidth)
        buffer.printRGB(barStartX, startY + j, segmentChar, point.color)
      
      currentHeight += segmentHeight
    
    # Draw category label below the bar
    let labelX = barStartX + (barWidth div 2) - (category.len div 2)
    buffer.print(labelX, y + height, category, labelStyle)
  
  # Draw legend
  let legendX = x + width - 20
  let legendStyle = Style(fg: ColorWhite, bg: ColorDefault)
  
  buffer.print(legendX, y + 2, "Legend:", legendStyle)
  
  # Get unique data points for legend (by label)
  var uniquePoints: seq[DataPoint] = @[]
  var seenLabels: seq[string] = @[]
  
  for point in data:
    if point.label notin seenLabels:
      uniquePoints.add(point)
      seenLabels.add(point.label)
  
  for i, point in uniquePoints:
    buffer.printRGB(legendX, y + 4 + i, "■ " & point.label, point.color)

# Heat map
proc drawHeatMap(buffer: var Buffer, x, y, width, height: int, 
                data: HeatMapData, title: string) =
  # Draw title
  let titleStyle = Style(fg: ColorCyan, bg: ColorDefault, attrs: {AttrBold})
  buffer.print(x + (width div 2) - (title.len div 2), y, title, titleStyle)
  
  # Calculate cell dimensions
  let rows = data.values.len
  let cols = if rows > 0: data.values[0].len else: 0
  
  if rows == 0 or cols == 0:
    buffer.print(x + 2, y + height div 2, "No data", Style(fg: ColorRed))
    return
  
  # Reserve space for row labels
  let rowLabelWidth = 10
  let cellWidth = min(4, (width - rowLabelWidth) div cols)
  let cellHeight = 1
  
  # Calculate available space for the heat map
  let availableHeight = height - 4  # Title + column labels + buffer
  let maxRows = availableHeight div cellHeight
  
  # Define color gradient
  let lowColor = RGBColor(r: 0, g: 0, b: 255)    # Blue for low values
  let midColor = RGBColor(r: 255, g: 255, b: 255) # White for mid values
  let highColor = RGBColor(r: 255, g: 0, b: 0)    # Red for high values
  
  # Draw column labels
  for j in 0..<min(cols, (width - rowLabelWidth) div cellWidth):
    let colLabel = if j < data.colLabels.len: data.colLabels[j] else: $j
    let labelLen = min(cellWidth, colLabel.len)
    let labelStr = colLabel[0..<labelLen]
    buffer.print(x + rowLabelWidth + j * cellWidth, y + 2, labelStr, 
                 Style(fg: ColorYellow, attrs: {AttrBold}))
  
  # Draw heat map cells
  for i in 0..<min(rows, maxRows):
    # Draw row label
    let rowLabel = if i < data.rowLabels.len: data.rowLabels[i] else: $i
    buffer.print(x, y + 3 + i * cellHeight, rowLabel, Style(fg: ColorYellow, attrs: {AttrBold}))
    
    for j in 0..<min(cols, (width - rowLabelWidth) div cellWidth):
      if j < data.values[i].len:
        let value = data.values[i][j]
        
        # Create color gradient
        let color = if value < (data.minValue + data.maxValue) / 2:
                      gradientColor(value, data.minValue, (data.minValue + data.maxValue) / 2, 
                                   lowColor, midColor)
                    else:
                      gradientColor(value, (data.minValue + data.maxValue) / 2, data.maxValue, 
                                   midColor, highColor)
        
        # Draw the cell
        let cellStr = "█".repeat(cellWidth)
        buffer.printRGB(x + rowLabelWidth + j * cellWidth, y + 3 + i * cellHeight, 
                       cellStr, color)
  
  # Draw color scale
  buffer.print(x, y + height - 1, "Scale:", Style(fg: ColorWhite))
  
  let scaleWidth = min(width - 20, 30)
  for i in 0..<scaleWidth:
    let ratio = i.float / (scaleWidth - 1).float
    let value = data.minValue + ratio * (data.maxValue - data.minValue)
    
    # Create color gradient for scale
    let color = if ratio < 0.5:
                  gradientColor(ratio, 0.0, 0.5, lowColor, midColor)
                else:
                  gradientColor(ratio, 0.5, 1.0, midColor, highColor)
    
    buffer.printRGB(x + 10 + i, y + height - 1, "█", color)
  
  # Scale labels
  buffer.print(x + 10, y + height, fmt"{data.minValue:.1f}", Style(fg: ColorWhite))
  buffer.print(x + 10 + scaleWidth - fmt"{data.maxValue:.1f}".len, y + height, 
               fmt"{data.maxValue:.1f}", Style(fg: ColorWhite))

# Generate sample data
proc generateSampleData(n: int): seq[DataPoint] =
  result = @[]
  let colors = [
    RGBColor(r: 255, g: 99, b: 71),   # Tomato
    RGBColor(r: 30, g: 144, b: 255),  # DodgerBlue
    RGBColor(r: 60, g: 179, b: 113),  # MediumSeaGreen
    RGBColor(r: 255, g: 165, b: 0),   # Orange
    RGBColor(r: 106, g: 90, b: 205),  # SlateBlue
    RGBColor(r: 255, g: 215, b: 0),   # Gold
    RGBColor(r: 178, g: 34, b: 34),   # FireBrick
    RGBColor(r: 75, g: 0, b: 130)     # Indigo
  ]
  
  let categories = ["Group A", "Group B", "Group C"]
  
  for i in 0..<n:
    let value = rand(10.0..100.0)
    let label = $('A'.int + i)
    let color = colors[i mod colors.len]
    let category = categories[i mod categories.len]
    
    result.add(DataPoint(label: label, value: value, color: color, category: category))

proc generateTimeseriesData(n: int): seq[DataPoint] =
  result = @[]
  let baseValue = rand(50.0..150.0)
  var currentValue = baseValue
  
  # Generate a somewhat realistic time series
  for i in 0..<n:
    # Add some random walk
    currentValue += rand(-10.0..10.0)
    currentValue = max(10.0, currentValue)
    
    # Add some seasonality
    let seasonal = sin(float(i) / (n/3) * 2 * PI) * 15.0
    
    let finalValue = currentValue + seasonal
    let label = if i mod 5 == 0: "Day " & $(i+1) else: ""
    
    # Gradient of colors from blue to red
    let ratio = i.float / max(1, n-1).float
    let color = RGBColor(
      r: uint8(30 + ratio * 225),
      g: uint8(100),
      b: uint8(200 - ratio * 170)
    )
    
    result.add(DataPoint(label: label, value: finalValue, color: color, category: "Time"))

proc generateHeatMapData(rows, cols: int): HeatMapData =
  var data = HeatMapData()
  
  # Generate values with some patterns
  data.values = newSeq[seq[float]](rows)
  for i in 0..<rows:
    data.values[i] = newSeq[float](cols)
    for j in 0..<cols:
      # Create a pattern (distance from center + noise)
      let centerRow = rows div 2
      let centerCol = cols div 2
      let distFromCenter = sqrt(pow(float(i - centerRow), 2) + pow(float(j - centerCol), 2))
      let maxDist = sqrt(pow(float(rows), 2) + pow(float(cols), 2)) / 2
      
      data.values[i][j] = 100.0 * (1.0 - distFromCenter / maxDist) + rand(-20.0..20.0)
  
  # Create labels
  data.rowLabels = newSeq[string](rows)
  for i in 0..<rows:
    data.rowLabels[i] = fmt"Row {i+1}"
  
  data.colLabels = newSeq[string](cols)
  for j in 0..<cols:
    data.colLabels[j] = fmt"Col {j+1}"
  
  # Calculate min and max values
  data.minValue = float.high
  data.maxValue = float.low
  
  for row in data.values:
    for value in row:
      data.minValue = min(data.minValue, value)
      data.maxValue = max(data.maxValue, value)
  
  return data

proc main() =
  randomize()
  
  withTerminal:
    # Get terminal size
    let (width, height) = raw.getTerminalSize()
    
    # Create buffer
    var buffer = newBuffer(width, height)
    
    # Clear screen
    clearScreen()
    
    # Title
    let titleStyle = Style(
      fg: ColorMagenta,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    buffer.print(2, 1, "Unicode Charts and Data Visualization Demo", titleStyle)
    buffer.print(2, 2, "Use arrow keys to navigate, Q to quit", Style(fg: ColorYellow))
    
    # Generate sample data
    let barData = generateSampleData(8)
    let lineData = generateTimeseriesData(20)
    let pieData = generateSampleData(5)
    let stackedData = generateSampleData(15)
    let heatMapData = generateHeatMapData(10, 15)
    
    # Track current chart
    var currentChart = BarChart
    var running = true
    
    while running:
      # Clear buffer
      buffer.clear()
      
      # Redraw title
      buffer.print(2, 1, "Unicode Charts and Data Visualization Demo", titleStyle)
      buffer.print(2, 2, "Use arrow keys to navigate, Q to quit", Style(fg: ColorYellow))
      
      # Draw the current chart
      case currentChart
      of BarChart:
        buffer.print(2, 4, "1. Bar Chart (←→)", Style(fg: ColorGreen, attrs: {AttrBold}))
        drawBarChart(buffer, 5, 6, width - 10, height - 10, barData, "Sample Bar Chart")
      
      of LineChart:
        buffer.print(2, 4, "2. Line Chart (←→)", Style(fg: ColorGreen, attrs: {AttrBold}))
        drawLineChart(buffer, 5, 6, width - 10, height - 10, lineData, "Time Series Line Chart")
      
      of PieChart:
        buffer.print(2, 4, "3. Pie Chart (←→)", Style(fg: ColorGreen, attrs: {AttrBold}))
        drawPieChart(buffer, 5, 6, width - 10, height - 10, pieData, "Category Distribution Pie Chart")
      
      of StackedBarChart:
        buffer.print(2, 4, "4. Stacked Bar Chart (←→)", Style(fg: ColorGreen, attrs: {AttrBold}))
        drawStackedBarChart(buffer, 5, 6, width - 10, height - 10, stackedData, "Stacked Bar Chart by Category")
      
      of HeatMap:
        buffer.print(2, 4, "5. Heat Map (←→)", Style(fg: ColorGreen, attrs: {AttrBold}))
        drawHeatMap(buffer, 5, 6, width - 10, height - 10, heatMapData, "Heat Map Visualization")
      
      # Draw buffer
      drawBuffer(buffer)
      
      # Process input
      let event = input.pollEvent()
      if event.kind == KeyPress:
        case event.key
        of KeyLeft:
          let chartOrd = ord(currentChart)
          currentChart = if chartOrd > 0: ChartType(chartOrd - 1) else: ChartType(high(ChartType).ord)
        of KeyRight:
          let chartOrd = ord(currentChart)
          currentChart = if chartOrd < high(ChartType).ord: ChartType(chartOrd + 1) else: ChartType(0)
        of KeyQ:
          running = false
        else:
          discard

when isMainModule:
  main()