# test_color_utils.nim
## 色処理関数のテスト

import unittest
import ../src/libterminal
import ../src/libterminal/output
import ../src/libterminal/private/color_utils
import ../src/libterminal/private/common

# NOTE: These tests are commented out because the color API has changed
# The functions fgColorToEscape, bgColorToEscape, etc. are not implemented
# in the current version of the library. The color functionality is now
# handled through ColorStyle and setColorStyle functions.

# suite "基本的な色処理":
#   test "16色の基本色":
#     discard
# 
# suite "拡張色モード":
#   test "256色モード":
#     discard
# 
# suite "RGB色変換":
#   test "RGBから256色への変換":
#     discard

suite "色サポート検出":
  test "色モードの検出":
    # 色サポートの検出はターミナルに依存するため、
    # 関数が呼び出せることのみを確認
    let colorMode = detectColorSupport()
    check(colorMode in {ColorBasic, ColorBright, Color256, ColorRGB})
    
  test "RGBサポートの確認":
    # 結果はターミナルに依存するが、関数は動作するはず
    discard supportsRgbColor()
    discard supports256Color()