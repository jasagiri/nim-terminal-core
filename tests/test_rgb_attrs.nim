import src/libterminal/output
import src/libterminal/private/common
import src/libterminal/private/color_utils

var buffer = newBuffer(80, 24)
let redColor = RGBColor(r: 255, g: 0, b: 0)
let blueColor = RGBColor(r: 0, g: 0, b: 255)

buffer.printRGB(5, 10, "Test", redColor, blueColor, {AttrBoldAttr})

# Check the style of the first character
echo "Cell at (5,10):"
echo "  style.attrs: ", buffer[5, 10].style.attrs
echo "  AttrBoldAttr in attrs: ", AttrBoldAttr in buffer[5, 10].style.attrs
