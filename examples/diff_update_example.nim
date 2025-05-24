# diff_update_example.nim
## このサンプルは差分更新の効果を示します
##
## 同じバッファに少しずつ変更を加え、差分更新が効率的に動作することを示します

import std/os
import std/strformat
import std/terminal
import std/random
import std/times

import ../src/libterminal
import ../src/libterminal/output

proc drawBox(buffer: var Buffer, x, y, width, height: int, style: Style) =
  # 箱の枠を描画
  let horizontalLine = "─".repeat(width - 2)
  let emptyLine = " ".repeat(width - 2)
  
  # 上端
  buffer.print(x, y, fmt"┌{horizontalLine}┐", style)
  
  # 側面
  for i in 1..<height-1:
    buffer.print(x, y + i, "│", style)
    buffer.print(x + width - 1, y + i, "│", style)
    buffer.print(x + 1, y + i, emptyLine, style)
  
  # 下端
  buffer.print(x, y + height - 1, fmt"└{horizontalLine}┘", style)

proc updateRandomCells(buffer: var Buffer, x, y, width, height: int, count: int) =
  # ランダムなセルを指定数だけ更新
  for _ in 0..<count:
    let rx = x + 1 + rand(width - 3)
    let ry = y + 1 + rand(height - 3)
    
    # ランダムな色を選択
    let colors = [ColorRed, ColorGreen, ColorBlue, ColorYellow, ColorMagenta, ColorCyan]
    let randomColor = colors[rand(colors.len - 1)]
    
    # セルを更新
    let style = Style(fg: randomColor, bg: ColorDefault, attrs: {})
    let ch = "█".runeAt(0)
    buffer[rx, ry] = Cell(ch: ch, style: style, width: 1)

proc main() =
  # 端末の初期化
  var term = newTerminal()
  term.init()
  hideCursor()
  clearScreen()
  
  # バッファ作成
  let (width, height) = terminalSize()
  var buffer = newBuffer(width, height)
  
  # 画面を分割して2つの箱を描画
  let boxWidth = width div 2 - 4
  let boxHeight = height - 6
  
  let leftBoxX = 2
  let rightBoxX = width div 2 + 2
  let boxY = 3
  
  # 箱の初期描画
  let normalStyle = Style(fg: ColorWhite, bg: ColorDefault, attrs: {})
  drawBox(buffer, leftBoxX, boxY, boxWidth, boxHeight, normalStyle)
  drawBox(buffer, rightBoxX, boxY, boxWidth, boxHeight, normalStyle)
  
  # ヘッダーを描画
  let headerStyle = Style(fg: ColorWhite, bg: ColorDefault, attrs: {AttrBoldAttr})
  buffer.print(leftBoxX, 1, "標準描画 (従来方式)", headerStyle)
  buffer.print(rightBoxX, 1, "差分描画 (最適化)", headerStyle)
  
  # 説明文
  let infoStyle = Style(fg: ColorWhite, bg: ColorDefault, attrs: {})
  buffer.print(2, height - 2, "各ボックス内のセルがランダムに更新されます。右側は差分描画を使用。", infoStyle)
  buffer.print(2, height - 1, "Qキーで終了", infoStyle)
  
  # 初期描画
  buffer.drawBuffer()
  
  # メインループ
  var iteration = 0
  let updateCount = 10  # 各更新で変更するセル数
  var running = true
  
  while running and iteration < 1000:
    try:
      # カウンター表示
      iteration += 1
      let counterStyle = Style(fg: ColorYellow, bg: ColorDefault, attrs: {AttrBoldAttr})
      let iterStr = fmt"更新回数: {iteration}"
      buffer.print(width div 2 - iterStr.len div 2, boxY + boxHeight + 1, iterStr, counterStyle)
      
      # 標準描画（左側）：全体を描画する方式
      let startStandard = cpuTime()
      
      # 左側のボックスを更新
      updateRandomCells(buffer, leftBoxX, boxY, boxWidth, boxHeight, updateCount)
      
      # 左側のボックスを手動で描画（差分なし）
      hideCursor()
      stdout.write(AttrReset)
      for y in 0..<boxHeight:
        for x in 0..<boxWidth:
          let cell = buffer[leftBoxX + x, boxY + y]
          setCursor(leftBoxX + x, boxY + y)
          setStyle(cell.style)
          stdout.write($cell.ch)
      
      let endStandard = cpuTime()
      
      # 差分描画（右側）
      let startDiff = cpuTime()
      
      # 右側のボックスを更新
      updateRandomCells(buffer, rightBoxX, boxY, boxWidth, boxHeight, updateCount)
      
      # 差分描画機能を使用して描画
      buffer.drawBuffer()
      
      let endDiff = cpuTime()
      
      # パフォーマンス情報
      let standardTime = (endStandard - startStandard) * 1000
      let diffTime = (endDiff - startDiff) * 1000
      let perfStyle = Style(fg: ColorCyan, bg: ColorDefault, attrs: {})
      let standardTimeStr = fmt"標準描画: {standardTime:.2f}ms"
      let diffTimeStr = fmt"差分描画: {diffTime:.2f}ms"
      let gainStr = fmt"効率: {(standardTime / diffTime):.2f}倍"
      
      buffer.print(leftBoxX, boxY + boxHeight + 2, standardTimeStr, perfStyle)
      buffer.print(rightBoxX, boxY + boxHeight + 2, diffTimeStr, perfStyle)
      buffer.print(width div 2 - gainStr.len div 2, boxY + boxHeight + 3, gainStr, perfStyle)
      
      # 表示を更新
      buffer.drawBuffer()
      
      # 少し待機
      sleep(200)
      
      # Qキーで終了
      if kbhit():
        let key = getch()
        if key == 'q' or key == 'Q':
          running = false
    except:
      let e = getCurrentException()
      echo "エラー: ", e.msg
      break

  # 後処理
  showCursor()
  term.shutdown()

# メインプログラム実行
randomize()
main()