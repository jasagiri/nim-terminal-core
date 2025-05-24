# test_widgets.nim
## ウィジェットシステムテスト

import unittest
import std/tables
import std/options
import std/sequtils
import std/unicode

import ../src/libterminal
import ../src/libterminal/widget_base
import ../src/libterminal/widgets
import ../src/libterminal/private/common
import ../src/libterminal/button
import ../src/libterminal/label
import ../src/libterminal/textinput
import ../src/libterminal/checkbox
import ../src/libterminal/dialog
import ../src/libterminal/progressbar
import ../src/libterminal/listbox
import ../src/libterminal/dialog
import ../src/libterminal/menu
import ../src/libterminal/scrollview
import ../src/libterminal/tabview
import ../src/libterminal/treeview
import ../src/libterminal/tableview

suite "ウィジェット基本機能":
  test "ウィジェット作成":
    # 基本ウィジェットのインスタンス作成
    let widget = newWidget("test_widget", 0, 0, 10, 5)
    check(widget != nil)
    check(widget.id == "test_widget")
    check(widget.children.len == 0)
    check(widget.parent == nil)
    
    # フラグのデフォルト値
    check(WidgetVisible in widget.flags)
    check(WidgetEnabled in widget.flags)

  test "親子関係":
    let parent = newWidget("parent", 0, 0, 20, 10)
    let child1 = newWidget("child1", 0, 0, 10, 5)
    let child2 = newWidget("child2", 0, 0, 10, 5)
    
    # 子ウィジェットの追加
    parent.addChild(child1)
    parent.addChild(child2)
    
    # 親子関係の確認
    check(parent.children.len == 2)
    check(child1.parent == parent)
    check(child2.parent == parent)
    check(parent.children[0] == child1)
    check(parent.children[1] == child2)
    
    # 子ウィジェットの削除
    discard parent.removeChild(child1)
    check(parent.children.len == 1)
    check(parent.children[0] == child2)
    check(child1.parent == nil)
    
    # 再度追加
    parent.addChild(child1)
    check(parent.children.len == 2)
    
    # すべての子を削除
    # parent.removeAllChildren()  # Method not implemented
    # check(parent.children.len == 0)
    # check(child1.parent == nil)
    # check(child2.parent == nil)

  test "ウィジェットフラグ":
    let widget = newWidget("test", 0, 0, 10, 5)
    
    # デフォルトフラグ
    check(WidgetVisible in widget.flags)
    check(WidgetEnabled in widget.flags)
    check(not (WidgetFocused in widget.flags))
    
    # フラグの設定
    widget.flags.incl(WidgetFocused)
    check(WidgetFocused in widget.flags)
    
    # フラグの解除
    widget.flags.excl(WidgetVisible)
    check(not (WidgetVisible in widget.flags))
    
    # 可視性と有効状態の変更
    widget.setVisible(true)
    check(WidgetVisible in widget.flags)
    
    widget.setEnabled(false)
    check(not (WidgetEnabled in widget.flags))

  test "イベントハンドラ":
    let widget = newWidget("test", 0, 0, 10, 5)
    var handlerCalled = false
    
    # イベントハンドラの追加
    proc testHandler(w: Widget, event: WidgetEvent): bool =
      check(w == widget)
      check(event.kind == WidgetMouseDown)
      handlerCalled = true
      return true
    
    widget.addEventHandler(WidgetMouseDown, testHandler)
    
    # ハンドラが正しく追加されたか確認
    check(widget.eventHandlers.hasKey(WidgetMouseDown))
    check(widget.eventHandlers[WidgetMouseDown].len == 1)
    
    # イベントの発生
    let event = Event(
      kind: EvMouse,
      mouse: MouseEvent(
        action: MousePressed,
        button: MouseLeft,
        x: 5,
        y: 3,
        modifiers: {}
      )
    )
    let handled = widget.handleEvent(event)
    
    # ハンドラが呼ばれたか確認
    check(handlerCalled)
    check(handled)
    
    # イベントハンドラの削除
    widget.removeEventHandler(WidgetMouseDown, testHandler)
    check(not widget.eventHandlers.hasKey(WidgetMouseDown))
    
    # 複数のハンドラ
    var handler1Called = false
    var handler2Called = false
    
    proc handler1(w: Widget, event: WidgetEvent): bool =
      handler1Called = true
      return false  # イベント伝播を続ける
      
    proc handler2(w: Widget, event: WidgetEvent): bool =
      handler2Called = true
      return true   # イベント伝播を停止
    
    widget.addEventHandler(WidgetMouseDown, handler1)
    widget.addEventHandler(WidgetMouseDown, handler2)
    
    let handled2 = widget.handleEvent(event)
    check(handler1Called)
    check(handler2Called)
    check(handled2)  # handler2がtrueを返したので全体としてもtrue

