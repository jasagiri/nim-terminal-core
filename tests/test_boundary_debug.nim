import src/libterminal/private/unicode_utils

let text = "Hello"
echo "Testing word boundaries for '", text, "'"
for i in 0..text.len:
  let result = isWordBoundary(text, i)
  echo "Index ", i, ": ", result
