## 進み具合。済んだ割合の棒、百分率、残りの時間の見込み。時計は呼び手が渡す (単調な時計のミリ秒)。
## 規則は ADR-TC-0002 の W-14〜W-16。terminal-ui/progress_bar.nim の Simple と Detailed の形を引き継ぐ。

import std/[options, strutils]
import nim_unicode_width
import ../[geometry, canvas, theme, widget, binding]

type
  ProgressBar* = ref object
    widget: Widget
    title*: string
    total: int
    current: int
    startMs: int64
    lastMs: int64
    showEta*: bool
    showRate*: bool
    filled*, empty*: string    ## 棒の字。罫線の字は曖昧な幅なので、幅は数えて描く

proc widget*(p: ProgressBar): Widget {.raises: [].} = p.widget
proc total*(p: ProgressBar): int {.raises: [].} = p.total
proc current*(p: ProgressBar): int {.raises: [].} = p.current

proc fraction*(p: ProgressBar): float {.raises: [].} =
  ## W-14: current / total を 0〜1 に収めたもの。total が 0 以下なら 0。
  if p.total <= 0: 0.0 else: max(0.0, min(1.0, p.current / p.total))

proc update*(p: ProgressBar, current: int, nowMs: int64) {.raises: [].} =
  p.current = max(current, 0)
  p.lastMs = nowMs

proc setTotal*(p: ProgressBar, total: int) {.raises: [].} = p.total = total

proc etaMs*(p: ProgressBar): Option[int64] {.raises: [].} =
  ## W-15: 始めてからの速さで、残りを見込む (ミリ秒)。進んでいないか、時間が経っていないか、
  ## total が無ければ none。
  let elapsed = p.lastMs - p.startMs
  if p.total <= 0 or p.current <= 0 or elapsed <= 0: return none(int64)
  let left = max(p.total - p.current, 0)
  some(int64(float(elapsed) * float(left) / float(p.current)))

proc ratePerSecond*(p: ProgressBar): Option[float] {.raises: [].} =
  let elapsed = p.lastMs - p.startMs
  if elapsed <= 0: return none(float)
  some(float(p.current) * 1000.0 / float(elapsed))

proc formatDuration*(ms: int64): string {.raises: [].} =
  ## 1 分未満は "12s"、1 時間未満は "3m05s"、それ以上は "2h03m"。
  let s = ms div 1000
  if s < 60: $s & "s"
  elif s < 3600: $(s div 60) & "m" & align($(s mod 60), 2, '0') & "s"
  else: $(s div 3600) & "h" & align($((s mod 3600) div 60), 2, '0') & "m"

proc newProgressBar*(total: int, startMs: int64, title = ""): ProgressBar {.raises: [].} =
  ## W-16: `title [████░░░░]  50% ETA 12s` と描く。棒は、題と後ろの文字を除いた幅で、済んだ割合の
  ## セルを filled (roAccent)、残りを empty (roMuted) で埋める。total が 0 以下なら棒の代わりに数を描く。
  let p = ProgressBar(title: title, total: total, startMs: startMs, lastMs: startMs, showEta: true,
                      filled: "█", empty: "░")
  p.widget = newWidget()
  p.widget.constraint = natural()     # 縦の箱では 1 行、横の箱では使える幅
  p.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    var x = 0
    if p.title.len > 0: x += c.put(0, 0, p.title & " ", theme[roTitle])
    if p.total <= 0:
      discard c.put(x, 0, $p.current, theme[roNormal])   # Why discard: 後ろに描くものが無い
      return
    var tail = " " & align($int(p.fraction * 100), 3) & "%"
    if p.showEta:
      let eta = p.etaMs
      if eta.isSome and p.current < p.total: tail.add " ETA " & formatDuration(eta.get)
    if p.showRate:
      let rate = p.ratePerSecond
      if rate.isSome: tail.add " " & formatFloat(rate.get, ffDecimal, 1) & "/s"
    let room = c.width - x - c.textWidth(tail) - 2
    if room > 0:
      let fw = max(c.textWidth(p.filled), 1)
      let ew = max(c.textWidth(p.empty), 1)
      let doneCells = int(p.fraction * float(room))
      x += c.put(x, 0, "[", theme[roNormal])
      var used = 0
      while used + fw <= doneCells:
        used += c.put(x + used, 0, p.filled, theme[roAccent])
      while used + ew <= room:
        used += c.put(x + used, 0, p.empty, theme[roMuted])
      x += room
      x += c.put(x, 0, "]", theme[roNormal])
    discard c.put(x, 0, tail, theme[roNormal])          # Why discard: 最後
  p.widget.behavior.measure = proc(available: Size, opts: WidthOptions): Size =
    size(available.width, 1)
  p

proc bindProgress*(p: ProgressBar, source: Observable[int], clock: proc(): int64 {.closure, raises: [].}) {.raises: [].} =
  ## source の値を current として見せ続ける。clock は単調な時計のミリ秒。
  p.update(source.value, clock())
  discard source.subscribe(proc(v: int) = p.update(v, clock()))   # Why discard: ProgressBar と同じだけ生きる
