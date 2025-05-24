import unicode
let text = "こんにちは世界"
echo "Text: ", text

# Count runes up to index 5
var runeCount = 0
for rune in text.runes:
  echo "Rune ", runeCount, ": ", rune
  runeCount += 1
  if runeCount >= 7:
    break

# The test might mean the 5th character position, which would be byte 15
echo "\nByte position of 5th rune boundary: 15"
echo "Character at that boundary: between 'は' and '世'"
