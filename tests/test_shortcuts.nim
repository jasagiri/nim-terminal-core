# test_shortcuts.nim
## Shortcut key system tests

import unittest
import std/tables
import std/sets
import std/options

import ../src/libterminal
import ../src/libterminal/shortcuts
import ../src/libterminal/private/common

suite "Shortcut keys":
  test "Shortcut registration and search":
    # Create shortcut manager
    let manager = newShortcutManager()
    check(manager != nil)
    check(manager.shortcuts.len == 0)
    
    # Define action
    var actionCalled = false
    proc testAction() =
      actionCalled = true
      
    # Register shortcut
    let id = manager.registerShortcut(
      KeyEnter,
      {ModCtrl},
      "Test Action",
      testAction,
      "global"
    )
    
    check(id >= 0)  # Valid ID is returned
    check(manager.shortcuts.len == 1)
    
    # Search shortcut by ID
    let shortcutById = manager.getShortcutById(id)
    check(shortcutById.isSome)
    check(shortcutById.get().key == KeyEnter)
    check(shortcutById.get().modifiers == {ModCtrl})
    check(shortcutById.get().description == "Test Action")
    check(shortcutById.get().context == "global")
    
    # Search by key and modifiers
    let shortcutByKey = manager.findShortcut(KeyEnter, {ModCtrl})
    check(shortcutByKey.isSome)
    check(shortcutByKey.get().id == id)
    
    # Not found for different key
    let notFound = manager.findShortcut(KeyEscape, {ModCtrl})
    check(notFound.isNone)
    
    # Search by KeyEvent
    let event = KeyEvent(
      key: KeyEnter,
      modifiers: {ModCtrl}
    )
    
    let shortcutByEvent = manager.findShortcutByKeyEvent(event)
    check(shortcutByEvent.isSome)
    check(shortcutByEvent.get().id == id)