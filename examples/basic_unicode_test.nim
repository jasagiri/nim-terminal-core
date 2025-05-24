import std/unicode
import std/strutils

# Import the libterminal's unicode_utils module directly without terminal handling
import ../src/libterminal/private/unicode_utils

proc main() =
  let text1 = "ASCII: Hello, World!"
  let text2 = "CJK: 你好，世界！"
  let text3 = "Arabic: مرحبا بالعالم!"
  let text4 = "Emoji: 👨‍👩‍👧‍👦 👍 🎉"
  let text5 = "Combined: é ñ ö ç"
  
  echo "Text Direction Tests:"
  echo "---------------------"
  echo text1, " -> Direction: ", getTextDirection(text1)
  echo text2, " -> Direction: ", getTextDirection(text2)
  echo text3, " -> Direction: ", getTextDirection(text3)
  echo text4, " -> Direction: ", getTextDirection(text4)
  echo text5, " -> Direction: ", getTextDirection(text5)
  echo ""
  
  echo "Grapheme Cluster Tests:"
  echo "----------------------"
  echo text1, " -> Graphemes: ", graphemeLength(text1), ", Runes: ", text1.runeLen
  echo text2, " -> Graphemes: ", graphemeLength(text2), ", Runes: ", text2.runeLen
  echo text3, " -> Graphemes: ", graphemeLength(text3), ", Runes: ", text3.runeLen
  echo text4, " -> Graphemes: ", graphemeLength(text4), ", Runes: ", text4.runeLen
  echo text5, " -> Graphemes: ", graphemeLength(text5), ", Runes: ", text5.runeLen
  echo ""
  
  echo "Display Width Tests:"
  echo "-------------------"
  echo text1, " -> Width: ", displayWidth(text1)
  echo text2, " -> Width: ", displayWidth(text2)
  echo text3, " -> Width: ", displayWidth(text3)
  echo text4, " -> Width: ", displayWidth(text4)
  echo text5, " -> Width: ", displayWidth(text5)
  echo ""
  
  echo "Text Wrapping Tests:"
  echo "-------------------"
  let longText = "This is a longer paragraph of text that will be wrapped " &
                "based on different wrapping modes. This demonstrates how " &
                "Unicode-aware line wrapping works with different wrapping " &
                "policies. This includes handling of 全角文字 (wide characters), " &
                "grapheme clusters like 👨‍👩‍👧‍👦 (emoji with ZWJ), combining characters " &
                "like é (e + ◌́), and 서로 다른 스크립트 (mixed scripts)."
  
  echo "Original text (", longText.len, " bytes):"
  echo longText
  echo ""
  
  echo "Wrapped text (WrapWord, width=40):"
  let wrappedLines = splitLines(longText, 40, WrapWord)
  for i, line in wrappedLines:
    echo i+1, ": ", line, " (", displayWidth(line), ")"
  echo ""
  
  echo "Wrapped text (WrapCharacter, width=40):"
  let charWrappedLines = splitLines(longText, 40, WrapCharacter)
  for i, line in charWrappedLines:
    echo i+1, ": ", line, " (", displayWidth(line), ")"
  echo ""
  
  echo "Visual/Logical Position Tests:"
  echo "-----------------------------"
  let testText = "ASCII and 你好 and مرحبا and 👨‍👩‍👧‍👦"
  echo "Text: ", testText
  
  # Test logical to visual positions
  echo "Logical to Visual positions:"
  for i in 0..min(20, testText.len):
    let visual = logicalPosToVisual(testText, i)
    echo "  Position ", i, " -> Visual: ", visual
  
  # Test visual to logical positions
  echo "Visual to Logical positions:"
  let maxWidth = displayWidth(testText)
  for i in 0..min(20, maxWidth):
    let logical = visualPosToLogical(testText, i)
    echo "  Visual ", i, " -> Logical: ", logical

when isMainModule:
  main()