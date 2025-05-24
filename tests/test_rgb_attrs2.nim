import src/libterminal/output
import src/libterminal/private/common
import src/libterminal/private/color_utils

var buffer = newBuffer(80, 24)
let redColor = RGBColor(r: 255, g: 0, b: 0)
let blueColor = RGBColor(r: 0, g: 0, b: 255)

buffer.printRGB(5, 10, "Colored", redColor, blueColor, {AttrBoldAttr})

# Check each character
for i in 5..(5+7):
  echo "Cell at (", i, ",10):"
  echo "  style.attrs: ", buffer[i, 10].style.attrs
  echo "  AttrBoldAttr in attrs: ", AttrBoldAttr in buffer[i, 10].style.attrs
