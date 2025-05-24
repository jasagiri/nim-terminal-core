import unicode
import src/libterminal/private/unicode_utils

# Test specific cases
echo "isWordBoundary(\"Hello\", 0) = ", isWordBoundary("Hello", 0)
echo "isWordBoundary(\"Hello\", 2) = ", isWordBoundary("Hello", 2)
echo "isWordBoundary(\"Hello\", 5) = ", isWordBoundary("Hello", 5)
echo "isWordBoundary(\"Hello World\", 5) = ", isWordBoundary("Hello World", 5)
echo "isWordBoundary(\"Hello World\", 6) = ", isWordBoundary("Hello World", 6)

# Show what the Japanese text looks like
let text = "こんにちは世界"
var i = 0
for rune in text.runes:
  echo "Rune ", i, ": ", rune
  i += 1
