# color_utils.nim
## 色操作のためのユーティリティ
##
## このモジュールは色変換や計算のための関数を提供します

import std/math
import std/os
import std/strutils
import common

type
  ColorMode* = enum
    ## ターミナルがサポートする色モード
    ColorBasic,      ## 8色（標準ANSI色）
    ColorBright,     ## 16色（標準 + 明るい色）
    Color256,        ## 256色
    ColorRGB         ## RGB（24ビットカラー）

  RGBColor* = object
    ## RGB色を表現する型
    r*, g*, b*: uint8  ## 0-255の色成分

  ## X11の標準的な色名とRGB値のマッピング
  X11ColorName* = enum
    Black, Red, Green, Yellow, Blue, Magenta, Cyan, White,
    BrightBlack, BrightRed, BrightGreen, BrightYellow, 
    BrightBlue, BrightMagenta, BrightCyan, BrightWhite,
    
    # 以下はX11の標準色名
    AliceBlue, AntiqueWhite, Aqua, Aquamarine, Azure, Beige, Bisque, 
    BlanchedAlmond, BlueViolet, Brown, BurlyWood, CadetBlue, Chartreuse,
    Chocolate, Coral, CornflowerBlue, Cornsilk, Crimson, DarkBlue, DarkCyan,
    DarkGoldenrod, DarkGray, DarkGreen, DarkKhaki, DarkMagenta, DarkOliveGreen,
    DarkOrange, DarkOrchid, DarkRed, DarkSalmon, DarkSeaGreen, DarkSlateBlue,
    DarkSlateGray, DarkTurquoise, DarkViolet, DeepPink, DeepSkyBlue, DimGray,
    DodgerBlue, Firebrick, FloralWhite, ForestGreen, Fuchsia, Gainsboro,
    GhostWhite, Gold, Goldenrod, Gray, GreenYellow, Honeydew, HotPink,
    IndianRed, Indigo, Ivory, Khaki, Lavender, LavenderBlush, LawnGreen,
    LemonChiffon, LightBlue, LightCoral, LightCyan, LightGoldenrodYellow,
    LightGreen, LightGrey, LightPink, LightSalmon, LightSeaGreen, LightSkyBlue,
    LightSlateGray, LightSteelBlue, LightYellow, Lime, LimeGreen, Linen,
    Maroon, MediumAquamarine, MediumBlue, MediumOrchid, MediumPurple,
    MediumSeaGreen, MediumSlateBlue, MediumSpringGreen, MediumTurquoise,
    MediumVioletRed, MidnightBlue, MintCream, MistyRose, Moccasin, NavajoWhite,
    Navy, OldLace, Olive, OliveDrab, Orange, OrangeRed, Orchid, PaleGoldenrod,
    PaleGreen, PaleTurquoise, PaleVioletRed, PapayaWhip, PeachPuff, Peru,
    Pink, Plum, PowderBlue, Purple, RebeccaPurple, RosyBrown, RoyalBlue,
    SaddleBrown, Salmon, SandyBrown, SeaGreen, Seashell, Sienna, Silver,
    SkyBlue, SlateBlue, SlateGray, Snow, SpringGreen, SteelBlue, Tan, Teal,
    Thistle, Tomato, Turquoise, Violet, Wheat, WhiteSmoke, YellowGreen

# ANSI 16色の定義
const 
  BasicColorTable* = [
    # ANSI標準8色
    RGBColor(r: 0, g: 0, b: 0),          # Black
    RGBColor(r: 170, g: 0, b: 0),        # Red
    RGBColor(r: 0, g: 170, b: 0),        # Green
    RGBColor(r: 170, g: 85, b: 0),       # Yellow
    RGBColor(r: 0, g: 0, b: 170),        # Blue
    RGBColor(r: 170, g: 0, b: 170),      # Magenta
    RGBColor(r: 0, g: 170, b: 170),      # Cyan
    RGBColor(r: 170, g: 170, b: 170),    # White
    
    # 明るい色（8-15）
    RGBColor(r: 85, g: 85, b: 85),       # BrightBlack
    RGBColor(r: 255, g: 85, b: 85),      # BrightRed
    RGBColor(r: 85, g: 255, b: 85),      # BrightGreen
    RGBColor(r: 255, g: 255, b: 85),     # BrightYellow
    RGBColor(r: 85, g: 85, b: 255),      # BrightBlue
    RGBColor(r: 255, g: 85, b: 255),     # BrightMagenta
    RGBColor(r: 85, g: 255, b: 255),     # BrightCyan
    RGBColor(r: 255, g: 255, b: 255)     # BrightWhite
  ]

