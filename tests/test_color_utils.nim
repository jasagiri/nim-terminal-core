# test_color_utils.nim
## Color processing function tests

import unittest
import ../src/libterminal
import ../src/libterminal/output
import ../src/libterminal/private/color_utils
import ../src/libterminal/private/common

# NOTE: These tests are commented out because the color API has changed
# The functions fgColorToEscape, bgColorToEscape, etc. are not implemented
# in the current version of the library. The color functionality is now
# handled through ColorStyle and setColorStyle functions.

# suite "Basic color processing":
#   test "Basic 16 colors":
#     discard
# 
# suite "Extended color mode":
#   test "256 color mode":
#     discard
# 
# suite "RGB color conversion":
#   test "RGB to 256 color conversion":
#     discard

suite "Color support detection":
  test "Color mode detection":
    # Since color support detection depends on the terminal,
    # we only verify that the function can be called
    let colorMode = detectColorSupport()
    check(colorMode in {ColorBasic, ColorBright, Color256, ColorRGB})
    
  test "RGB support verification":
    # The result depends on the terminal, but the function should work
    discard supportsRgbColor()
    discard supports256Color()