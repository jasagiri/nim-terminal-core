import src/libterminal/output
import src/libterminal/private/common
import src/libterminal/private/color_utils

var buffer = newBuffer(80, 24)
let redColor = RGBColor(r: 255, g: 0, b: 0)
let greenColor = RGBColor(r: 0, g: 255, b: 0)

buffer.printRGBAdvanced(5, 10, "é👍", redColor, greenColor)

echo "Cell at (5,10) - é:"
echo "  width: ", buffer[5, 10].width

echo "\nCell at (6,10) - after é:"
echo "  width: ", buffer[6, 10].width

echo "\nCell at (7,10) - 👍 first cell:"
echo "  width: ", buffer[7, 10].width

echo "\nCell at (8,10) - 👍 second cell:"
echo "  width: ", buffer[8, 10].width
