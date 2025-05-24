# test_shortcuts.nim
## ショートカットキーシステムのテスト

import unittest
import std/tables
import std/sets
import std/options

import ../src/libterminal
import ../src/libterminal/shortcuts
import ../src/libterminal/private/common

suite "ショートカットキー":
  test "ショートカットの登録と検索":
    # ショートカットマネージャの作成
    let manager = newShortcutManager()
    check(manager != nil)
    check(manager.shortcuts.len == 0)
    
    # アクションの定義
    var actionCalled = false
    proc testAction() =
      actionCalled = true
      
    # ショートカットの登録
    let id = manager.registerShortcut(
      KeyEnter,
      {ModCtrl},
      "Test Action",
      testAction,
      "global"
    )
    
    check(id >= 0)  # 有効なIDが返される
    check(manager.shortcuts.len == 1)
    
    # IDによるショートカットの検索
    let shortcutById = manager.getShortcutById(id)
    check(shortcutById.isSome)
    check(shortcutById.get().key == KeyEnter)
    check(shortcutById.get().modifiers == {ModCtrl})
    check(shortcutById.get().description == "Test Action")
    check(shortcutById.get().context == "global")
    
    # キーとモディファイアによる検索
    let shortcutByKey = manager.findShortcut(KeyEnter, {ModCtrl})
    check(shortcutByKey.isSome)
    check(shortcutByKey.get().id == id)
    
    # 異なるキーの場合は見つからない
    let notFound = manager.findShortcut(KeyEscape, {ModCtrl})
    check(notFound.isNone)
    
    # KeyEventによる検索
    let event = KeyEvent(
      key: KeyEnter,
      modifiers: {ModCtrl}
    )
    
    let shortcutByEvent = manager.findShortcutByKeyEvent(event)
    check(shortcutByEvent.isSome)
    check(shortcutByEvent.get().id == id)