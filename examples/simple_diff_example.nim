# simple_diff_example.nim
## 差分更新の効果を示す簡単な例

import std/os
import std/strformat
import std/terminal
import std/random
import std/times

import ../src/libterminal/output

proc main() =
  # 端末の初期化
  stdout.write(AttrReset)
  stdout.write(CursorHide)
  stdout.write(EraseDisplay)
  stdout.flushFile()
  
  # バッファ作成
  let (width, height) = terminalSize()
  var buffer = newBuffer(width, height)
  
  # タイトル表示
  let titleStyle = Style(fg: ColorWhite, bg: ColorDefault, attrs: {})
  buffer.print(2, 1, "差分描画デモ - 同じ内容でも効率的に描画します", titleStyle)
  buffer.print(2, 2, "Ctrl+Cで終了", titleStyle)
  
  # 初期描画
  buffer.drawBuffer()
  
  # メインループ
  var iteration = 0
  
  while iteration < 100:
    # 更新カウンター
    iteration += 1
    let counterStyle = Style(fg: ColorYellow, bg: ColorDefault, attrs: {})
    let iterStr = fmt"更新回数: {iteration}"
    buffer.print(2, 4, iterStr, counterStyle)
    
    # ランダムな位置に文字を描画（少量の変更）
    for i in 0..<10:
      let x = rand(5..<width-5)
      let y = rand(6..<height-2)
      let colors = [ColorRed, ColorGreen, ColorBlue, ColorYellow, ColorMagenta, ColorCyan]
      let randomColor = colors[rand(colors.len - 1)]
      let style = Style(fg: randomColor, bg: ColorDefault, attrs: {})
      buffer.print(x, y, "*", style)
    
    # 経過時間表示
    let timeStr = fmt"現在時刻: {now()}"
    buffer.print(width - timeStr.len - 2, height - 2, timeStr, 
                Style(fg: ColorCyan, bg: ColorDefault, attrs: {}))
    
    # バッファを差分描画（変更箇所のみ更新）
    let startTime = cpuTime()
    buffer.drawBuffer()
    let endTime = cpuTime()
    
    # 描画時間表示
    let drawTime = (endTime - startTime) * 1000
    buffer.print(2, height - 2, fmt"描画時間: {drawTime:.2f}ms", 
                Style(fg: ColorGreen, bg: ColorDefault, attrs: {}))
    buffer.drawBuffer()
    
    # 少し待機
    sleep(100)
  
  # 後処理
  stdout.write(CursorShow)
  stdout.write(AttrReset)
  stdout.flushFile()

# 実行
randomize()
main()