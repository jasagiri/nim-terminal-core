# mouse_example.nim
## マウス入力のデモンストレーション
## 
## このサンプルでは、マウスイベントの処理と表示を行います。
## マウスクリック、ドラッグ、ホイールスクロールなどの操作を試せます。

import libterminal
import std/strformat

proc drawBox(buffer: var Buffer, x, y, width, height: int) =
  # 外枠を描画
  let style = Style(fg: ColorWhite, bg: ColorBlue, attrs: {})
  
  # 上下の横線
  for i in 0..<width:
    buffer[x + i, y] = Cell(ch: '─', style: style)
    buffer[x + i, y + height - 1] = Cell(ch: '─', style: style)
  
  # 左右の縦線
  for i in 0..<height:
    buffer[x, y + i] = Cell(ch: '│', style: style)
    buffer[x + width - 1, y + i] = Cell(ch: '│', style: style)
  
  # 四隅
  buffer[x, y] = Cell(ch: '┌', style: style)
  buffer[x + width - 1, y] = Cell(ch: '┐', style: style)
  buffer[x, y + height - 1] = Cell(ch: '└', style: style)
  buffer[x + width - 1, y + height - 1] = Cell(ch: '┘', style: style)

proc main() =
  # マウスサポート付きでターミナルを初期化
  withMouseTerminal:
    # 初期サイズを取得
    let (width, height) = raw.getTerminalSize()
    
    # バッファを作成
    var buffer = newBuffer(width, height)
    
    # 画面をクリア
    clearScreen()
    
    # マウスイベントログ
    var eventLog: seq[string] = @[]
    let maxLogEntries = 10
    
    # 描画対象になる領域を作成
    let boxX = 5
    let boxY = 3
    let boxWidth = width - 10
    let boxHeight = height - 10
    
    # マウスの現在位置
    var mouseX = 0
    var mouseY = 0
    var mouseButton = "None"
    var mouseAction = "None"
    
    # 初期描画
    buffer.clear()
    drawBox(buffer, boxX, boxY, boxWidth, boxHeight)
    buffer.print(2, 1, "マウス入力テスト - 'q'キーで終了")
    buffer.print(boxX + 2, boxY + 1, "この領域内でマウスを操作してください")
    
    var running = true
    while running:
      # 情報表示
      buffer.print(boxX + 2, boxY + 3, fmt"位置: X={mouseX:3} Y={mouseY:3}   ")
      buffer.print(boxX + 2, boxY + 4, fmt"ボタン: {mouseButton:10}   ")
      buffer.print(boxX + 2, boxY + 5, fmt"アクション: {mouseAction:10}   ")
      
      # ログ表示
      buffer.print(boxX + 2, boxY + 7, "イベントログ:")
      for i, logEntry in eventLog:
        buffer.print(boxX + 2, boxY + 8 + i, "                                       ")
        buffer.print(boxX + 2, boxY + 8 + i, logEntry)
      
      # ヘルプ表示
      buffer.print(boxX + 2, boxHeight - 2, "マウスボタン、ドラッグ、ホイールスクロールを試してください")
      
      # バッファを表示
      drawBuffer(buffer)
      
      # マウスポインタがある場所を強調表示
      if mouseX >= boxX and mouseX < boxX + boxWidth and 
         mouseY >= boxY and mouseY < boxY + boxHeight:
        # マウス位置に点を描画
        let highlightStyle = Style(fg: ColorBlack, bg: ColorYellow, attrs: {})
        buffer[mouseX, mouseY] = Cell(ch: ' ', style: highlightStyle)
      
      # イベントを待機
      let event = input.pollEvent(100)
      
      # イベント処理
      case event.kind
      of EvKey:
        if event.key.key == KeyNone and event.key.ch == 'q':
          running = false
      of EvMouse:
        # マウス位置を更新
        mouseX = event.mouse.x
        mouseY = event.mouse.y
        
        # ボタン情報
        case event.mouse.button
        of MouseLeft: mouseButton = "左ボタン"
        of MouseRight: mouseButton = "右ボタン"
        of MouseMiddle: mouseButton = "中ボタン"
        of MouseWheelUp: mouseButton = "ホイール上"
        of MouseWheelDown: mouseButton = "ホイール下"
        of MouseNone: mouseButton = "なし"
        
        # アクション情報
        case event.mouse.action
        of MousePressed: mouseAction = "押下"
        of MouseReleased: mouseAction = "解放"
        of MouseDragged: mouseAction = "ドラッグ"
        of MouseMoved: mouseAction = "移動"
        
        # ログに追加
        let logEntry = fmt"[{mouseAction}] {mouseButton} @ ({mouseX},{mouseY})"
        eventLog.add(logEntry)
        if eventLog.len > maxLogEntries:
          eventLog.delete(0)
      of EvResize:
        # リサイズ処理
        buffer = newBuffer(event.resize.width, event.resize.height)
        buffer.clear()
        drawBox(buffer, boxX, boxY, min(boxWidth, event.resize.width - 10), 
                min(boxHeight, event.resize.height - 10))
      else:
        discard  # 他のイベントは無視

when isMainModule:
  main()