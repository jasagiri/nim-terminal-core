# textinput.nim
## テキスト入力ウィジェット

import std/unicode
import std/tables
import widget_base
import widgets
import layout
import private/common

type
  TextInputState* = ref object of WidgetState
    text*: string
    cursorPos*: int
    selectionStart*: int
    selectionEnd*: int

  TextInput* = ref object of Widget

proc newTextInput*(id: string, text: string = ""): TextInput =
  ## 新しいテキスト入力を作成
  result = TextInput()
  result.id = id
  
  # 初期状態設定
  var state = TextInputState()
  state.text = text
  state.cursorPos = text.len
  state.selectionStart = -1
  state.selectionEnd = -1
  result.state = state
  
  # デフォルトフラグ設定
  result.flags = {WidgetVisible, WidgetEnabled, WidgetFocusable}
  
  # イベントハンドラのテーブルを初期化
  result.eventHandlers = initTable[WidgetEventKind, seq[WidgetEventHandler]]()
  
  # 矩形を初期化
  result.rect = Rect(x: 0, y: 0, width: 0, height: 0)
  
  # キー入力ハンドラの設定
  result.addEventHandler(WidgetChar, proc(widget: Widget, event: WidgetEvent): bool =
    let textInput = TextInput(widget)
    let state = TextInputState(textInput.state)
    let ch = event.ch
    
    # 文字を挿入
    let textRunes = state.text.toRunes
    var newTextRunes = newSeq[Rune]()
    
    # カーソル位置まで既存のテキスト
    for i in 0..<state.cursorPos:
      if i < textRunes.len:
        newTextRunes.add(textRunes[i])
    
    # 新しい文字を挿入
    newTextRunes.add(ch)
    
    # カーソル位置以降の既存のテキスト
    for i in state.cursorPos..<textRunes.len:
      newTextRunes.add(textRunes[i])
    
    state.text = $newTextRunes
    state.cursorPos += 1
    return true
  )
  
  # バックスペースキー処理
  result.addEventHandler(WidgetKeyDown, proc(widget: Widget, event: WidgetEvent): bool =
    if event.key.key == KeyBackspace:
      let textInput = TextInput(widget)
      let state = TextInputState(textInput.state)
      
      if state.cursorPos > 0:
        let textRunes = state.text.toRunes
        var newTextRunes = newSeq[Rune]()
        
        # カーソル位置-1までの文字
        for i in 0..<state.cursorPos-1:
          newTextRunes.add(textRunes[i])
        
        # カーソル位置以降の文字
        for i in state.cursorPos..<textRunes.len:
          newTextRunes.add(textRunes[i])
        
        state.text = $newTextRunes
        state.cursorPos -= 1
        return true
    
    return false
  )

proc getText*(textInput: TextInput): string =
  ## テキストを取得
  TextInputState(textInput.state).text

proc setText*(textInput: TextInput, text: string) =
  ## テキストを設定
  let state = TextInputState(textInput.state)
  state.text = text
  state.cursorPos = text.len

proc getCursorPosition*(textInput: TextInput): int =
  ## カーソル位置を取得
  TextInputState(textInput.state).cursorPos

proc setCursorPosition*(textInput: TextInput, pos: int) =
  ## カーソル位置を設定
  let state = TextInputState(textInput.state)
  let textLen = state.text.toRunes.len
  
  if pos < 0:
    state.cursorPos = 0
  elif pos > textLen:
    state.cursorPos = textLen
  else:
    state.cursorPos = pos