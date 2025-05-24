import unicode
import src/libterminal/private/unicode_utils

let text = "こんにちは世界"
echo "Text: ", text

# Show character positions
var charIndex = 0
for rune in text.runes:
  echo "Character ", charIndex, ": ", rune
  charIndex += 1

echo "\nTesting isWordBoundary:"
for i in 0..7:
  let result = isWordBoundary(text, i)
  echo "isWordBoundary(\"", text, "\", ", i, ") = ", result
