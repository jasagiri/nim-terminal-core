# unicode_tables_example.nim
## Unicode Table and Layout Demo
## 
## This example demonstrates handling Unicode in structured layouts like tables,
## properly maintaining alignment despite varying character widths.

import libterminal
import std/unicode
import std/strutils
import std/tables
import std/algorithm

type
  TableAlignment = enum
    AlignLeft, AlignCenter, AlignRight
  
  TableColumn = object
    title: string
    width: int
    align: TableAlignment

proc alignText(text: string, width: int, align: TableAlignment): string =
  # Calculate the visual width of the text
  let textWidth = displayWidth(text)
  
  # If text is wider than the column, truncate it
  if textWidth > width:
    var result = ""
    var currentWidth = 0
    # Add characters until we would exceed the width
    let clusters = unicode_utils.splitIntoGraphemeClusters(text)
    for cluster in clusters:
      let clusterWidth = cluster.width
      if currentWidth + clusterWidth <= width - 1:
        # Add all codepoints in this cluster
        for r in cluster.codePoints:
          result.add(toUTF8(r))
        currentWidth += clusterWidth
      else:
        break
    
    # Add ellipsis for truncated text
    result.add("…")
    return result
  
  # Calculate padding based on alignment
  let padding = width - textWidth
  case align
  of AlignLeft:
    return text & " ".repeat(padding)
  of AlignRight:
    return " ".repeat(padding) & text
  of AlignCenter:
    let leftPad = padding div 2
    let rightPad = padding - leftPad
    return " ".repeat(leftPad) & text & " ".repeat(rightPad)

