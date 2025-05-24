import src/libterminal/private/unicode_utils

# Test case from test_unicode_utils.nim
let text1 = "こんにちは世界"
let result1 = isWordBoundary(text1, 5)
echo "isWordBoundary(\"", text1, "\", 5) = ", result1
echo "Expected: true"

# Let's check what happens at different indices
echo "\nChecking all indices:"
for i in 0..text1.len:
  let isBoundary = isWordBoundary(text1, i)
  if isBoundary:
    echo "Index ", i, " is a word boundary"

# Test empty string
echo "\nEmpty string test:"
echo "isWordBoundary(\"\", 0) = ", isWordBoundary("", 0)
echo "Expected: false"
