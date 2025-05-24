# minimal_diff_example.nim
## 差分更新の最も基本的なデモ

import std/os
import std/strformat
import std/terminal
import std/times
import std/random
import std/posix
import std/termios

# キー入力関連関数
proc kbhit(): bool =
  # キー入力があるかチェック
  var fd: cint = STDIN_FILENO
  var readfds: TFdSet
  FD_ZERO(readfds)
  FD_SET(fd, readfds)
  var timeout: Timeval
  timeout.tv_sec = posix.Time(0)
  timeout.tv_usec = 0
  return select(fd+1, addr(readfds), nil, nil, addr(timeout)) > 0

proc getch(): char =
  # 1文字読み込み
  var c: char
  discard read(STDIN_FILENO, addr(c), 1)
  return c

# 直接使用する最低限のコード
type
  Cell = object
    ch: char
    fg, bg: int
    
  Buffer = object
    width, height: int
    cells: seq[Cell]
    lastCells: seq[Cell]  # 前回のバッファ内容

proc newBuffer(width, height: int): Buffer =
  # 新しいバッファを作成
  var w = max(1, width)
  var h = max(1, height)
  
  result.width = w
  result.height = h
  result.cells = newSeq[Cell](w * h)
  
  # デフォルトで空白で埋める
  for i in 0..<(w * h):
    result.cells[i] = Cell(ch: ' ', fg: 7, bg: 0)

proc `[]`(buffer: Buffer, x, y: int): Cell =
  # 座標からセルを取得
  if x < 0 or x >= buffer.width or y < 0 or y >= buffer.height:
    return Cell(ch: ' ', fg: 7, bg: 0)
  return buffer.cells[y * buffer.width + x]

proc `[]=`(buffer: var Buffer, x, y: int, value: Cell) =
  # 座標にセルを設定
  if x < 0 or x >= buffer.width or y < 0 or y >= buffer.height:
    return
  buffer.cells[y * buffer.width + x] = value

proc print(buffer: var Buffer, x, y: int, text: string, fg: int = 7, bg: int = 0) =
  # バッファにテキストを描画
  var xPos = x
  for ch in text:
    if xPos < buffer.width and y >= 0 and y < buffer.height:
      buffer[xPos, y] = Cell(ch: ch, fg: fg, bg: bg)
    xPos += 1

proc drawFull(buffer: var Buffer) =
  # バッファを全て描画（全画面更新）
  stdout.write("\e[H")  # カーソルをホームポジションに
  
  var lastFg = -1
  var lastBg = -1
  
  for y in 0..<buffer.height:
    stdout.setCursorPos(0, y)
    
    for x in 0..<buffer.width:
      let cell = buffer[x, y]
      
      # 色を変更する必要がある場合
      if cell.fg != lastFg or cell.bg != lastBg:
        stdout.write("\e[", 30 + cell.fg, ";", 40 + cell.bg, "m")
        lastFg = cell.fg
        lastBg = cell.bg
      
      # 文字を出力
      stdout.write(cell.ch)
  
  # バッファを記憶
  buffer.lastCells = buffer.cells
  stdout.flushFile()

proc drawDiff(buffer: var Buffer) =
  # 差分のみを描画
  var changes = 0
  
  # 初回またはサイズ変更時は全描画
  if buffer.lastCells.len != buffer.cells.len:
    drawFull(buffer)
    return
  
  # 変更箇所を探して描画
  for y in 0..<buffer.height:
    for x in 0..<buffer.width:
      let idx = y * buffer.width + x
      let newCell = buffer.cells[idx]
      let oldCell = buffer.lastCells[idx]
      
      # 変更があった場合のみ描画
      if newCell.ch != oldCell.ch or 
         newCell.fg != oldCell.fg or 
         newCell.bg != oldCell.bg:
        
        # カーソル位置を設定
        stdout.setCursorPos(x, y)
        
        # 色を設定
        stdout.write("\e[", 30 + newCell.fg, ";", 40 + newCell.bg, "m")
        
        # 文字を出力
        stdout.write(newCell.ch)
        changes += 1
  
  # バッファを記憶
  buffer.lastCells = buffer.cells
  stdout.flushFile()
  echo "\e[0m\e[", buffer.height + 1, ";0H変更箇所: ", changes  # 下部に情報表示

