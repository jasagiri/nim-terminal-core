# listbox.nim
## リストボックスウィジェット

import std/options
import widget_base
import widgets

type
  ListboxState* = ref object of WidgetState
    items*: seq[string]
    selectedIndex*: int

  Listbox* = ref object of Widget

proc newListbox*(id: string): Listbox =
  ## 新しいリストボックスを作成
  result = Listbox()
  result.id = id
  
  # 初期状態設定
  var state = ListboxState()
  state.items = @[]
  state.selectedIndex = -1
  result.state = state
  
  # デフォルトフラグ設定
  result.flags = {WidgetVisible, WidgetEnabled, WidgetFocusable}

proc addItem*(listbox: Listbox, item: string) =
  ## アイテムを追加
  let state = ListboxState(listbox.state)
  state.items.add(item)

proc removeItem*(listbox: Listbox, index: int) =
  ## アイテムを削除
  let state = ListboxState(listbox.state)
  
  if index >= 0 and index < state.items.len:
    state.items.delete(index)
    
    # 削除された項目が選択されていた場合、選択を更新
    if state.selectedIndex == index:
      if state.items.len > 0:
        state.selectedIndex = min(index, state.items.len - 1)
      else:
        state.selectedIndex = -1
    elif state.selectedIndex > index:
      state.selectedIndex -= 1

proc clearItems*(listbox: Listbox) =
  ## すべてのアイテムを削除
  let state = ListboxState(listbox.state)
  state.items.setLen(0)
  state.selectedIndex = -1

proc getItemCount*(listbox: Listbox): int =
  ## アイテム数を取得
  ListboxState(listbox.state).items.len

proc getItem*(listbox: Listbox, index: int): string =
  ## 指定インデックスのアイテムを取得
  let state = ListboxState(listbox.state)
  
  if index >= 0 and index < state.items.len:
    return state.items[index]
  
  return ""

proc getSelectedIndex*(listbox: Listbox): int =
  ## 選択されているアイテムのインデックスを取得
  ListboxState(listbox.state).selectedIndex

proc setSelectedIndex*(listbox: Listbox, index: int) =
  ## 選択アイテムを設定
  let state = ListboxState(listbox.state)
  
  if index >= -1 and index < state.items.len:
    state.selectedIndex = index

proc getSelectedItem*(listbox: Listbox): Option[string] =
  ## 選択されているアイテムを取得
  let state = ListboxState(listbox.state)
  
  if state.selectedIndex >= 0 and state.selectedIndex < state.items.len:
    return some(state.items[state.selectedIndex])
  
  return none(string)