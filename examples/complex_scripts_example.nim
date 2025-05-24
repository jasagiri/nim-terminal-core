# complex_scripts_example.nim
## Complex Scripts and Bidirectional Text Demo
## 
## This example demonstrates handling of complex scripts including
## right-to-left languages, CJK characters, and Indic scripts.

import libterminal
import std/unicode
import std/strutils

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
    buffer.print(2, 1, "Complex Scripts and Bidirectional Text Demo", titleStyle)
    
    # Section headers style
    let sectionStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    
    # Section 1: Right-to-Left Languages
    buffer.print(2, 3, "1. Right-to-Left Text", sectionStyle)
    
    # Arabic
    buffer.print(4, 5, "Arabic:")
    buffer.printAdvanced(6, 6, "مرحبا بالعالم - Hello World", Style())
    buffer.printAdvanced(6, 7, "هذا مثال للنص العربي مع بعض الكلمات الإنجليزية English words in Arabic text", Style())
    
    # Hebrew
    buffer.print(4, 9, "Hebrew:")
    buffer.printAdvanced(6, 10, "שלום עולם - Hello World", Style())
    buffer.printAdvanced(6, 11, "זוהי דוגמה לטקסט בעברית עם English words mixed in", Style())
    
    # Bidirectional mixed text
    buffer.print(4, 13, "Mixed Bidirectional:")
    buffer.printAdvanced(6, 14, "Latin, عربي, English, עברית, 日本語, Latin", Style())
    buffer.printAdvanced(6, 15, "Numbers in RTL: ١٢٣٤٥ and ١٢٣٤٥٦٧٨٩", Style())
    
    # Section 2: CJK (Chinese, Japanese, Korean)
    buffer.print(2, 17, "2. CJK Characters", sectionStyle)
    
    # Chinese
    buffer.print(4, 19, "Chinese (Simplified):")
    buffer.printAdvanced(6, 20, "你好世界 - Hello World", Style())
    buffer.printAdvanced(6, 21, "这是中文示例 This is a Chinese example 混合英文", Style())
    
    # Japanese
    buffer.print(4, 23, "Japanese:")
    buffer.printAdvanced(6, 24, "こんにちは世界 - Hello World", Style())
    buffer.printAdvanced(6, 25, "これは日本語の例です This is a Japanese example 英語と混合", Style())
    buffer.printAdvanced(6, 26, "平仮名, 片仮名, 漢字 and Latin mixed: あアア漢字カタカナ", Style())
    
    # Korean
    buffer.print(4, 28, "Korean:")
    buffer.printAdvanced(6, 29, "안녕하세요 세계 - Hello World", Style())
    buffer.printAdvanced(6, 30, "이것은 한국어 예제입니다 English words 영어 단어들", Style())
    
    # Section 3: Indic and South Asian Scripts
    buffer.print(2, 32, "3. Indic and South Asian Scripts", sectionStyle)
    
    # Devanagari (Hindi/Sanskrit)
    buffer.print(4, 34, "Devanagari (Hindi):")
    buffer.printAdvanced(6, 35, "नमस्ते दुनिया - Hello World", Style())
    buffer.printAdvanced(6, 36, "यह हिंदी में एक उदाहरण है with English words", Style())
    
    # Thai
    buffer.print(4, 38, "Thai:")
    buffer.printAdvanced(6, 39, "สวัสดีชาวโลก - Hello World", Style())
    buffer.printAdvanced(6, 40, "นี่คือตัวอย่างภาษาไทย with English words", Style())
    
    # Section 4: Width and Alignment Demonstration
    buffer.print(2, 42, "4. Width and Alignment", sectionStyle)
    
    # Create strings of same logical length but different display widths
    let alignEnglish = "Hello World"
    let alignJapanese = "こんにちは世界"
    let alignArabic = "مرحبا بالعالم"
    let alignHindi = "नमस्ते दुनिया"
    
    # Calculate display widths
    let widthEnglish = displayWidth(alignEnglish)
    let widthJapanese = displayWidth(alignJapanese)
    let widthArabic = displayWidth(alignArabic)
    let widthHindi = displayWidth(alignHindi)
    
    # Display width information
    buffer.print(4, 44, "English: \"" & alignEnglish & "\" - Width: " & $widthEnglish)
    buffer.print(4, 45, "Japanese: \"" & alignJapanese & "\" - Width: " & $widthJapanese)
    buffer.print(4, 46, "Arabic: \"" & alignArabic & "\" - Width: " & $widthArabic)
    buffer.print(4, 47, "Hindi: \"" & alignHindi & "\" - Width: " & $widthHindi)
    
    # Aligned text (using calculated widths for proper alignment)
    let maxWidth = max(max(widthEnglish, widthJapanese), max(widthArabic, widthHindi))
    
    buffer.print(4, 49, "Aligned Text:")
    
    # Format with spaces based on width difference
    proc alignRight(text: string, width: int, targetWidth: int): string =
      let spaces = " ".repeat(targetWidth - width)
      return spaces & text
    
    let englishAligned = alignRight(alignEnglish, widthEnglish, maxWidth)
    let japaneseAligned = alignRight(alignJapanese, widthJapanese, maxWidth)
    let arabicAligned = alignRight(alignArabic, widthArabic, maxWidth)
    let hindiAligned = alignRight(alignHindi, widthHindi, maxWidth)
    
    buffer.printAdvanced(6, 50, englishAligned & " |", Style())
    buffer.printAdvanced(6, 51, japaneseAligned & " |", Style())
    buffer.printAdvanced(6, 52, arabicAligned & " |", Style())
    buffer.printAdvanced(6, 53, hindiAligned & " |", Style())
    
    # Footer
    buffer.print(2, 55, "Press any key to exit...", Style(fg: ColorGreen))
    
    # Draw buffer
    drawBuffer(buffer)
    
    # Wait for keypress before exiting
    discard input.pollEvent()

when isMainModule:
  main()