proc enterRawMode() =
  # 端末をRawモードに設定
  var tios: Termios
  discard tcgetattr(STDIN_FILENO, addr(tios))
  
  # Rawモード設定
  tios.c_lflag = tios.c_lflag and not Cflag(ECHO or ICANON or IEXTEN or ISIG)
  tios.c_iflag = tios.c_iflag and not Cflag(IXON or ICRNL or BRKINT or INPCK or ISTRIP)
  tios.c_cflag = tios.c_cflag or Cflag(CS8)
  tios.c_oflag = tios.c_oflag and not Cflag(OPOST)
  
  # ノンブロッキング入力
  tios.c_cc[VMIN] = cuchar(0)
  tios.c_cc[VTIME] = cuchar(0)
  
  discard tcsetattr(STDIN_FILENO, TCSAFLUSH, addr(tios))

proc exitRawMode() =
  # 端末設定を元に戻す
  var tios: Termios
  discard tcgetattr(STDIN_FILENO, addr(tios))
  
  # 元の設定に戻す
  tios.c_lflag = tios.c_lflag or Cflag(ECHO or ICANON or IEXTEN or ISIG)
  tios.c_iflag = tios.c_iflag or Cflag(IXON or ICRNL or BRKINT or INPCK or ISTRIP)
  tios.c_cflag = tios.c_cflag and not Cflag(CS8)
  tios.c_oflag = tios.c_oflag or Cflag(OPOST)
  
  discard tcsetattr(STDIN_FILENO, TCSAFLUSH, addr(tios))

proc main() =
  # 初期化
  enterRawMode()
  stdout.write("\e[?25l")  # カーソル非表示
  stdout.write("\e[2J")    # 画面クリア
  
  # バッファ作成
  let (width, height) = terminalSize()
  var buffer = newBuffer(width, height - 2)  # 情報表示用に2行余裕を持たせる
  
  # 初期表示
  buffer.print(2, 1, "差分更新デモ - スペースキーで全画面/差分描画を切り替え", 3)
  buffer.print(2, 2, "Ctrl+Cで終了", 3)
  
  # フレーム描画
  for x in 0..<buffer.width:
    buffer[x, 0] = Cell(ch: '-', fg: 6, bg: 0)
    buffer[x, buffer.height-1] = Cell(ch: '-', fg: 6, bg: 0)
  
  for y in 0..<buffer.height:
    buffer[0, y] = Cell(ch: '|', fg: 6, bg: 0)
    buffer[buffer.width-1, y] = Cell(ch: '|', fg: 6, bg: 0)
  
  # 全画面描画
  drawFull(buffer)
  
  # メインループ
  var 
    frame = 0
    useDiff = true  # 差分描画モード
    running = true
  
  echo "\e[0m\e[", height-1, ";0H現在: 差分描画モード"
  
  while running and frame < 1000:
    # 星をランダムに表示 (少量の変更)
    for i in 0..<10:
      # 有効範囲かチェック
      if buffer.width > 2 and buffer.height > 4:
        let x = 1 + rand(max(1, buffer.width-3))
        let y = 3 + rand(max(1, buffer.height-5))
        let color = 1 + rand(6)  # ランダム色
        buffer[x, y] = Cell(ch: '*', fg: color, bg: 0)
    
    # フレームカウンター表示
    frame += 1
    buffer.print(buffer.width - 15, 2, "フレーム: " & $frame, 2)
    
    # 描画タイミング測定
    let start = cpuTime()
    
    # 描画方法に応じた処理
    if useDiff:
      drawDiff(buffer)
    else:
      drawFull(buffer)
    
    let elapsed = (cpuTime() - start) * 1000
    
    # 描画時間表示
    echo "\e[0m\e[", height, ";0H描画時間: ", fmt"{elapsed:.2f}", "ms"
    
    # キー入力チェック
    if kbhit():
      let key = getch()
      
      # スペースキーで描画モード切り替え
      if key == ' ':
        useDiff = not useDiff
        echo "\e[0m\e[", height-1, ";0H現在: ", 
             if useDiff: "差分描画モード" else: "全画面描画モード"
      
      # qで終了
      elif key == 'q':
        running = false
    
    # 少し待機
    sleep(50)
  
  # 終了処理
  stdout.write("\e[?25h")  # カーソル表示
  stdout.write("\e[0m")    # 色リセット
  stdout.flushFile()
  exitRawMode()

# メイン実行
randomize()
main()