import unicode
let text = "こんにちは世界"
echo "Text: ", text
echo "Length: ", text.len
for i, c in text:
  echo "Index ", i, ": ", c.ord, " (", c, ")"

echo "\nRune indices:"
var idx = 0
for rune in text.runes:
  echo "Rune at byte ", idx, ": ", rune
  idx += rune.size
