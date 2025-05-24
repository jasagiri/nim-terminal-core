# simple_color_example.nim
#
# 拡張カラーサポート（RGB、256色）の簡易デモ

import std/os
import std/strformat
import std/terminal
import std/math

import ../src/libterminal/output
import ../src/libterminal/private/color_utils

proc main() =
  # ターミナルを初期化
  stdout.write(AttrReset)
  clearScreen()
  
  # 現在の端末のカラーモードを取得
  echo "現在の端末カラーモード: ", case currentColorMode
    of ColorBasic: "基本色モード (8色)"
    of ColorBright: "明るい色モード (16色)" 
    of Color256: "256色モード"
    of ColorRGB: "RGB/True Colorモード"
  
  echo "このデモは、端末の対応に合わせて色を自動調整します。"
  echo "Ctrl+Cで終了します。"
  echo ""
  
  # 基本色のデモ
  echo "基本色のデモ:"
  for i in 0..15:
    var style: Style
    
    if i < 8:
      # 基本8色
      style = Style(fg: ColorDefault, bg: Color(i), attrs: {})
    else:
      # 明るい色（一部の端末では未対応）
      style = Style(fg: ColorDefault, bg: Color(i-8), attrs: {AttrBoldAttr})
      
    stdout.setStyle(style)
    stdout.write("  ")
    stdout.write(AttrReset)
    stdout.write(" ")
  
  stdout.write("\n\n")
  
  # RGB色のデモ
  echo "RGBカラーグラデーション:"
  
  # 赤～青のグラデーション
  for i in 0..<50:
    let t = i.float / 49.0
    let r = uint8(255.0 * (1.0 - t))
    let b = uint8(255.0 * t)
    
    let color = RGBColor(r: r, g: 0, b: b)
    
    # RGB色を設定
    case currentColorMode
    of ColorRGB:
      setRgbForeground(color.r, color.g, color.b)
    of Color256:
      set256Foreground(to256Index(color))
    else:
      let basicColor = closestBasicColor(color)
      let colorStr = fmt"\e[{30 + ord(basicColor)}m"
      stdout.write(colorStr)
    
    stdout.write("█")
  
  stdout.write(AttrReset)
  stdout.write("\n\n")
  
  # 256色パレットの一部表示（16-32の範囲）
  if currentColorMode in {Color256, ColorRGB}:
    echo "256色パレットのサンプル (インデックス 16-32):"
    
    for i in 16..32:
      # 背景色を設定
      set256Background(i)
      stdout.write("  ")
      stdout.write(AttrReset)
      stdout.write(fmt" {i} ")
    
    stdout.write(AttrReset)
    stdout.write("\n\n")
  
  # X11名前付き色のサンプル
  echo "X11名前付き色のサンプル:"
  
  let namedColors = [
    DeepSkyBlue, Tomato, LimeGreen, Gold, 
    DarkViolet, Chocolate, DodgerBlue, Firebrick
  ]
  
  for color in namedColors:
    let rgb = x11ColorMap[color]
    
    # 色を設定
    case currentColorMode
    of ColorRGB:
      setRgbBackground(rgb.r, rgb.g, rgb.b)
    of Color256:
      set256Background(to256Index(rgb))
    else:
      let basicColor = closestBasicColor(rgb)
      let colorStr = fmt"\e[{40 + ord(basicColor)}m"
      stdout.write(colorStr)
    
    stdout.write(fmt" {color} ")
    stdout.write(AttrReset)
    stdout.write(" ")
  
  # 終了
  stdout.write(AttrReset)
  stdout.write("\n\nデモ終了\n")

# メインプログラム実行
main()