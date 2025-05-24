import src/libterminal/output
import src/libterminal/private/common
import src/libterminal/private/color_utils
import unicode

var buffer = newBuffer(80, 24)
let redColor = RGBColor(r: 255, g: 0, b: 0)
let greenColor = RGBColor(r: 0, g: 255, b: 0)

echo "Text to print: 'é👍'"
echo "String length: ", "é👍".len
echo "Rune count: ", "é👍".toRunes.len

buffer.printRGBAdvanced(5, 10, "é👍", redColor, greenColor)

for i in 5..9:
  echo "\nCell at (", i, ",10):"
  echo "  ch: '", $buffer[i, 10].ch, "'"
  echo "  width: ", buffer[i, 10].width
