## ウィジェットが描く先。nim-terminal-io の Screen の上の、原点と切り抜きを持つ窓。規則は ADR-TC-0001 の C-1〜C-6。
## ウィジェットは自分の左上を (0, 0) として描き、切り抜きの外には何も書かれない。

import std/options
import nim_unicode_width
import nim_terminal_io/screen
import ./geometry

export screen   # Style・Color と、描いた Screen を読む手続き

type
  Surface* = ref object
    ## 1 回の描画の全体。描き終えたら screen を端末へ送り、cursor に端末のカーソルを置く
    screen*: Screen
    cursor*: Option[tuple[x, y: int]]
    opts*: WidthOptions

  Canvas* = object
    surface: Surface
    ox, oy: int        # 原点 (画面の位置)
    clip: Rect         # 書いてよい所 (画面の位置)
    width*, height*: int

proc newSurface*(width, height: int, opts = WidthOptions()): Surface {.raises: [].} =
  Surface(screen: newScreen(width, height, opts), opts: opts)

proc canvas*(s: Surface): Canvas {.raises: [].} =
  ## 画面の全体を描く窓。
  let w = s.screen.width
  let h = s.screen.height
  Canvas(surface: s, clip: rect(0, 0, w, h), width: w, height: h)

proc sub*(c: Canvas, r: Rect): Canvas {.raises: [].} =
  ## C-4: r (c の中の位置) を原点とし、切り抜きを r と c の切り抜きの重なりにした窓。
  let area = rect(c.ox + r.x, c.oy + r.y, r.width, r.height)
  Canvas(surface: c.surface, ox: area.x, oy: area.y, clip: intersect(c.clip, area),
         width: r.width, height: r.height)

proc within*(s: Surface, area, clip: Rect): Canvas {.raises: [].} =
  ## 画面の位置 area を原点とし、clip で切り抜く窓 (枠組みが各ウィジェットに渡す)。
  Canvas(surface: s, ox: area.x, oy: area.y, clip: intersect(clip, rect(0, 0, s.screen.width, s.screen.height)),
         width: area.width, height: area.height)

proc widthOptions*(c: Canvas): WidthOptions {.raises: [].} = c.surface.opts

proc textWidth*(c: Canvas, text: string): int {.raises: [].} =
  ## 描いたときの幅 (幅 0 のクラスタは ? として 1 と数える。C-2)。
  for cl in clusters(text, c.surface.opts): result += max(cl.width, 1)

proc put*(c: Canvas, x, y: int, text: string, style = Style()): int {.raises: [].} =
  ## C-1: (x, y) から書記素クラスタごとに書く。切り抜きの外は書かず、切り抜きの端で切れた幅 2 の
  ## クラスタは、見える半分を空白にする。C-2: 戻り値は、切り抜きに関わらず text の幅。
  let ay = c.oy + y
  let row = ay >= c.clip.y and ay < c.clip.bottom
  var col = c.ox + x
  for cl in clusters(text, c.surface.opts):
    var w = cl.width
    var t = text[cl.bytes]
    if w == 0:
      w = 1
      t = "?"
    if row:
      let l = max(col, c.clip.x)
      let r = min(col + w, c.clip.right)
      if r - l == w:
        discard c.surface.screen.put(col, ay, t, style)   # Why discard: 幅は上で数えた
      elif r > l:
        for k in l ..< r: discard c.surface.screen.put(k, ay, " ", style)
    col += w
  col - (c.ox + x)

proc fill*(c: Canvas, r: Rect, style = Style()) {.raises: [].} =
  ## C-3: r (c の中の位置) の切り抜きの中を、style の空白で埋める。
  let area = intersect(c.clip, rect(c.ox + r.x, c.oy + r.y, r.width, r.height))
  for ay in area.y ..< area.bottom:
    for ax in area.x ..< area.right:
      discard c.surface.screen.put(ax, ay, " ", style)   # Why discard: 1 列ずつ

proc fill*(c: Canvas, style = Style()) {.raises: [].} =
  c.fill(rect(0, 0, c.width, c.height), style)

proc setCursor*(c: Canvas, x, y: int) {.raises: [].} =
  ## C-5: 端末のカーソルを (x, y) に置く (日本語の入力の変換の窓もここに出る)。切り抜きの外なら置かない。
  ## 後から置いたものが勝つ。
  let ax = c.ox + x
  let ay = c.oy + y
  if c.clip.contains(ax, ay): c.surface.cursor = some((x: ax, y: ay))

proc fit*(c: Canvas, text: string, width: int, ellipsis = "…"): string {.raises: [].} =
  ## C-6: 幅が width に収まるよう、クラスタの境で切る。切ったときは末尾を ellipsis にする
  ## (ellipsis も入らなければ付けない)。
  if c.textWidth(text) <= width: return text
  let room = width - c.textWidth(ellipsis)
  let limit = if room >= 0: room else: width
  var used = 0
  for cl in clusters(text, c.surface.opts):
    let w = max(cl.width, 1)
    if used + w > limit: break
    result.add text[cl.bytes]
    used += w
  if room >= 0: result.add ellipsis