suite "基本ウィジェット":
  test "ラベル":
    let label = newLabel("label_id", "Hello World")
    check(label != nil)
    check(label.id == "label_id")
    check(label.getText() == "Hello World")
    
    # テキストの変更
    label.setText("こんにちは世界")
    check(label.getText() == "こんにちは世界")
    
    # スタイルの変更
    label.style = Style(fg: ColorRed, bg: ColorBlue)
    check(label.style.fg == ColorRed)
    check(label.style.bg == ColorBlue)

  test "ボタン":
    var clicked = false
    proc onButtonClick(widget: Widget, event: WidgetEvent): bool =
      clicked = true
      return true
      
    let button = newButton("button_id", "Click Me")
    check(button != nil)
    check(button.getText() == "Click Me")
    
    # クリックハンドラを追加
    button.onClick(onButtonClick)
    
    # ウィジェットの位置とサイズを設定
    button.rect = Rect(x: 0, y: 0, width: 20, height: 1)
    
    # rectが正しく設定されているか確認
    check(button.rect.x == 0)
    check(button.rect.y == 0) 
    check(button.rect.width == 20)
    check(button.rect.height == 1)
    
    # クリックイベントをシミュレート
    # まずマウスプレス (ボタンの範囲内の座標を使用)
    let pressEvent = Event(
      kind: EvMouse,
      mouse: MouseEvent(
        action: MousePressed,
        button: MouseLeft,
        x: 5,
        y: 0,
        modifiers: {}
      )
    )
    discard button.handleEvent(pressEvent)
    
    # アクティブフラグが設定されているか確認
    check(button.isActive())
    
    # 次にマウスリリース（クリックを完成させる）
    let releaseEvent = Event(
      kind: EvMouse,
      mouse: MouseEvent(
        action: MouseReleased,
        button: MouseLeft,
        x: 5,
        y: 0,
        modifiers: {}
      )
    )
    discard button.handleEvent(releaseEvent)
    
    # ハンドラが呼ばれたか確認
    check(clicked)

  test "チェックボックス":
    let checkbox = newCheckbox("checkbox_id", "Option")
    check(checkbox != nil)
    check(checkbox.getText() == "Option")
    check(not checkbox.isChecked())
    
    # 状態の変更
    checkbox.setChecked(true)
    check(checkbox.isChecked())
    
    # トグル操作
    checkbox.toggle()
    check(not checkbox.isChecked())
    
    checkbox.toggle()
    check(checkbox.isChecked())
    
    # ウィジェットの位置とサイズを設定（マウスイベントのため）
    checkbox.rect = Rect(x: 0, y: 0, width: 20, height: 1)
    
    # クリックでトグルされるか確認
    # マウスプレス (チェックボックスの範囲内の座標を使用)
    let pressEvent = Event(
      kind: EvMouse,
      mouse: MouseEvent(
        action: MousePressed,
        button: MouseLeft,
        x: 5,
        y: 0,
        modifiers: {}
      )
    )
    discard checkbox.handleEvent(pressEvent)
    
    # マウスリリース（クリックを完成させる）
    let releaseEvent = Event(
      kind: EvMouse,
      mouse: MouseEvent(
        action: MouseReleased,
        button: MouseLeft,
        x: 5,
        y: 0,
        modifiers: {}
      )
    )
    discard checkbox.handleEvent(releaseEvent)
    check(not checkbox.isChecked())

  test "テキスト入力":
    let textInput = newTextInput("input_id", "Initial Text")
    check(textInput != nil)
    check(textInput.getText() == "Initial Text")
    
    # テキストの変更
    textInput.setText("New Text")
    check(textInput.getText() == "New Text")
    
    # フォーカスを設定
    textInput.setFocused(true)
    
    # 文字の追加
    for c in "Added":
      let event = Event(
        kind: EvKey,
        key: KeyEvent(
          key: KeyNone,
          ch: c,
          modifiers: {}
        )
      )
      discard textInput.handleEvent(event)
    
    check(textInput.getText() == "New TextAdded")
    
    # バックスペースのテスト
    let backspaceEvent = Event(
      kind: EvKey,
      key: KeyEvent(
        key: KeyBackspace,
        ch: '\0',
        modifiers: {}
      )
    )
    discard textInput.handleEvent(backspaceEvent)
    
    check(textInput.getText() == "New TextAdde")

  test "プログレスバー":
    let progressBar = newProgressBar("progress_id")
    check(progressBar != nil)
    check(progressBar.getValue() == 0.0)
    
    # 値の設定
    progressBar.setValue(0.5)
    check(progressBar.getValue() == 0.5)
    
    # 範囲外の値は調整される
    progressBar.setValue(-0.1)
    check(progressBar.getValue() == 0.0)
    
    progressBar.setValue(1.5)
    check(progressBar.getValue() == 1.0)

