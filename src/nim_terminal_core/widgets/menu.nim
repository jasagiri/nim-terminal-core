## ポップアップのメニュー、入れ子のメニュー、画面の上のメニューの帯。規則は ADR-TC-0002 の W-23〜W-26。

import std/unicode
import nim_unicode_width
import ../[geometry, canvas, theme, event, widget, app]

type
  MenuItem* = ref object
    text*: string
    shortcut*: string           ## 右に描く案内 (例: "Ctrl+S")。割り当ては shortcuts が持つ
    enabled*: bool
    action*: proc() {.closure, raises: [].}
    submenu*: Menu
    separator: bool

  Menu* = ref object
    widget: Widget
    items: seq[MenuItem]
    active: int
    shownIn: App
    parentMenu: Menu
    openChild: Menu
    onClose*: proc() {.closure, raises: [].}

  MenuBar* = ref object
    widget: Widget
    titles: seq[string]
    menus: seq[Menu]
    active: int
    app: App

proc widget*(m: Menu): Widget {.raises: [].} = m.widget
proc items*(m: Menu): seq[MenuItem] {.raises: [].} = m.items
proc active*(m: Menu): int {.raises: [].} = m.active    ## 選んでいる項目
proc isShown*(m: Menu): bool {.raises: [].} = not m.shownIn.isNil and m.shownIn.isOpen(m.widget)
proc isSeparator*(i: MenuItem): bool {.raises: [].} = i.separator

proc menuItem*(text: string, action: proc() {.closure, raises: [].} = nil, shortcut = "",
               enabled = true): MenuItem {.raises: [].} =
  MenuItem(text: text, action: action, shortcut: shortcut, enabled: enabled)

proc separator*(): MenuItem {.raises: [].} = MenuItem(separator: true)

proc submenuItem*(text: string, menu: Menu): MenuItem {.raises: [].} =
  MenuItem(text: text, submenu: menu, enabled: true)

proc selectable(i: MenuItem): bool = not i.separator and i.enabled

proc moveActive(m: Menu, by: int) =
  ## 区切りと無効の項目を飛ばして動く。端で回る
  if m.items.len == 0: return
  var i = m.active
  for _ in 0 ..< m.items.len:
    i = (i + by + m.items.len) mod m.items.len
    if m.items[i].selectable:
      m.active = i
      return

proc close*(m: Menu) {.raises: [].} =
  ## W-25: 開いている入れ子のメニューを閉じてから、このメニューを閉じる (後始末は closed)。
  if not m.openChild.isNil: m.openChild.close()
  if m.isShown: m.shownIn.closeLayer(m.widget)

proc closed(m: Menu) =
  ## 層が閉じた後 (close でも、外を押したのでも)
  m.shownIn = nil
  if not m.parentMenu.isNil and m.parentMenu.openChild == m: m.parentMenu.openChild = nil
  if not m.onClose.isNil: m.onClose()

proc root(m: Menu): Menu =
  result = m
  while not result.parentMenu.isNil: result = result.parentMenu

proc popup*(m: Menu, app: App, x, y: int) {.raises: [].}

proc activate(m: Menu, index: int) =
  ## W-24: 入れ子なら開き、そうでなければ全部のメニューを閉じてから動作を呼ぶ
  if index < 0 or index >= m.items.len or not m.items[index].selectable: return
  m.active = index
  let it = m.items[index]
  if not it.submenu.isNil:
    if not m.openChild.isNil: m.openChild.close()
    it.submenu.parentMenu = m
    m.openChild = it.submenu
    it.submenu.popup(m.shownIn, m.widget.rect.right - 1, m.widget.rect.y + 1 + index)
    return
  m.root.close()
  if not it.action.isNil: it.action()

