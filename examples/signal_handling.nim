# signal_handling.nim
## シグナル処理機能のデモ
## 
## このサンプルでは、シグナル処理機能を検証します:
## - Ctrl+C (SIGINT) の捕捉と処理
## - ウィンドウリサイズ (SIGWINCH) の検出
## - 適切な終了処理

import std/os
import libterminal

proc main() =
  # 初期化
  var term = newTerminal()
  term.init()
  
  try:
    # 初期ターミナルサイズを取得
    var (width, height) = raw.getTerminalSize()
    
    # バッファを作成
    var buffer = newBuffer(width, height)
    
    # メッセージを表示
    clearScreen()
    buffer.print(0, 0, "シグナル処理のテスト")
    buffer.print(0, 2, "- Ctrl+C を押すとイベントが捕捉されます")
    buffer.print(0, 3, "- ターミナルのサイズを変更するとイベントが発生します")
    buffer.print(0, 4, "- q キーで終了します")
    
    var running = true
    var eventCounter = 0
    
    # イベント情報を表示する位置
    let eventX = 0
    let eventY = 6
    
    while running:
      # バッファを描画
      drawBuffer(buffer)
      
      # イベントを取得（最大100ミリ秒待機）
      let event = input.pollEvent(100)
      
      # リサイズ処理
      if event.kind == EvResize:
        width = event.resize.width
        height = event.resize.height
        buffer = newBuffer(width, height)
        
        # 基本メッセージを再描画
        buffer.print(0, 0, "シグナル処理のテスト")
        buffer.print(0, 2, "- Ctrl+C を押すとイベントが捕捉されます")
        buffer.print(0, 3, "- ターミナルのサイズを変更するとイベントが発生します")
        buffer.print(0, 4, "- q キーで終了します")
        
        # リサイズ情報を表示
        eventCounter += 1
        let infoMsg = "イベント #" & $eventCounter & ": リサイズ " & 
                    $width & "x" & $height
        buffer.print(eventX, eventY, "                                          ")
        buffer.print(eventX, eventY, infoMsg)
      
      # キー入力処理
      elif event.kind == EvKey:
        if event.key.key == KeyNone and event.key.ch == 'q':
          running = false
        elif event.key.key == KeyNone and 
             ModCtrl in event.key.modifiers and 
             event.key.ch == 'C':
          # Ctrl+C が捕捉された
          eventCounter += 1
          buffer.print(eventX, eventY, "                                          ")
          buffer.print(eventX, eventY, "イベント #" & $eventCounter & ": Ctrl+C が捕捉されました")
        else:
          # その他のキー入力
          eventCounter += 1
          var keyInfo = "イベント #" & $eventCounter & ": キー入力 "
          
          if event.key.key != KeyNone:
            # 特殊キー
            keyInfo.add($event.key.key)
          else:
            # 通常の文字
            keyInfo.add("'" & $event.key.ch & "'")
          
          # 修飾キーがあれば表示
          if event.key.modifiers.len > 0:
            keyInfo.add(" + 修飾キー: ")
            var first = true
            for mod in event.key.modifiers:
              if not first:
                keyInfo.add(", ")
              keyInfo.add($mod)
              first = false
          
          buffer.print(eventX, eventY, "                                          ")
          buffer.print(eventX, eventY, keyInfo)
      
      # シグナルイベントも処理（内部的にはキーイベントに変換されている）
      input.handleSignals()
    
  finally:
    # 終了処理（シグナルハンドラも適切に復元される）
    term.shutdown()

when isMainModule:
  main()