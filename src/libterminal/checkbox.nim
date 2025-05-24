# checkbox.nim
## チェックボックスウィジェット

import std/tables
import widget_base
import widgets
import layout

type
  CheckboxState* = ref object of WidgetState
    text*: string
    checked*: bool

  Checkbox* = ref object of Widget

proc toggle*(checkbox: Checkbox) =
  ## チェック状態をトグル
  let state = CheckboxState(checkbox.state)
  state.checked = not state.checked

proc newCheckbox*(id: string, text: string = "", checked: bool = false): Checkbox =
  ## 新しいチェックボックスを作成
  result = Checkbox()
  result.id = id
  
  # 初期状態設定
  var state = CheckboxState()
  state.text = text
  state.checked = checked
  result.state = state
  
  # デフォルトフラグ設定
  result.flags = {WidgetVisible, WidgetEnabled, WidgetFocusable}
  
  # イベントハンドラのテーブルを初期化
  result.eventHandlers = initTable[WidgetEventKind, seq[WidgetEventHandler]]()
  
  # 矩形を初期化
  result.rect = Rect(x: 0, y: 0, width: 0, height: 0)
  
  # クリックイベントでトグル処理
  result.addEventHandler(WidgetClick, proc(widget: Widget, event: WidgetEvent): bool =
    let checkbox = Checkbox(widget)
    checkbox.toggle()
    return true
  )

proc getText*(checkbox: Checkbox): string =
  ## テキストを取得
  CheckboxState(checkbox.state).text

proc setText*(checkbox: Checkbox, text: string) =
  ## テキストを設定
  CheckboxState(checkbox.state).text = text

proc isChecked*(checkbox: Checkbox): bool =
  ## チェック状態を取得
  CheckboxState(checkbox.state).checked

proc setChecked*(checkbox: Checkbox, checked: bool) =
  ## チェック状態を設定
  CheckboxState(checkbox.state).checked = checked