proc newMenu*(items: openArray[MenuItem]): Menu {.raises: [].} =
  ## W-23: 枠の内に項目を 1 行ずつ描き、右に shortcut と、入れ子なら ▸ を描く。選んでいる項目は roSelected、
  ## 無効の項目は roMuted、区切りは横の線。
  ## W-24: 上下 (区切りと無効を飛ばし、端で回る)・Home・End で選び、Enter・Space で選んだ項目を動かす。
  ## 右で入れ子を開き、左と Esc でこのメニューを閉じる。押した項目を動かし、押さずに動かすと選ぶ。
  let m = Menu(items: @items, active: -1)
  m.moveActive(1)
  m.widget = newWidget(focusable = true)
  m.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    c.box(rect(0, 0, c.width, c.height), theme.border, theme[roNormal])
    for i, it in m.items:
      let y = i + 1
      if y >= c.height - 1: break
      if it.separator:
        for x in 1 ..< c.width - 1: discard c.put(x, y, theme.border.horizontal, theme[roBorder])   # Why discard: 1 列ずつ
        continue
      let style = if i == m.active: theme[roSelected] elif not it.enabled: theme[roMuted] else: theme[roNormal]
      c.fill(rect(1, y, c.width - 2, 1), style)
      discard c.put(2, y, it.text, style)                   # Why discard: 幅は measure で取った
      let tail = (if it.submenu.isNil: it.shortcut else: "▸")
      if tail.len > 0: discard c.put(c.width - 2 - c.textWidth(tail), y, tail, style)   # Why discard: 同上
  m.widget.behavior.handle = proc(e: Event): bool =
    case e.kind
    of evKey:
      if e.key.mods != {}: return false
      case e.key.kind
      of kUp: m.moveActive(-1)
      of kDown: m.moveActive(1)
      of kHome:
        m.active = -1
        m.moveActive(1)
      of kEnd:
        m.active = 0
        m.moveActive(-1)
      of kEnter: m.activate(m.active)
      of kRight:
        if m.active >= 0 and not m.items[m.active].submenu.isNil: m.activate(m.active)
      of kLeft, kEscape: m.close()
      of kRune:
        if e.key.rune == Rune(' '): m.activate(m.active) else: return false
      else: return false
      true
    of evPress:
      m.activate(e.y - 1)
      true
    of evMove:
      if e.y - 1 >= 0 and e.y - 1 < m.items.len and m.items[e.y - 1].selectable: m.active = e.y - 1
      true
    else: false
  m.widget.behavior.measure = proc(available: Size, opts: WidthOptions): Size =
    var w = 0
    for it in m.items:
      let tail = (if it.submenu.isNil: it.shortcut else: "▸")
      w = max(w, displayWidth(it.text, opts) + (if tail.len > 0: displayWidth(tail, opts) + 2 else: 0))
    size(w + 4, m.items.len + 2)
  m

proc popup*(m: Menu, app: App, x, y: int) {.raises: [].} =
  ## W-25: (x, y) を左上に開く (画面からはみ出すなら内へずらす)。外を押すと閉じる (lmPopup)。
  if m.isShown: return
  m.shownIn = app
  m.active = -1
  m.moveActive(1)
  let w = m.widget
  app.openLayer(w, proc(screen: Size): Rect =
    let s = w.measure(screen, app.widthOptions)
    at(x, y, s.width, s.height)(screen), lmPopup, proc() = m.closed())

proc newMenuBar*(app: App, entries: openArray[tuple[title: string, menu: Menu]]): MenuBar {.raises: [].} =
  ## W-26: 題を 1 行に並べ、フォーカスがあれば選んでいる題を roSelected で描く。左右で題を選び、
  ## Enter・下・押すで、その題の下にメニューを開く。メニューの中の左右は隣の題のメニューへ移る。
  let b = MenuBar(app: app)
  for e in entries:
    b.titles.add e.title
    b.menus.add e.menu
  b.widget = newWidget(focusable = true)
  b.widget.constraint = fixed(1)
  proc titleX(i: int): int =
    for k in 0 ..< i: result += displayWidth(b.titles[k], app.widthOptions) + 2
  proc open(i: int) =
    for m in b.menus: m.close()
    if i < 0 or i >= b.menus.len: return
    b.active = i
    b.menus[i].popup(app, b.widget.rect.x + titleX(i), b.widget.rect.y + 1)
  proc neighbours(index: int, m: Menu): proc(e: Event): bool {.closure, raises: [].} =
    # Why a factory: ループの中の変数を閉包が捕まえると、全部が最後の値を共有する
    let previous = m.widget.behavior.handle
    result = proc(e: Event): bool =
      if e.kind == evKey and e.key.mods == {} and e.key.kind in {kLeft, kRight} and
         (e.key.kind == kLeft or m.active < 0 or m.items[m.active].submenu.isNil):
        open((index + (if e.key.kind == kLeft: -1 else: 1) + b.menus.len) mod b.menus.len)
        return true
      previous(e)
  for i, m in b.menus: m.widget.behavior.handle = neighbours(i, m)
  b.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    c.fill(theme[roHeader])
    var x = 0
    for i, t in b.titles:
      let style = if focused and i == b.active: theme[roSelected] else: theme[roHeader]
      x += c.put(x, 0, " " & t & " ", style)
  b.widget.behavior.handle = proc(e: Event): bool =
    case e.kind
    of evKey:
      if e.key.mods != {} or b.titles.len == 0: return false
      case e.key.kind
      of kLeft: b.active = (b.active - 1 + b.titles.len) mod b.titles.len
      of kRight: b.active = (b.active + 1) mod b.titles.len
      of kEnter, kDown: open(b.active)
      else: return false
      true
    of evPress:
      for i in 0 ..< b.titles.len:
        let x0 = titleX(i)
        if e.x >= x0 and e.x < x0 + displayWidth(b.titles[i], app.widthOptions) + 2:
          open(i)
          return true
      false
    else: false
  b

proc widget*(b: MenuBar): Widget {.raises: [].} = b.widget
proc active*(b: MenuBar): int {.raises: [].} = b.active
