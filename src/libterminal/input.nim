# input.nim
## Terminal input processing
##
## This module handles input events from the terminal,
## including keyboard and mouse input.

import std/posix
import std/options
# import std/tables     # Reserved for future use
# import std/strutils   # Reserved for future use
import private/common
import private/signals
import private/escape_parser
import raw
import mouse

var
  eventQueue: seq[Event]
  lastTerminalSize: tuple[width: int, height: int] = (0, 0)
  maxInputBufferSize = 1024
  inputBuffer = newSeq[char](maxInputBufferSize)
  pendingEscape = false
  escBuffer = newSeq[char](32)
  escBufferLen = 0

proc createKeyEvent*(key: common.Key, ch: char = '\0', modifiers: set[KeyModifier] = {}): Event =
  ## キーイベントの作成ヘルパー
  result = Event(
    kind: EvKey,
    key: KeyEvent(
      key: key,
      ch: ch,
      modifiers: modifiers
    )
  )

proc createResizeEvent*(width, height: int): Event =
  ## リサイズイベントの作成ヘルパー
  result = Event(
    kind: EvResize,
    resize: ResizeEvent(
      width: width,
      height: height
    )
  )

proc createMouseEvent*(action: MouseAction, button: MouseButton, x, y: int, 
                     modifiers: set[KeyModifier] = {}): Event =
  ## マウスイベントの作成ヘルパー
  result = Event(
    kind: EvMouse,
    mouse: MouseEvent(
      action: action,
      button: button,
      x: x,
      y: y,
      modifiers: modifiers
    )
  )

proc checkSignalEvents*(): Option[Event] =
  ## シグナルイベントをチェックし、対応するイベントに変換する
  let signalEvent = getLastSignalEvent()
  if signalEvent.isNone:
    return none(Event)
    
  let signalType = signalEvent.get()
  case signalType
  of SigInt:
    # Ctrl+C as key event
    return some(createKeyEvent(KeyNone, char(3), {ModCtrl}))
  of SigWinch:
    # Window resize event
    let (width, height) = raw.getTerminalSize()
    if width != lastTerminalSize.width or height != lastTerminalSize.height:
      lastTerminalSize = (width, height)
      return some(createResizeEvent(width, height))
  of SigQuit:
    # Ctrl+\ as key event
    return some(createKeyEvent(KeyNone, char(28), {ModCtrl}))
  of SigTerm, SigHup:
    # Special exit event (could be extended later)
    return none(Event)
  
  return none(Event)

proc parseEscapeSequence*(buffer: openArray[char], count: int): Event =
  ## エスケープシーケンスをパースして対応するイベントに変換
  
  # Validate input parameters
  if count <= 0 or buffer.len < count:
    return Event(kind: EvNone)
  
  # 単一のESCキーの特別処理
  if count == 1 and buffer[0] == '\e':
    return createKeyEvent(KeyEscape)
  
  # エスケープシーケンスをパース
  let escSeq = createEscapeSequence(buffer, count)
  
  # マウスイベントの判定と変換
  if isMouseEvent(escSeq):
    let mouseEvt = parseMouseEvent(escSeq)
    return createMouseEvent(
      mouseEvt.action,
      mouseEvt.button,
      mouseEvt.x,
      mouseEvt.y,
      mouseEvt.modifiers
    )
  
  # キーイベントの判定と変換
  if isKeyEvent(escSeq):
    let keyEvt = parseKeyEvent(escSeq)
    return createKeyEvent(
      keyEvt.key,
      keyEvt.ch,
      keyEvt.modifiers
    )
  
  # 2文字のエスケープシーケンス (ESC + 1文字)
  if escSeq.kind == PsEscape:
    return createKeyEvent(KeyEscape)
  
  # 不明なシーケンス、または解析不可能なシーケンス
  return Event(kind: EvNone)

