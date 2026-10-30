## 文字を見せるだけのウィジェット。改行で行を分け、幅を越える行は折り返すか切る。規則は ADR-TC-0002 の W-1〜W-2。

import std/strutils
import nim_unicode_width
import ../[geometry, canvas, theme, widget, binding]

type
  Align* = enum
    alLeft, alCenter, alRight

  Label* = ref object
    widget: Widget
    text: string
    align*: Align
    wrap*: bool          ## 幅を越える行を折り返す (偽なら … で切る)
    role*: Role

proc widget*(l: Label): Widget {.raises: [].} = l.widget
proc text*(l: Label): string {.raises: [].} = l.text
proc setText*(l: Label, text: string) {.raises: [].} = l.text = text

proc wrapLine(line: string, width: int, opts: WidthOptions): seq[string] =
  ## 幅 width ごとにクラスタの境で折る (空の行は 1 行)
  if width <= 0: return @[line]
  var cur = ""
  var used = 0
  for c in clusters(line, opts):
    let w = max(c.width, 1)
    if used + w > width and cur.len > 0:
      result.add cur
      cur = ""
      used = 0
    cur.add line[c.bytes]
    used += w
  result.add cur

proc lines(l: Label, width: int, opts: WidthOptions): seq[string] =
  for line in l.text.split('\n'):
    if l.wrap: result.add wrapLine(line, width, opts)
    else: result.add line

proc newLabel*(text = "", align = alLeft, wrap = false, role = roNormal): Label {.raises: [].} =
  ## W-1: 行ごとに、揃えの向きに置く。wrap なら幅で折り返し、そうでなければ幅を越える行を … で切る。
  ## W-2: 測った大きさは、一番長い行の幅と行の数 (wrap なら与えられた幅で折った行の数)。
  let l = Label(text: text, align: align, wrap: wrap, role: role)
  l.widget = newWidget()
  l.widget.constraint = natural()
  l.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    let style = theme[l.role]
    for y, line in l.lines(c.width, c.widthOptions):
      if y >= c.height: break
      let shown = c.fit(line, c.width)
      let w = c.textWidth(shown)
      let x = case l.align
        of alLeft: 0
        of alCenter: (c.width - w) div 2
        of alRight: c.width - w
      discard c.put(x, y, shown, style)   # Why discard: fit で幅に収めた
  l.widget.behavior.measure = proc(available: Size, opts: WidthOptions): Size =
    let ls = l.lines(available.width, opts)
    var w = 0
    for line in ls: w = max(w, displayWidth(line, opts))
    size(w, ls.len)
  l

proc bindText*(l: Label, source: Observable[string]) {.raises: [].} =
  ## source の値を見せ続ける。
  l.text = source.value
  discard source.subscribe(proc(v: string) = l.text = v)   # Why discard: Label と同じだけ生きる
