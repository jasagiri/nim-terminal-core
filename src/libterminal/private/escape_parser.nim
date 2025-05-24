# escape_parser.nim
## エスケープシーケンスのパース機能
##
## このモジュールはVT100/ANSI/xterm形式のエスケープシーケンスを
## 解析するための機能を提供します。

import std/strutils
import common

type
  ParserState* = enum
    ## パーサーの状態を表す列挙型
    PsNone,      ## 初期状態
    PsEscape,    ## ESC受信
    PsBracket,   ## ESC[ = CSI受信
    PsParams,    ## パラメータ受信中
    PsIntermediate, ## 中間文字受信
    PsComplete   ## パース完了

  EscapeSequence* = object
    ## エスケープシーケンスの構造体
    case kind*: ParserState
    of PsNone:
      discard
    of PsEscape:
      escape_char*: char  # ESC の次の文字
    of PsBracket, PsParams, PsIntermediate, PsComplete:
      params*: seq[int]  # パラメータ配列
      intermediate*: seq[char]  # 中間文字
      final*: char  # 最終文字
      raw_buffer*: string  # 生のエスケープシーケンス

# CSIパラメータをパースするヘルパー関数
proc parseCSIParams*(params_str: string): seq[int] =
  ## CSIパラメータ文字列（例: "1;2;3"）を数値配列に変換
  result = @[]
  
  if params_str.len == 0:
    return @[0]  # デフォルトは0
  
  for p in params_str.split(';'):
    if p.len == 0:
      result.add(0)
    else:
      try:
        result.add(parseInt(p))
      except ValueError:
        result.add(0)

proc createEscapeSequence*(buffer: openArray[char], len: int): EscapeSequence =
  ## バッファからエスケープシーケンスを作成
  # More defensive checks to prevent segfaults
  if len < 2:
    result = default(EscapeSequence)
    result.kind = PsNone
    return
  
  # Ensure buffer has enough data
  if buffer.len < len:
    result = default(EscapeSequence)
    result.kind = PsNone
    return
  
  # Safe first character check
  if buffer.len == 0 or buffer[0] != '\e':
    result = default(EscapeSequence)
    result.kind = PsNone
    return
  
  # ESC + 1文字のシンプルなシーケンス
  if len == 2:
    # Bounds check before accessing
    if buffer.len >= 2:
      return EscapeSequence(
        kind: PsEscape,
        escape_char: buffer[1]
      )
    else:
      result = default(EscapeSequence)
      result.kind = PsNone
      return
  
  # CSIシーケンスの処理
  if buffer.len >= 2 and buffer[1] == '[':
    # CSIシーケンスを解析する
    var params_str = ""
    var intermediate_chars: seq[char] = @[]
    var i = 2  # ESC[ の後から開始
    
    # SGR mouse形式の特別な処理: ESC[< で始まる場合
    if i < len and i < buffer.len and buffer[i] == '<':
      intermediate_chars.add(buffer[i])
      i.inc
    
    # 標準的な中間文字をチェック
    while i < len and i < buffer.len and buffer[i] in {' '..'/'}: # 標準中間文字
      intermediate_chars.add(buffer[i])
      i.inc
    
    # パラメータを集める (数字と;)
    while i < len and i < buffer.len and buffer[i] in {'0'..'9', ';'}:
      params_str.add(buffer[i])
      i.inc
    
    # 追加の中間文字を集める
    while i < len and i < buffer.len and buffer[i] in {' '..'/', '@'..'~'}:
      if buffer[i] in {' '..'/'}: # 中間文字
        intermediate_chars.add(buffer[i])
      else: # 最終文字
        # 最終文字を含むエスケープシーケンスを返す
        var raw = newString(len)
        for j in 0..<len:
          if j < buffer.len:
            raw[j] = buffer[j]
          else:
            raw[j] = '\0'
        
        return EscapeSequence(
          kind: PsComplete,
          params: parseCSIParams(params_str),
          intermediate: intermediate_chars,
          final: buffer[i],
          raw_buffer: raw
        )
      i.inc
  
  # 解析できなかった場合
  result = default(EscapeSequence)
  result.kind = PsNone
  return

proc isMouseEvent*(seq: EscapeSequence): bool =
  ## エスケープシーケンスがマウスイベントかどうかを判定
  if seq.kind != PsComplete:
    return false
  
  # SGRエンコーディング (ESC[<...M or ESC[<...m)
  if seq.params.len >= 3 and 
     seq.final in {'M', 'm'} and 
     seq.intermediate.len > 0 and
     seq.intermediate[0] == '<':
    return true
  
  # X10エンコーディング (ESC[M...)
  if seq.final == 'M' and seq.params.len == 0 and seq.intermediate.len == 0:
    return true
  
  return false

