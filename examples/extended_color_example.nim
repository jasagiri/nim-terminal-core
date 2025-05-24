# extended_color_example.nim
# 拡張カラーサポート（RGB、256色）のデモ

import std/os
import std/strformat
import std/terminal
import std/math

import ../src/libterminal
import ../src/libterminal/output
import ../src/libterminal/private/color_utils

proc drawColorGradient(buffer: var Buffer, x, y, width, height: int, 
                      fromColor, toColor: RGBColor) =
  ## カラーグラデーションを描画
  for row in 0..<height:
    let t = row.float / max(height - 1, 1).float
    
    # 線形補間でRGB値を計算
    let r = uint8(fromColor.r.float * (1.0 - t) + toColor.r.float * t)
    let g = uint8(fromColor.g.float * (1.0 - t) + toColor.g.float * t)
    let b = uint8(fromColor.b.float * (1.0 - t) + toColor.b.float * t)
    
    # 現在の色を表示
    let color = RGBColor(r: r, g: g, b: b)
    let valueStr = fmt"RGB({r:3}, {g:3}, {b:3})"
    
    # グラデーションを描画
    for col in 0..<width:
      if col < valueStr.len:
        # テキスト部分
        if col == 0:
          # 各行の最初の文字のみRGBを設定（効率化のため）
          buffer.printRGB(x + col, y + row, valueStr[col..^1], color, 
                         RGBColor(r: 0, g: 0, b: 0))
        break
      else:
        # グラデーション部分
        buffer.printRGB(x + col, y + row, "█", color, 
                       RGBColor(r: 0, g: 0, b: 0))

proc draw256ColorPalette(buffer: var Buffer, x, y: int) =
  ## 256色パレットを表示
  
  let title = "256色パレット"
  let headerStyle = Style(fg: ColorWhite, bg: ColorBlack, attrs: {AttrBoldAttr})
  buffer.print(x + (36 - title.len) div 2, y, title, headerStyle)
  
  # 標準16色
  buffer.print(x, y + 1, "基本16色:", headerStyle)
  for i in 0..15:
    let color = RGBColor(r: 0, g: 0, b: 0)  # ダミー（256色インデックスが重要）
    let extColor = ExtendedColorInfo(
      mode: Color256,
      idx256Fg: i,
      idx256Bg: 0
    )
    
    let cell = Cell(
      ch: ' '.Rune,
      style: Style(fg: ColorBlack, bg: ColorBlack, attrs: {}),
      width: 1,
      extColor: some(extColor)
    )
    
    # 正方形を描画
    buffer[x + i*2, y + 2] = cell
    buffer[x + i*2 + 1, y + 2] = cell
    
    # インデックス表示
    let idxStr = fmt"{i:2}"
    buffer.print(x + i*2, y + 3, idxStr)
  
  # 6x6x6カラーキューブ
  buffer.print(x, y + 5, "6x6x6カラーキューブ (インデックス 16-231):", headerStyle)
  
  var row = 0
  var col = 0
  
  for i in 16..231:
    # 256色パレットからインデックスを使用
    let extColor = ExtendedColorInfo(
      mode: Color256,
      idx256Fg: 0,  # 前景色は黒固定
      idx256Bg: i   # 背景色を変化
    )
    
    let cell = Cell(
      ch: ' '.Rune,
      style: Style(fg: ColorBlack, bg: ColorBlack, attrs: {}),
      width: 1,
      extColor: some(extColor)
    )
    
    # 正方形を描画（インデックス付き）
    buffer[x + col*3, y + 7 + row] = cell
    buffer[x + col*3 + 1, y + 7 + row] = cell
    buffer[x + col*3 + 2, y + 7 + row] = cell
    
    # インデックスは小さめに表示
    if i mod 6 == 0:
      let idxStr = fmt"{i}"
      buffer.print(x + col*3, y + 8 + row, idxStr[0..0])
      if idxStr.len > 1:
        buffer.print(x + col*3 + 1, y + 8 + row, idxStr[1..^1])
    
    # 次の位置へ
    col += 1
    if col >= 6*6:  # 1行に36色
      col = 0
      row += 3  # 各色に3行使用（色表示+インデックス+空白）
  
  # グレースケール
  buffer.print(x, y + 7 + row + 2, "24段階グレースケール (インデックス 232-255):", headerStyle)
  
  for i in 0..23:
    let idx = 232 + i
    
    # 256色パレットからインデックスを使用
    let extColor = ExtendedColorInfo(
      mode: Color256,
      idx256Fg: 0,    # 前景色は黒固定
      idx256Bg: idx   # 背景色はグレースケール
    )
    
    let cell = Cell(
      ch: ' '.Rune,
      style: Style(fg: ColorBlack, bg: ColorBlack, attrs: {}),
      width: 1,
      extColor: some(extColor)
    )
    
    # 正方形を描画
    buffer[x + i*2, y + 7 + row + 4] = cell
    buffer[x + i*2 + 1, y + 7 + row + 4] = cell
    
    # インデックス表示
    if i mod 4 == 0:
      let idxStr = fmt"{idx}"
      buffer.print(x + i*2, y + 7 + row + 5, idxStr)

