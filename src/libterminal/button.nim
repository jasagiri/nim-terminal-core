# button.nim
## ボタンウィジェット

import std/tables
import widget_base
import widgets
import layout

type
  ButtonState* = ref object of WidgetState
    text*: string

  Button* = ref object of Widget

proc newButton*(id: string, text: string = ""): Button =
  ## 新しいボタンを作成
  result = Button()
  result.id = id
  
  # 初期状態設定
  var state = ButtonState()
  state.text = text
  result.state = state
  
  # デフォルトフラグ設定
  result.flags = {WidgetVisible, WidgetEnabled, WidgetFocusable}
  
  # イベントハンドラのテーブルを初期化
  result.eventHandlers = initTable[WidgetEventKind, seq[WidgetEventHandler]]()
  
  # 矩形を初期化
  result.rect = Rect(x: 0, y: 0, width: 0, height: 0)

proc getText*(button: Button): string =
  ## テキストを取得
  ButtonState(button.state).text

proc setText*(button: Button, text: string) =
  ## テキストを設定
  ButtonState(button.state).text = text

proc onClick*(button: Button, handler: WidgetEventHandler) =
  ## クリックハンドラを設定
  button.addEventHandler(WidgetClick, handler)