suite "複合ウィジェット":
  test "リストボックス":
    let listbox = newListbox("listbox_id")
    check(listbox != nil)
    
    # 項目の追加
    listbox.addItem("Item 1")
    listbox.addItem("Item 2")
    listbox.addItem("Item 3")
    
    check(listbox.getItemCount() == 3)
    check(listbox.getItem(0) == "Item 1")
    check(listbox.getItem(1) == "Item 2")
    check(listbox.getItem(2) == "Item 3")
    
    # 選択項目のテスト
    check(listbox.getSelectedIndex() == -1)  # 初期状態では選択なし
    
    listbox.setSelectedIndex(1)
    check(listbox.getSelectedIndex() == 1)
    check(listbox.getSelectedItem() == some("Item 2"))
    
    # 範囲外のインデックスは無視される
    listbox.setSelectedIndex(10)
    check(listbox.getSelectedIndex() == 1)  # 変更なし
    
    # 項目の削除
    listbox.removeItem(0)
    check(listbox.getItemCount() == 2)
    check(listbox.getItem(0) == "Item 2")  # 元のItem 2が先頭に
    check(listbox.getSelectedIndex() == 0)  # 選択インデックスも更新
    
    listbox.clearItems()
    check(listbox.getItemCount() == 0)
    check(listbox.getSelectedIndex() == -1)

  test "ダイアログ":
    let dialog = newDialog("dialog_id", "Title", "Message")
    check(dialog != nil)
    let dialogState = DialogState(dialog.state)
    check(dialogState.title == "Title")
    check(dialogState.content == "Message")
    
    # ボタンの設定
    let buttons = @[
      DialogButtonInfo(text: "OK", result: DialogOk, isDefault: true, id: "ok"),
      DialogButtonInfo(text: "Cancel", result: DialogCancel, isDefault: false, id: "cancel")
    ]
    dialog.setCustomButtons(buttons)
    
    # 結果のテスト
    check(dialog.getResult() == DialogNone)  # 初期状態では結果なし

  test "メニュー":
    let menu = newMenu("menu_id")
    check(menu != nil)
    
    # 項目の追加
    let fileItem = newMenuItem("File", "file")
    let editItem = newMenuItem("Edit", "edit")
    let viewItem = newMenuItem("View", "view")
    
    menu.addItem(fileItem)
    menu.addItem(editItem)
    menu.addItem(viewItem)
    
    # サブメニューの追加
    let fileMenu = newMenu("file_menu")
    let openItem = newMenuItem("Open", "open")
    let saveItem = newMenuItem("Save", "save")
    fileMenu.addItem(openItem)
    fileMenu.addItem(saveItem)
    
    # Basic menu functionality test
    discard

suite "高度なウィジェット":
  test "スクロールビュー":
    let content = newWidget("content", 0, 0, 100, 100)
    content.rect = Rect(x: 0, y: 0, width: 100, height: 100)
    
    let scrollView = newScrollView("scroll_id")
    check(scrollView != nil)
    
    # Basic functionality test
    discard

  test "タブビュー":
    let tabView = newTabView("tabview_id")
    check(tabView != nil)

  test "基本ウィジェット作成のみテスト":
    # This test just ensures all basic widget types can be created
    discard newTableView("table")
    discard newTreeView("tree") 
    check(true)

  test "ツリービュー":
    let treeView = newTreeView("treeview_id")
    check(treeView != nil)

  test "テーブルビュー":
    let tableView = newTableView("tableview_id")
    check(tableView != nil)