## shortcuts.nim
## Keyboard shortcut management for libterminal widgets
##
## This module implements a shortcut key system for the widget framework
## that allows binding specific key combinations to actions.

import std/tables
import std/options
# import input  # Reserved for future use
import widgets
import private/common

type
  ShortcutAction* = proc() {.closure.}
  
  ShortcutBinding* = object
    ## Represents a keyboard shortcut binding
    id*: int                      ## Unique identifier for the shortcut
    key*: Key                     ## Primary key
    modifiers*: set[KeyModifier]  ## Modifier keys (Ctrl, Alt, Shift)
    description*: string          ## Human-readable description of the action
    action*: ShortcutAction       ## Callback to execute when triggered
    context*: string              ## Context where the shortcut is active (e.g., "global", "editor", etc.)
  
  ShortcutManager* = ref object
    ## Manages keyboard shortcuts across the application
    shortcuts*: seq[ShortcutBinding]
    contextStack*: seq[string]    ## Stack of active contexts (most recent has highest priority)
    enabled*: bool                ## Whether shortcuts are currently enabled
    nextId*: int                  ## Next available ID for shortcuts

proc newShortcutManager*(): ShortcutManager =
  ## Create a new shortcut manager
  result = ShortcutManager()
  result.shortcuts = @[]
  result.contextStack = @["global"]  # Global context is always active
  result.enabled = true
  result.nextId = 0

proc registerShortcut*(manager: ShortcutManager, key: Key, modifiers: set[KeyModifier],
                      description: string, action: ShortcutAction, context: string = "global"): int =
  ## Register a new keyboard shortcut and return its ID
  let id = manager.nextId
  manager.nextId += 1
  
  let binding = ShortcutBinding(
    id: id,
    key: key,
    modifiers: modifiers,
    description: description,
    action: action,
    context: context
  )
  
  manager.shortcuts.add(binding)
  return id

proc getShortcutById*(manager: ShortcutManager, id: int): Option[ShortcutBinding] =
  ## Get a shortcut by its ID
  for shortcut in manager.shortcuts:
    if shortcut.id == id:
      return some(shortcut)
  return none(ShortcutBinding)

proc findShortcut*(manager: ShortcutManager, key: Key, modifiers: set[KeyModifier], context: string = "global"): Option[ShortcutBinding] =
  ## Find a shortcut by key, modifiers, and context
  for shortcut in manager.shortcuts:
    if shortcut.key == key and shortcut.modifiers == modifiers and shortcut.context == context:
      return some(shortcut)
  return none(ShortcutBinding)

proc findShortcutByKeyEvent*(manager: ShortcutManager, event: KeyEvent): Option[ShortcutBinding] =
  ## Find a shortcut that matches the key event in the current context
  # Search contexts from most specific (top of stack) to global (bottom of stack)
  for contextIdx in countdown(manager.contextStack.high, 0):
    let currentContext = manager.contextStack[contextIdx]
    
    # Search shortcuts in reverse order (most recently added first)
    for i in countdown(manager.shortcuts.high, 0):
      let shortcut = manager.shortcuts[i]
      if shortcut.context == currentContext and 
         shortcut.key == event.key and 
         shortcut.modifiers == event.modifiers:
        return some(shortcut)
  
  return none(ShortcutBinding)

proc unregisterShortcut*(manager: ShortcutManager, key: Key, modifiers: set[KeyModifier], context: string = "global") =
  ## Remove a keyboard shortcut
  var i = 0
  while i < manager.shortcuts.len:
    let shortcut = manager.shortcuts[i]
    if shortcut.key == key and shortcut.modifiers == modifiers and shortcut.context == context:
      manager.shortcuts.delete(i)
    else:
      inc i

proc pushContext*(manager: ShortcutManager, context: string) =
  ## Push a new context onto the stack
  ## Shortcuts in the most recently pushed context have highest priority
  manager.contextStack.add(context)

proc popContext*(manager: ShortcutManager): string =
  ## Pop the most recent context from the stack
  ## Returns the popped context
  if manager.contextStack.len > 1:  # Keep at least the global context
    result = manager.contextStack.pop()
  else:
    result = ""

proc enable*(manager: ShortcutManager) =
  ## Enable the shortcut manager
  manager.enabled = true

proc disable*(manager: ShortcutManager) =
  ## Disable the shortcut manager
  ## When disabled, no shortcuts will be triggered
  manager.enabled = false