proc drawRainbow(buffer: var Buffer, x, y, width: int) =
  ## 虹色のグラデーションを描画
  
  let rainbowColors = [
    RGBColor(r: 255, g: 0, b: 0),     # 赤
    RGBColor(r: 255, g: 127, b: 0),   # オレンジ
    RGBColor(r: 255, g: 255, b: 0),   # 黄色
    RGBColor(r: 0, g: 255, b: 0),     # 緑
    RGBColor(r: 0, g: 0, b: 255),     # 青
    RGBColor(r: 75, g: 0, b: 130),    # インディゴ
    RGBColor(r: 148, g: 0, b: 211)    # 紫
  ]
  
  let title = "RGB カラーグラデーション"
  let headerStyle = Style(fg: ColorWhite, bg: ColorBlack, attrs: {AttrBoldAttr})
  buffer.print(x + (width - title.len) div 2, y, title, headerStyle)
  
  # 水平グラデーション
  for i in 0..<width:
    let t = i.float / max(width - 1, 1).float * 6.0
    let section = int(t)
    let sectionT = t - section.float
    
    let fromColor = rainbowColors[min(section, 6)]
    let toColor = rainbowColors[min(section + 1, 6)]
    
    # 線形補間でRGB値を計算
    let r = uint8(fromColor.r.float * (1.0 - sectionT) + toColor.r.float * sectionT)
    let g = uint8(fromColor.g.float * (1.0 - sectionT) + toColor.g.float * sectionT)
    let b = uint8(fromColor.b.float * (1.0 - sectionT) + toColor.b.float * sectionT)
    
    let color = RGBColor(r: r, g: g, b: b)
    buffer.printRGB(x + i, y + 2, "█", color)

proc main() =
  # 初期化
  var term = newTerminal()
  term.init()
  hideCursor()
  
  # バッファ作成
  let (width, height) = terminalSize()
  var buffer = newBuffer(width, height)
  
  # タイトル
  let titleStyle = Style(fg: ColorWhite, bg: ColorBlack, attrs: {AttrBoldAttr})
  let title = "拡張カラーサポートデモ"
  buffer.print(width div 2 - title.len div 2, 1, title, titleStyle)
  
  # 色モード情報
  let modeStr = case currentColorMode
    of ColorBasic: "基本色モード (8色)"
    of ColorBright: "明るい色モード (16色)"
    of Color256: "256色モード"
    of ColorRGB: "RGB/True Colorモード"
  
  buffer.print(width div 2 - modeStr.len div 2, 2, modeStr, titleStyle)
  
  # 説明文
  let infoStyle = Style(fg: ColorDefault, bg: ColorDefault, attrs: {})
  buffer.print(2, 4, "このターミナルでサポートされるカラーモード: " & modeStr, infoStyle)
  buffer.print(2, 5, "※色の表示はターミナルのカラー設定とハードウェアによって異なる場合があります", infoStyle)
  buffer.print(2, 6, "Qキーで終了", infoStyle)
  
  # RGB色のグラデーションサンプル
  drawRainbow(buffer, 5, 8, width - 10)
  
  # グラデーションサンプル1
  let red = RGBColor(r: 255, g: 0, b: 0)
  let blue = RGBColor(r: 0, g: 0, b: 255)
  drawColorGradient(buffer, 5, 11, 40, 10, red, blue)
  
  # グラデーションサンプル2
  let green = RGBColor(r: 0, g: 255, b: 0)
  let purple = RGBColor(r: 128, g: 0, b: 128)
  drawColorGradient(buffer, width - 45, 11, 40, 10, green, purple)
  
  # 256色パレット
  draw256ColorPalette(buffer, 5, 24)
  
  # 描画
  buffer.drawBuffer()
  
  # メインループ
  var running = true
  while running:
    if kbhit():
      let key = getch()
      if key == 'q' or key == 'Q':
        running = false
    
    sleep(100)
  
  # 終了処理
  showCursor()
  term.shutdown()

# メイン実行
main()