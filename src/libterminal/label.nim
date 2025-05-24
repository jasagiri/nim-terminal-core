# label.nim
## ラベルウィジェット

import std/tables
import widget_base
import widgets
import layout

type
  LabelState* = ref object of WidgetState
    text*: string

  Label* = ref object of Widget

proc newLabel*(id: string, text: string = ""): Label =
  ## 新しいラベルを作成
  result = Label()
  result.id = id
  
  # 初期状態設定
  var state = LabelState()
  state.text = text
  result.state = state
  
  # デフォルトフラグ設定
  result.flags = {WidgetVisible, WidgetEnabled}
  
  # イベントハンドラのテーブルを初期化
  result.eventHandlers = initTable[WidgetEventKind, seq[WidgetEventHandler]]()
  
  # 矩形を初期化
  result.rect = Rect(x: 0, y: 0, width: 0, height: 0)

proc getText*(label: Label): string =
  ## テキストを取得
  LabelState(label.state).text

proc setText*(label: Label, text: string) =
  ## テキストを設定
  LabelState(label.state).text = text