proc isEnabled*(manager: ShortcutManager): bool =
  ## Check if the shortcut manager is enabled
  return manager.enabled

proc findMatchingShortcut(manager: ShortcutManager, key: Key, modifiers: set[KeyModifier]): Option[ShortcutBinding] =
  ## Find a shortcut that matches the given key and modifiers
  ## Prioritizes shortcuts in the most recently pushed context
  
  # Search contexts from most specific (top of stack) to global (bottom of stack)
  for contextIdx in countdown(manager.contextStack.high, 0):
    let currentContext = manager.contextStack[contextIdx]
    
    # Search shortcuts in reverse order (most recently added first)
    for i in countdown(manager.shortcuts.high, 0):
      let shortcut = manager.shortcuts[i]
      if shortcut.context == currentContext and 
         shortcut.key == key and 
         shortcut.modifiers == modifiers:
        return some(shortcut)
  
  return none(ShortcutBinding)

proc handleKeyEvent*(manager: ShortcutManager, event: KeyEvent): bool =
  ## Handle a key event and trigger shortcuts if appropriate
  ## Returns true if a shortcut was triggered
  
  if not manager.enabled:
    return false
  
  # Extract modifiers from the event
  let modifiers = event.modifiers
  
  # Find and execute matching shortcut
  let shortcutOpt = manager.findMatchingShortcut(event.key, modifiers)
  if shortcutOpt.isSome:
    let shortcut = shortcutOpt.get
    shortcut.action()
    return true
  
  return false

proc getActiveShortcuts*(manager: ShortcutManager): seq[ShortcutBinding] =
  ## Get all shortcuts that are active in the current context hierarchy
  var activeShortcuts: seq[ShortcutBinding] = @[]
  var seenKeys: Table[tuple[key: Key, mods: set[KeyModifier]], bool] = initTable[tuple[key: Key, mods: set[KeyModifier]], bool]()
  
  # Collect shortcuts from all active contexts, prioritizing more specific ones
  for contextIdx in countdown(manager.contextStack.high, 0):
    let currentContext = manager.contextStack[contextIdx]
    
    for shortcut in manager.shortcuts:
      if shortcut.context == currentContext:
        let keyMod = (shortcut.key, shortcut.modifiers)
        if not seenKeys.hasKey(keyMod):
          activeShortcuts.add(shortcut)
          seenKeys[keyMod] = true
  
  return activeShortcuts

proc getShortcutsForContext*(manager: ShortcutManager, context: string): seq[ShortcutBinding] =
  ## Get all shortcuts for a specific context
  result = @[]
  
  for shortcut in manager.shortcuts:
    if shortcut.context == context:
      result.add(shortcut)

#-----------------------------------------------------------------------------
# Integration with Widget Framework
#-----------------------------------------------------------------------------

proc installShortcutHandler*(manager: ShortcutManager, widgetManager: WidgetManager) =
  ## Install the shortcut handler into the widget system
  ## This will intercept key events before they're passed to focused widgets
  
  # Create a pre-event handler
  let handler = proc(event: Event): bool =
    if event.kind == EvKey:
      return manager.handleKeyEvent(event.key)
    return false
  
  widgetManager.preEventHandlers.add(handler)

proc formatKeyBinding*(key: Key, modifiers: set[KeyModifier]): string =
  ## Format a key binding as a human-readable string
  result = ""
  
  if ModCtrl in modifiers:
    result.add("Ctrl+")
  if ModAlt in modifiers:
    result.add("Alt+")
  if ModShift in modifiers:
    result.add("Shift+")
  
  # Add the key name
  case key
  of KeyF1..KeyF12:
    result.add($key)
  of KeyEnter:
    result.add("Enter")
  of KeyTab:
    result.add("Tab")
  of KeySpace:
    result.add("Space")
  of KeyBackspace:
    result.add("Backspace")
  of KeyEscape:
    result.add("Esc")
  of KeyUp:
    result.add("Up")
  of KeyDown:
    result.add("Down")
  of KeyLeft:
    result.add("Left")
  of KeyRight:
    result.add("Right")
  of KeyHome:
    result.add("Home")
  of KeyEnd:
    result.add("End")
  of KeyPageUp:
    result.add("PgUp")
  of KeyPageDown:
    result.add("PgDn")
  of KeyInsert:
    result.add("Ins")
  of KeyDelete:
    result.add("Del")
  else:
    result.add($key)