# X11の色定義（標準16色と一部の追加色）
const x11ColorMap*: array[X11ColorName, RGBColor] = [
  # 基本16色
  RGBColor(r: 0, g: 0, b: 0),                 # Black
  RGBColor(r: 170, g: 0, b: 0),               # Red
  RGBColor(r: 0, g: 170, b: 0),               # Green
  RGBColor(r: 170, g: 85, b: 0),              # Yellow
  RGBColor(r: 0, g: 0, b: 170),               # Blue
  RGBColor(r: 170, g: 0, b: 170),             # Magenta
  RGBColor(r: 0, g: 170, b: 170),             # Cyan
  RGBColor(r: 170, g: 170, b: 170),           # White
  RGBColor(r: 85, g: 85, b: 85),              # BrightBlack
  RGBColor(r: 255, g: 85, b: 85),             # BrightRed
  RGBColor(r: 85, g: 255, b: 85),             # BrightGreen
  RGBColor(r: 255, g: 255, b: 85),            # BrightYellow
  RGBColor(r: 85, g: 85, b: 255),             # BrightBlue
  RGBColor(r: 255, g: 85, b: 255),            # BrightMagenta
  RGBColor(r: 85, g: 255, b: 255),            # BrightCyan
  RGBColor(r: 255, g: 255, b: 255),           # BrightWhite
  
  # 以下、X11標準色
  RGBColor(r: 240, g: 248, b: 255),           # AliceBlue
  RGBColor(r: 250, g: 235, b: 215),           # AntiqueWhite
  RGBColor(r: 0, g: 255, b: 255),             # Aqua
  RGBColor(r: 127, g: 255, b: 212),           # Aquamarine
  RGBColor(r: 240, g: 255, b: 255),           # Azure
  RGBColor(r: 245, g: 245, b: 220),           # Beige
  RGBColor(r: 255, g: 228, b: 196),           # Bisque
  RGBColor(r: 255, g: 235, b: 205),           # BlanchedAlmond
  RGBColor(r: 138, g: 43, b: 226),            # BlueViolet
  RGBColor(r: 165, g: 42, b: 42),             # Brown
  RGBColor(r: 222, g: 184, b: 135),           # BurlyWood
  RGBColor(r: 95, g: 158, b: 160),            # CadetBlue
  RGBColor(r: 127, g: 255, b: 0),             # Chartreuse
  RGBColor(r: 210, g: 105, b: 30),            # Chocolate
  RGBColor(r: 255, g: 127, b: 80),            # Coral
  RGBColor(r: 100, g: 149, b: 237),           # CornflowerBlue
  RGBColor(r: 255, g: 248, b: 220),           # Cornsilk
  RGBColor(r: 220, g: 20, b: 60),             # Crimson
  RGBColor(r: 0, g: 0, b: 139),               # DarkBlue
  RGBColor(r: 0, g: 139, b: 139),             # DarkCyan
  RGBColor(r: 184, g: 134, b: 11),            # DarkGoldenrod
  RGBColor(r: 169, g: 169, b: 169),           # DarkGray
  RGBColor(r: 0, g: 100, b: 0),               # DarkGreen
  RGBColor(r: 189, g: 183, b: 107),           # DarkKhaki
  RGBColor(r: 139, g: 0, b: 139),             # DarkMagenta
  RGBColor(r: 85, g: 107, b: 47),             # DarkOliveGreen
  RGBColor(r: 255, g: 140, b: 0),             # DarkOrange
  RGBColor(r: 153, g: 50, b: 204),            # DarkOrchid
  RGBColor(r: 139, g: 0, b: 0),               # DarkRed
  RGBColor(r: 233, g: 150, b: 122),           # DarkSalmon
  RGBColor(r: 143, g: 188, b: 143),           # DarkSeaGreen
  RGBColor(r: 72, g: 61, b: 139),             # DarkSlateBlue
  RGBColor(r: 47, g: 79, b: 79),              # DarkSlateGray
  RGBColor(r: 0, g: 206, b: 209),             # DarkTurquoise
  RGBColor(r: 148, g: 0, b: 211),             # DarkViolet
  RGBColor(r: 255, g: 20, b: 147),            # DeepPink
  RGBColor(r: 0, g: 191, b: 255),             # DeepSkyBlue
  RGBColor(r: 105, g: 105, b: 105),           # DimGray
  RGBColor(r: 30, g: 144, b: 255),            # DodgerBlue
  RGBColor(r: 178, g: 34, b: 34),             # Firebrick
  RGBColor(r: 255, g: 250, b: 240),           # FloralWhite
  RGBColor(r: 34, g: 139, b: 34),             # ForestGreen
  RGBColor(r: 255, g: 0, b: 255),             # Fuchsia
  RGBColor(r: 220, g: 220, b: 220),           # Gainsboro
  RGBColor(r: 248, g: 248, b: 255),           # GhostWhite
  RGBColor(r: 255, g: 215, b: 0),             # Gold
  RGBColor(r: 218, g: 165, b: 32),            # Goldenrod
  RGBColor(r: 128, g: 128, b: 128),           # Gray
  RGBColor(r: 173, g: 255, b: 47),            # GreenYellow
  RGBColor(r: 240, g: 255, b: 240),           # Honeydew
  RGBColor(r: 255, g: 105, b: 180),           # HotPink
  RGBColor(r: 205, g: 92, b: 92),             # IndianRed
  RGBColor(r: 75, g: 0, b: 130),              # Indigo
  RGBColor(r: 255, g: 255, b: 240),           # Ivory
  RGBColor(r: 240, g: 230, b: 140),           # Khaki
  RGBColor(r: 230, g: 230, b: 250),           # Lavender
  RGBColor(r: 255, g: 240, b: 245),           # LavenderBlush
  RGBColor(r: 124, g: 252, b: 0),             # LawnGreen
  RGBColor(r: 255, g: 250, b: 205),           # LemonChiffon
  RGBColor(r: 173, g: 216, b: 230),           # LightBlue
  RGBColor(r: 240, g: 128, b: 128),           # LightCoral
  RGBColor(r: 224, g: 255, b: 255),           # LightCyan
  RGBColor(r: 250, g: 250, b: 210),           # LightGoldenrodYellow
  RGBColor(r: 144, g: 238, b: 144),           # LightGreen
  RGBColor(r: 211, g: 211, b: 211),           # LightGrey
  RGBColor(r: 255, g: 182, b: 193),           # LightPink
  RGBColor(r: 255, g: 160, b: 122),           # LightSalmon
  RGBColor(r: 32, g: 178, b: 170),            # LightSeaGreen
  RGBColor(r: 135, g: 206, b: 250),           # LightSkyBlue
  RGBColor(r: 119, g: 136, b: 153),           # LightSlateGray
  RGBColor(r: 176, g: 196, b: 222),           # LightSteelBlue
  RGBColor(r: 255, g: 255, b: 224),           # LightYellow
  RGBColor(r: 0, g: 255, b: 0),               # Lime
  RGBColor(r: 50, g: 205, b: 50),             # LimeGreen
  RGBColor(r: 250, g: 240, b: 230),           # Linen
  RGBColor(r: 128, g: 0, b: 0),               # Maroon
  RGBColor(r: 102, g: 205, b: 170),           # MediumAquamarine
  RGBColor(r: 0, g: 0, b: 205),               # MediumBlue
  RGBColor(r: 186, g: 85, b: 211),            # MediumOrchid
  RGBColor(r: 147, g: 112, b: 219),           # MediumPurple
  RGBColor(r: 60, g: 179, b: 113),            # MediumSeaGreen
  RGBColor(r: 123, g: 104, b: 238),           # MediumSlateBlue
  RGBColor(r: 0, g: 250, b: 154),             # MediumSpringGreen
  RGBColor(r: 72, g: 209, b: 204),            # MediumTurquoise
  RGBColor(r: 199, g: 21, b: 133),            # MediumVioletRed
  RGBColor(r: 25, g: 25, b: 112),             # MidnightBlue
  RGBColor(r: 245, g: 255, b: 250),           # MintCream
  RGBColor(r: 255, g: 228, b: 225),           # MistyRose
  RGBColor(r: 255, g: 228, b: 181),           # Moccasin
  RGBColor(r: 255, g: 222, b: 173),           # NavajoWhite
  RGBColor(r: 0, g: 0, b: 128),               # Navy
  RGBColor(r: 253, g: 245, b: 230),           # OldLace
  RGBColor(r: 128, g: 128, b: 0),             # Olive
  RGBColor(r: 107, g: 142, b: 35),            # OliveDrab
  RGBColor(r: 255, g: 165, b: 0),             # Orange
  RGBColor(r: 255, g: 69, b: 0),              # OrangeRed
  RGBColor(r: 218, g: 112, b: 214),           # Orchid
  RGBColor(r: 238, g: 232, b: 170),           # PaleGoldenrod
  RGBColor(r: 152, g: 251, b: 152),           # PaleGreen
  RGBColor(r: 175, g: 238, b: 238),           # PaleTurquoise
  RGBColor(r: 219, g: 112, b: 147),           # PaleVioletRed
  RGBColor(r: 255, g: 239, b: 213),           # PapayaWhip
  RGBColor(r: 255, g: 218, b: 185),           # PeachPuff
  RGBColor(r: 205, g: 133, b: 63),            # Peru
  RGBColor(r: 255, g: 192, b: 203),           # Pink
  RGBColor(r: 221, g: 160, b: 221),           # Plum
  RGBColor(r: 176, g: 224, b: 230),           # PowderBlue
  RGBColor(r: 128, g: 0, b: 128),             # Purple
  RGBColor(r: 102, g: 51, b: 153),            # RebeccaPurple
  RGBColor(r: 188, g: 143, b: 143),           # RosyBrown
  RGBColor(r: 65, g: 105, b: 225),            # RoyalBlue
  RGBColor(r: 139, g: 69, b: 19),             # SaddleBrown
  RGBColor(r: 250, g: 128, b: 114),           # Salmon
  RGBColor(r: 244, g: 164, b: 96),            # SandyBrown
  RGBColor(r: 46, g: 139, b: 87),             # SeaGreen
  RGBColor(r: 255, g: 245, b: 238),           # Seashell
  RGBColor(r: 160, g: 82, b: 45),             # Sienna
  RGBColor(r: 192, g: 192, b: 192),           # Silver
  RGBColor(r: 135, g: 206, b: 235),           # SkyBlue
  RGBColor(r: 106, g: 90, b: 205),            # SlateBlue
  RGBColor(r: 112, g: 128, b: 144),           # SlateGray
  RGBColor(r: 255, g: 250, b: 250),           # Snow
  RGBColor(r: 0, g: 255, b: 127),             # SpringGreen
  RGBColor(r: 70, g: 130, b: 180),            # SteelBlue
  RGBColor(r: 210, g: 180, b: 140),           # Tan
  RGBColor(r: 0, g: 128, b: 128),             # Teal
  RGBColor(r: 216, g: 191, b: 216),           # Thistle
  RGBColor(r: 255, g: 99, b: 71),             # Tomato
  RGBColor(r: 64, g: 224, b: 208),            # Turquoise
  RGBColor(r: 238, g: 130, b: 238),           # Violet
  RGBColor(r: 245, g: 222, b: 179),           # Wheat
  RGBColor(r: 245, g: 245, b: 245),           # WhiteSmoke
  RGBColor(r: 154, g: 205, b: 50)             # YellowGreen
]

