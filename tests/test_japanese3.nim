import unicode
let text = "こんにちは世界"

# Maybe the test is using grapheme/character index not byte index
var charIndex = 0
var byteIndex = 0
for rune in text.runes:
  if charIndex == 5:
    echo "Character index 5 is at byte index: ", byteIndex
    echo "This is between '", text.runeAt(charIndex-1), "' and '", rune, "'"
    break
  charIndex += 1
  byteIndex += rune.size