proc readInputExtended(): Event =
  ## 拡張入力処理（エスケープシーケンス対応版）
  ## 
  ## より多くのキー入力に対応している
  result = Event(kind: EvNone)
  
  # シグナルイベントをまず確認
  let signalEvent = checkSignalEvents()
  if signalEvent.isSome:
    return signalEvent.get()
  
  # 前回のエスケープシーケンスの継続があれば処理
  if pendingEscape and escBufferLen > 0:
    var tv: Timeval
    tv.tv_sec = Time(0)
    tv.tv_usec = Suseconds(10_000)  # 10ミリ秒待機
    
    var fds: TFdSet
    FD_ZERO(fds)
    FD_SET(STDIN_FILENO, fds)
    
    # 追加データを待機
    let ready = select(STDIN_FILENO + 1, addr fds, nil, nil, addr tv)
    if ready > 0:
      let additionalBytes = read(STDIN_FILENO, addr escBuffer[escBufferLen], 
                                escBuffer.len - escBufferLen)
      if additionalBytes > 0:
        escBufferLen += additionalBytes
        # Ensure we don't exceed buffer size
        if escBufferLen > escBuffer.len:
          escBufferLen = escBuffer.len
        let evt = parseEscapeSequence(escBuffer, escBufferLen)
        
        # エスケープシーケンスを消費
        pendingEscape = false
        escBufferLen = 0
        
        return evt
    else:
      # タイムアウト - 単独のエスケープキーと判断
      pendingEscape = false
      escBufferLen = 0
      return createKeyEvent(KeyEscape)
  
  # 入力バッファ
  var bytesRead = read(STDIN_FILENO, addr inputBuffer[0], inputBuffer.len)
  
  if bytesRead <= 0:
    return
  
  # 単一文字の処理
  if bytesRead == 1:
    case inputBuffer[0]
    of '\t':
      return createKeyEvent(KeyTab)
    of '\n', '\r':
      return createKeyEvent(KeyEnter)
    of '\e':
      # エスケープキー - 短い遅延後に追加バイトを確認
      # (エスケープシーケンスの開始かもしれないため)
      var tv: Timeval
      tv.tv_sec = Time(0)
      tv.tv_usec = Suseconds(10_000)  # 10ミリ秒待機
      
      var fds: TFdSet
      FD_ZERO(fds)
      FD_SET(STDIN_FILENO, fds)
      
      # 追加入力があるか確認
      let ready = select(STDIN_FILENO + 1, addr fds, nil, nil, addr tv)
      if ready > 0:
        # エスケープシーケンスの開始
        escBuffer[0] = inputBuffer[0]
        escBufferLen = 1
        
        let additionalBytes = read(STDIN_FILENO, addr escBuffer[1], escBuffer.len - 1)
        if additionalBytes > 0:
          escBufferLen += additionalBytes
          # Ensure we don't exceed buffer size
          if escBufferLen > escBuffer.len:
            escBufferLen = escBuffer.len
          let evt = parseEscapeSequence(escBuffer, escBufferLen)
          
          # エスケープシーケンスが完了していなければ保留状態に
          if evt.kind == EvNone:
            pendingEscape = true
            return evt
          
          # 完了していれば結果を返す
          pendingEscape = false
          escBufferLen = 0
          return evt
      
      # 単独のエスケープキー
      return createKeyEvent(KeyEscape)
      
    of ' ':
      return createKeyEvent(KeySpace)
    of '\b', char(127):  # Backspace or Delete
      return createKeyEvent(KeyBackspace)
    else:
      # Ctrl+キーの検出
      if ord(inputBuffer[0]) < 32:
        let ctrlChar = char(ord(inputBuffer[0]) + ord('A') - 1)
        return createKeyEvent(KeyNone, ctrlChar, {ModCtrl})
      
      # 通常の文字
      return createKeyEvent(KeyNone, inputBuffer[0])
  
  # エスケープシーケンスの処理
  elif bytesRead > 1 and inputBuffer[0] == '\e':
    return parseEscapeSequence(inputBuffer, bytesRead)
  
  # 不明な入力
  return Event(kind: EvNone)

proc readInput*(): Event =
  ## 端末から単一の入力イベントを読み取ります
  ## 
  ## この呼び出しは入力が利用可能になるまでブロックします
  return readInputExtended()

proc pollEvent*(timeout: int = -1): Event =
  ## イベントをポーリングします（オプションでタイムアウト指定可能）
  ## 
  ## - timeoutが負の場合、イベントが利用可能になるまでブロックします
  ## - timeoutが0の場合、イベントをチェックして即座に戻ります
  ## - timeoutが正の場合、最大timeout ミリ秒まで待機します
  ##
  ## イベントが取得できなかった場合、EvNoneが返されます
  
  # まずキューを確認
  if eventQueue.len > 0:
    result = eventQueue[0]
    eventQueue.delete(0)
    return result
  
  # シグナルイベントをチェック
  let signalEvent = checkSignalEvents()
  if signalEvent.isSome:
    return signalEvent.get()
  
  # ポーリング設定
  var fds: TFdSet
  FD_ZERO(fds)
  FD_SET(STDIN_FILENO, fds)
  
  var tv: Timeval
  var tvp: ptr Timeval = nil
  
  if timeout >= 0:
    tv.tv_sec = Time(timeout div 1000)
    tv.tv_usec = Suseconds(timeout mod 1000 * 1000)
    tvp = addr tv
  
  # 入力待機
  let ready = select(STDIN_FILENO + 1, addr fds, nil, nil, tvp)
  
  if ready > 0 and FD_ISSET(STDIN_FILENO, fds) != 0:
    result = readInput()
  else:
    result = Event(kind: EvNone)

proc pushEvent*(event: Event) =
  ## イベントをイベントキューに追加します
  eventQueue.add(event)

proc clearEvents*() =
  ## 保留中のすべてのイベントをキューからクリアします
  eventQueue.setLen(0)

proc enableMouse*(): bool =
  ## マウス入力を有効にします
  ## 
  ## マウス入力を有効にすると、マウスのクリック、移動、ドラッグなどが
  ## イベントとして取得できるようになります。
  ##
  ## 戻り値:
  ## * true: 有効化成功
  ## * false: 有効化失敗（サポートされていない環境など）
  if not mouse.supportsMouseMode():
    return false
  
  # SGRエンコーディングを使用（最も互換性が高い）
  result = mouse.enableMouseMode(MouseSGR, {MaskPress, MaskRelease, MaskDrag})

proc disableMouse*() =
  ## マウス入力を無効にします
  mouse.disableMouseMode()

proc isMouseEnabled*(): bool =
  ## マウス入力が有効かどうかを返します
  return mouse.getActiveMouseMode() != MouseNone

proc handleSignals*() =
  ## シグナルイベントを処理し、必要に応じてイベントキューに追加します
  let signalEvent = checkSignalEvents()
  if signalEvent.isSome:
    pushEvent(signalEvent.get())

# Export signal-related functions for testing
export signals.setSignalFlag