# 256色テーブルの生成
var color256Table*: array[256, RGBColor]

# 256色パレットの初期化
proc initColor256Table*() =
  # 最初の16色はANSI標準色
  for i in 0..15:
    color256Table[i] = BasicColorTable[i]
  
  # 216色のRGBカラーキューブ (16-231)
  # 各成分は0, 36, 72, 108, 144, 180, 216 (6段階)のいずれか
  var index = 16
  for r in 0..5:
    for g in 0..5:
      for b in 0..5:
        color256Table[index] = RGBColor(
          r: uint8(if r > 0: r * 40 + 55 else: 0),
          g: uint8(if g > 0: g * 40 + 55 else: 0),
          b: uint8(if b > 0: b * 40 + 55 else: 0)
        )
        inc index
  
  # グレースケール (232-255)
  # 24段階のグレー
  for i in 0..23:
    let gray = uint8(i * 10 + 8)
    color256Table[i + 232] = RGBColor(r: gray, g: gray, b: gray)

# 色テーブルを初期化
initColor256Table()

# 色関連の変換関数

proc toRGB*(color: Color): RGBColor =
  ## 基本色からRGB値への変換
  let index = ord(color)
  if index < BasicColorTable.len:
    return BasicColorTable[index]
  return RGBColor(r: 255, g: 255, b: 255)  # デフォルトは白

