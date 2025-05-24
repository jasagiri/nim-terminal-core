# color_example.nim
## 拡張色サポートのデモンストレーション
## 
## このサンプルでは、様々な色表現を示します。
## 基本色、256色、RGB色（対応端末のみ）を表示します。

import libterminal
import std/strformat

proc main() =
  # 初期化
  withTerminal:
    # 初期サイズを取得
    let (width, height) = raw.getTerminalSize()
    
    # バッファを作成
    var buffer = newBuffer(width, height)
    
    # 画面をクリア
    clearScreen()
    
    # 色モードを検出
    let colorMode = detectColorSupport()
    
    # 基本情報表示
    let titleStyle = Style(
      fg: ColorMagenta,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    buffer.print(2, 1, "端末色サポートデモンストレーション", titleStyle)
    
    # 検出された色モード
    let modeStr = case colorMode
      of ColorBasic: "基本色モード (8色)"
      of ColorBright: "明るい色モード (16色)"
      of Color256: "256色モード"
      of ColorRGB: "RGB色モード (トゥルーカラー)"
    
    let infoStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {}
    )
    buffer.print(2, 3, "検出された色モード: " & modeStr, infoStyle)
    
    # 基本色表示
    buffer.print(2, 5, "基本16色:", titleStyle)
    
    var x = 2
    for i in 0..15:
      # 背景色を設定
      let style = Style(
        fg: if i < 8: ColorWhite else: ColorBlack,
        bg: Color(i),
        attrs: {}
      )
      
      # 色番号を表示
      buffer.print(x, 6, fmt" {i:2} ", style)
      x += 5
      
      # 改行
      if i == 7:
        x = 2
    
    # 256色パレットの一部を表示（対応端末のみ）
    if colorMode in {Color256, ColorRGB}:
      buffer.print(2, 8, "256色パレット (16-55):", titleStyle)
      
      x = 2
      var y = 9
      for i in 16..55:
        # 背景色を設定（256色インデックスを使用）
        let style = Style(
          fg: ColorBlack,
          bg: ColorBlack,  # あとで最適な色に変換される
          attrs: {}
        )
        
        # 色番号を表示
        buffer.print(x, y, fmt" {i:3} ", style)
        x += 5
        
        # 改行
        if (i - 16) mod 8 == 7:
          x = 2
          y += 1
        
        # ページ制限
        if i >= 55:
          break
    
    # RGB色の例（対応端末のみ）
    if colorMode == ColorRGB:
      buffer.print(2, 15, "RGB色の例:", titleStyle)
      
      # 赤色のグラデーション
      buffer.print(2, 16, "赤のグラデーション:")
      x = 2
      for r in countup(0, 255, 32):
        let rgb = RGBColor(r: uint8(r), g: 0, b: 0)
        buffer.printRGB(x, 17, fmt" {r:3} ", rgb, RGBColor(r:0, g:0, b:0), {AttrBold})
        x += 5
      
      # 緑色のグラデーション
      buffer.print(2, 18, "緑のグラデーション:")
      x = 2
      for g in countup(0, 255, 32):
        let rgb = RGBColor(r: 0, g: uint8(g), b: 0)
        buffer.printRGB(x, 19, fmt" {g:3} ", rgb, RGBColor(r:0, g:0, b:0), {AttrBold})
        x += 5
      
      # 青色のグラデーション
      buffer.print(2, 20, "青のグラデーション:")
      x = 2
      for b in countup(0, 255, 32):
        let rgb = RGBColor(r: 0, g: 0, b: uint8(b))
        buffer.printRGB(x, 21, fmt" {b:3} ", rgb, RGBColor(r:0, g:0, b:0), {AttrBold})
        x += 5
      
      # グレースケール
      buffer.print(2, 22, "グレースケール:")
      x = 2
      for g in countup(0, 255, 32):
        let rgb = RGBColor(r: uint8(g), g: uint8(g), b: uint8(g))
        buffer.printRGB(x, 23, fmt" {g:3} ", rgb, RGBColor(r:0, g:0, b:0), {AttrBold})
        x += 5
    
    # 色名の例
    buffer.print(2, if colorMode == ColorRGB: 25 else: 15, "色名の例:", titleStyle)
    let colorNames = [
      Red, Green, Blue, Yellow, Magenta, Cyan,
      DarkRed, DarkGreen, DarkBlue, Coral, Aquamarine, Gold, 
      Pink, Orchid, SkyBlue, Tomato
    ]
    
    x = 2
    y = if colorMode == ColorRGB: 26 else: 16
    for i, name in colorNames:
      # 色名で設定
      buffer.printColorName(x, y, fmt" {name} ", name, Black, {AttrBold})
      x += name.len + 3
      
      # 改行
      if i mod 4 == 3:
        x = 2
        y += 1
    
    # 効率的な描画でバッファを表示
    drawBuffer(buffer)
    
    # 何かキーが押されるまで待機
    buffer.print(2, y + 2, "何かキーを押すと終了します...", titleStyle)
    drawBuffer(buffer)
    
    discard input.pollEvent()

when isMainModule:
  main()