proc drawTable(buffer: var Buffer, startX, startY: int, 
               columns: seq[TableColumn],
               rows: seq[seq[string]],
               style: Style = Style()) =
  # Calculate total width including borders
  var totalWidth = columns.len + 1  # Vertical borders
  for col in columns:
    totalWidth += col.width
  
  # Draw top border
  var borderLine = "┌"
  for i, col in columns:
    borderLine.add("─".repeat(col.width))
    borderLine.add(if i < columns.high: "┬" else: "┐")
  buffer.printAdvanced(startX, startY, borderLine, style)
  
  # Draw header row
  var headerLine = "│"
  for i, col in columns:
    headerLine.add(alignText(col.title, col.width, col.align))
    headerLine.add("│")
  buffer.printAdvanced(startX, startY + 1, headerLine, style)
  
  # Draw header separator
  var separatorLine = "├"
  for i, col in columns:
    separatorLine.add("─".repeat(col.width))
    separatorLine.add(if i < columns.high: "┼" else: "┤")
  buffer.printAdvanced(startX, startY + 2, separatorLine, style)
  
  # Draw data rows
  for rowIdx, row in rows:
    var dataLine = "│"
    for colIdx, col in columns:
      let cellText = if colIdx < row.len: row[colIdx] else: ""
      dataLine.add(alignText(cellText, col.width, col.align))
      dataLine.add("│")
    buffer.printAdvanced(startX, startY + 3 + rowIdx, dataLine, style)
  
  # Draw bottom border
  var footerLine = "└"
  for i, col in columns:
    footerLine.add("─".repeat(col.width))
    footerLine.add(if i < columns.high: "┴" else: "┘")
  buffer.printAdvanced(startX, startY + 3 + rows.len, footerLine, style)

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
    buffer.print(2, 1, "Unicode Table and Layout Demo", titleStyle)
    
    # Description
    buffer.print(2, 3, "This example demonstrates correct handling of Unicode in tables with proper alignment.")
    
    # Section 1: Simple Unicode Table
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    buffer.print(2, 5, "1. Unicode Language Comparison Table", sectionStyle)
    
    # Define table structure
    let languageColumns = @[
      TableColumn(title: "Language", width: 12, align: AlignLeft),
      TableColumn(title: "Hello World", width: 25, align: AlignLeft),
      TableColumn(title: "Script", width: 20, align: AlignLeft)
    ]
    
    # Define table data
    let languageData = @[
      @["English", "Hello World", "Latin"],
      @["Japanese", "こんにちは世界", "CJK (Hiragana/Kanji)"],
      @["Korean", "안녕하세요 세계", "Hangul"],
      @["Arabic", "مرحبا بالعالم", "Arabic (RTL)"],
      @["Russian", "Привет мир", "Cyrillic"],
      @["Greek", "Γειά σου Κόσμε", "Greek"],
      @["Hindi", "नमस्ते दुनिया", "Devanagari"],
      @["Hebrew", "שלום עולם", "Hebrew (RTL)"],
      @["Thai", "สวัสดีชาวโลก", "Thai"],
      @["Chinese", "你好世界", "CJK (Han)"]
    ]
    
    # Draw the table
    drawTable(buffer, 4, 7, languageColumns, languageData)
    
    # Section 2: Emoji Attributes Table
    buffer.print(2, 22, "2. Emoji Attributes Table", sectionStyle)
    
    # Define emoji table structure
    let emojiColumns = @[
      TableColumn(title: "Emoji", width: 6, align: AlignCenter),
      TableColumn(title: "Description", width: 25, align: AlignLeft),
      TableColumn(title: "Width", width: 10, align: AlignCenter),
      TableColumn(title: "Sequence", width: 20, align: AlignLeft)
    ]
    
    # Define emoji data
    let emojiData = @[
      @["👍", "Thumbs Up", $displayWidth("👍"), "Basic Emoji"],
      @["👍🏽", "Thumbs Up (Medium Skin)", $displayWidth("👍🏽"), "Emoji + Modifier"],
      @["👩‍👩‍👧‍👦", "Family", $displayWidth("👩‍👩‍👧‍👦"), "ZWJ Sequence"],
      @["🏳️‍🌈", "Rainbow Flag", $displayWidth("🏳️‍🌈"), "Flag + ZWJ"],
      @["👨‍💻", "Man Technologist", $displayWidth("👨‍💻"), "Person + ZWJ + Object"],
      @["😊", "Smiling Face", $displayWidth("😊"), "Basic Emoji"],
      @["🇯🇵", "Flag: Japan", $displayWidth("🇯🇵"), "Regional Indicators"]
    ]
    
    # Draw the emoji table
    drawTable(buffer, 4, 24, emojiColumns, emojiData)
    
    # Section 3: Unicode Control Characters
    buffer.print(2, 37, "3. Unicode Width Statistics", sectionStyle)
    
    # Define stats table columns
    let statsColumns = @[
      TableColumn(title: "Category", width: 18, align: AlignLeft),
      TableColumn(title: "Example", width: 20, align: AlignLeft),
      TableColumn(title: "Width", width: 12, align: AlignCenter),
      TableColumn(title: "Properties", width: 25, align: AlignLeft)
    ]
    
    # Define categories and examples
    let statsData = @[
      @["Latin Lowercase", "abcdefgh", $displayWidth("abcdefgh"), "1 width per character"],
      @["Latin Uppercase", "ABCDEFGH", $displayWidth("ABCDEFGH"), "1 width per character"],
      @["Latin Accented", "áéíóúñ", $displayWidth("áéíóúñ"), "1 width per character"],
      @["Fullwidth Latin", "ＡＢＣＤ", $displayWidth("ＡＢＣＤ"), "2 width per character"],
      @["Halfwidth Katakana", "ﾊﾜｲ", $displayWidth("ﾊﾜｲ"), "1 width per character"],
      @["Japanese Hiragana", "ひらがな", $displayWidth("ひらがな"), "2 width per character"],
      @["CJK Ideographs", "漢字", $displayWidth("漢字"), "2 width per character"],
      @["Combining Marks", "e\u0301 a\u0300", $displayWidth("e\u0301 a\u0300"), "Base + zero width"],
      @["Emoji", "🌍🚀✨", $displayWidth("🌍🚀✨"), "2 width per emoji"]
    ]
    
    # Draw the stats table
    drawTable(buffer, 4, 39, statsColumns, statsData)
    
    # Section 4: Complex Layout with Mixed Scripts
    buffer.print(2, 53, "4. Complex Layout Grid", sectionStyle)
    
    # Create a grid of unicode characters from different scripts
    let gridStyle = Style(
      fg: ColorDefault,
      bg: ColorDefault,
      attrs: {}
    )
    
    # Define a mix of scripts for the grid
    let scripts = @[
      @["A", "B", "C", "D", "E"],
      @["あ", "い", "う", "え", "お"],
      @["漢", "字", "한", "글", "조"],
      @["α", "β", "γ", "δ", "ε"],
      @["א", "ב", "ג", "ד", "ה"]
    ]
    
    # Draw a box around the grid
    buffer.printAdvanced(4, 55, "┌───┬───┬───┬───┬───┐", gridStyle)
    
    # Draw the grid rows
    for i in 0..<scripts.len:
      var rowStr = "│"
      for j in 0..<scripts[i].len:
        let char = scripts[i][j]
        # Center align each character
        rowStr.add(alignText(char, 3, AlignCenter))
        rowStr.add("│")
      buffer.printAdvanced(4, 56 + i, rowStr, gridStyle)
      
      # Add row separator (except after the last row)
      if i < scripts.len - 1:
        buffer.printAdvanced(4, 56 + i + 1, "├───┼───┼───┼───┼───┤", gridStyle)
    
    # Draw the bottom border
    buffer.printAdvanced(4, 56 + scripts.len, "└───┴───┴───┴───┴───┘", gridStyle)
    
    # Footer
    buffer.print(2, 64, "Press any key to exit...", Style(fg: ColorGreen))
    
    # Draw buffer
    drawBuffer(buffer)
    
    # Wait for keypress before exiting
    discard input.pollEvent()

when isMainModule:
  main()