proc parseMouseEvent*(seq: EscapeSequence): MouseEvent =
  ## エスケープシーケンスからマウスイベントを解析
  result = MouseEvent()
  
  if not isMouseEvent(seq):
    return result
  
  # SGRエンコーディング (ESC[<...M or ESC[<...m)
  if seq.params.len >= 3 and seq.intermediate.len > 0 and seq.intermediate[0] == '<':
    let button = seq.params[0]
    let x = seq.params[1] - 1  # 1-indexed -> 0-indexed
    let y = seq.params[2] - 1  # 1-indexed -> 0-indexed
    
    # ボタンの解析
    # SGR式では64以上はホイールイベント
    if button >= 64:
      if (button and 0x01) != 0:
        result.button = MouseWheelDown
      else:
        result.button = MouseWheelUp
    else:
      let button_type = button and 0x03  # 下位2ビットがボタン種類
      case button_type
      of 0: result.button = MouseLeft
      of 1: result.button = MouseMiddle
      of 2: result.button = MouseRight
      else: result.button = MouseNone
    
    # 修飾キーの判定
    var modifiers: set[KeyModifier] = {}
    if (button and 0x04) != 0: modifiers.incl(ModShift)
    if (button and 0x08) != 0: modifiers.incl(ModAlt)
    if (button and 0x10) != 0: modifiers.incl(ModCtrl)
    result.modifiers = modifiers
    
    # アクションの判定
    if seq.final == 'M':  # ボタン押下またはドラッグ
      if (button and 0x20) != 0:
        result.action = MouseMoved
      else:
        result.action = MousePressed
    else:  # seq.final == 'm', ボタン解放
      result.action = MouseReleased
    
    # 座標設定
    result.x = x
    result.y = y
    
  # X10エンコーディング (ESC[M...)
  elif seq.final == 'M' and seq.params.len == 0:
    # X10エンコーディングはオリジナルバッファから直接読み取る必要がある
    if seq.raw_buffer.len >= 6:
      let b = ord(seq.raw_buffer[3]) - 32
      let x = ord(seq.raw_buffer[4]) - 32
      let y = ord(seq.raw_buffer[5]) - 32
      
      # ボタンの解析
      let button_type = b and 0x03
      
      # ボタン種類の判定
      case button_type
      of 0: result.button = MouseLeft
      of 1: result.button = MouseMiddle
      of 2: result.button = MouseRight
      of 3:
        if (b and 0x40) != 0:  # スクロールフラグ
          if (b and 0x01) != 0:
            result.button = MouseWheelDown
          else:
            result.button = MouseWheelUp
        else:
          if (b and 0x20) != 0:
            result.action = MouseMoved
            result.button = MouseNone
          else:
            result.action = MouseReleased
            result.button = MouseNone
      else:
        result.button = MouseNone
      
      # 修飾キーの判定
      var modifiers: set[KeyModifier] = {}
      if (b and 0x04) != 0: modifiers.incl(ModShift)
      if (b and 0x08) != 0: modifiers.incl(ModAlt)
      if (b and 0x10) != 0: modifiers.incl(ModCtrl)
      result.modifiers = modifiers
      
      # アクションの判定
      if (b and 0x20) != 0:
        result.action = MouseMoved
      else:
        result.action = MousePressed
      
      # 座標設定
      result.x = x - 1  # 1-indexed -> 0-indexed
      result.y = y - 1  # 1-indexed -> 0-indexed

proc isKeyEvent*(seq: EscapeSequence): bool =
  ## エスケープシーケンスがキーイベントかどうかを判定
  if seq.kind != PsComplete:
    return false
  
  # キーイベントの代表的なパターン
  if seq.final in {'A', 'B', 'C', 'D', 'E', 'F', 'H', 'P', 'Q', 'R', 'S', '~'}:
    return true
  
  return false

proc parseKeyEvent*(seq: EscapeSequence): KeyEvent =
  ## エスケープシーケンスからキーイベントを解析
  result = KeyEvent(key: KeyNone, ch: '\0', modifiers: {})
  
  if not isKeyEvent(seq):
    return result
  
  # 一般的なファンクションキーのパターン
  case seq.final
  of 'A': result.key = KeyUp
  of 'B': result.key = KeyDown
  of 'C': result.key = KeyRight
  of 'D': result.key = KeyLeft
  of 'E': result.key = KeyHome  # キーパッドの5 (NumpadCenter)
  of 'F': result.key = KeyEnd
  of 'H': result.key = KeyHome
  of 'P': result.key = KeyF1
  of 'Q': result.key = KeyF2
  of 'R': result.key = KeyF3
  of 'S': result.key = KeyF4
  of '~':
    # ~で終わるシーケンスはパラメータ値に基づく
    if seq.params.len > 0:
      case seq.params[0]
      of 1, 7: result.key = KeyHome
      of 2: result.key = KeyInsert
      of 3: result.key = KeyDelete
      of 4, 8: result.key = KeyEnd
      of 5: result.key = KeyPageUp
      of 6: result.key = KeyPageDown
      of 11..15: result.key = Key(ord(KeyF1) + (seq.params[0] - 11))  # F1-F5
      of 17..21: result.key = Key(ord(KeyF6) + (seq.params[0] - 17))  # F6-F10
      of 23..24: result.key = Key(ord(KeyF11) + (seq.params[0] - 23))  # F11-F12
      else: discard
  else: discard
  
  # 修飾キーの解析（一部のターミナルでサポート）
  if seq.params.len >= 2 and seq.params[1] > 0:
    let mod_param = seq.params[1]
    if (mod_param and 1) != 0: result.modifiers.incl(ModShift)
    if (mod_param and 2) != 0: result.modifiers.incl(ModAlt)
    if (mod_param and 4) != 0: result.modifiers.incl(ModCtrl)
  
  return result