proc to256Index*(rgb: RGBColor): int =
  ## RGB値から最も近い256色インデックスを返す
  
  # グレースケールの判定
  # 赤、緑、青の値が近い場合はグレースケール
  if abs(int(rgb.r) - int(rgb.g)) < 10 and abs(int(rgb.g) - int(rgb.b)) < 10:
    # グレースケール（232-255）の中から最適なものを探す
    if rgb.r < 8:
      return 16  # 最も暗い色（黒）
    if rgb.r > 238:
      return 231  # 最も明るい色（白）
    
    # 対応するグレースケールを計算
    return 232 + int(rgb.r - 8) div 10
  
  # RGBカラーキューブ内の最も近い色を探す
  # 各成分を0-5の範囲に変換
  let r = int(rgb.r) div 51
  let g = int(rgb.g) div 51
  let b = int(rgb.b) div 51
  
  # インデックスを計算
  return 16 + (r * 36) + (g * 6) + b

proc closestBasicColor*(rgb: RGBColor): Color =
  ## RGB値から最も近い基本色を返す
  var closestIndex = 0
  var minDistance = int.high
  
  for i, basicRgb in BasicColorTable:
    # 単純なユークリッド距離を使用
    let distance = (
      (int(rgb.r) - int(basicRgb.r))^2 +
      (int(rgb.g) - int(basicRgb.g))^2 +
      (int(rgb.b) - int(basicRgb.b))^2
    )
    
    if distance < minDistance:
      minDistance = distance
      closestIndex = i
  
  return Color(closestIndex)

proc detectColorSupport*(): ColorMode =
  ## ターミナルの色サポートレベルを検出
  # COLORTERM環境変数を確認
  let colorterm = getEnv("COLORTERM")
  if colorterm.contains("truecolor") or colorterm.contains("24bit"):
    return ColorRGB
  
  # TERM環境変数を確認
  let term = getEnv("TERM")
  if term.contains("256color"):
    return Color256
  elif term.contains("color"):
    return ColorBright
  
  # その他の場合はデフォルトで基本色のみと判断
  return ColorBasic

proc supportsRgbColor*(): bool =
  ## 端末がRGB色をサポートしているかを確認
  return detectColorSupport() == ColorRGB

proc supports256Color*(): bool =
  ## 端末が256色をサポートしているかを確認
  let mode = detectColorSupport()
  return mode == Color256 or mode == ColorRGB