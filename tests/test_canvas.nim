## TC-C-*: 画布の原点・切り抜き・カーソル・切り詰め。

import std/[unittest, options]
import nim_unicode_width
import nim_terminal_io/screen
import nim_terminal_core/[geometry, canvas]

proc row(s: Surface, y: int): string =
  for x in 0 ..< s.screen.width: result.add s.screen.cellText(x, y)

suite "canvas":
  test "TC-C-1 Given a canvas clipped to a part of the screen When text runs past the clip Then only the clipped part is written, and a cut wide cluster leaves a space":
    let s = newSurface(10, 2)
    let c = s.within(rect(2, 0, 5, 1), rect(2, 0, 5, 1))
    discard c.put(0, 0, "abcdefgh")
    check s.row(0) == "  abcde   "
    discard c.put(3, 0, "東京")          # 東 は 5〜6 列、京 は 7〜8 列 (切り抜きは 2〜6)
    check s.row(0) == "  abc東   "       # 京 は切り抜きの外 (続きのセルの cellText は "")
    discard c.put(4, 0, "東")            # 6〜7 列: 6 列だけ見えるので空白。5〜6 列の 東 も片方を失って空白
    check s.row(0) == "  abc     "
    discard c.put(0, 1, "row out of the clip")
    check s.row(1) == "          "

  test "TC-C-1 Given a cluster cut at the left edge of the clip Then the visible half is a space":
    let s = newSurface(6, 1)
    let c = s.within(rect(0, 0, 6, 1), rect(1, 0, 5, 1))
    discard c.put(0, 0, "東京")
    check s.row(0) == "  京  "

  test "TC-C-2 Given text with a zero width cluster When put Then the width counts it as 1, as drawn":
    let s = newSurface(10, 1)
    let c = s.canvas
    check c.put(0, 0, "a東\u0007") == 4
    check c.put(8, 0, "東京") == 4       # 切り抜きを越えても text の幅
    check c.textWidth("a東\u0007") == 4

  test "TC-C-3 Given a style When a rect is filled Then only the cells inside the rect and the clip change":
    let s = newSurface(5, 3)
    let c = s.within(rect(1, 1, 4, 2), rect(0, 0, 3, 3))
    let st = Style(reverse: true)
    c.fill(rect(0, 0, 4, 2), st)
    check s.screen.styleAt(1, 1) == st and s.screen.styleAt(2, 2) == st
    check s.screen.styleAt(3, 1) == Style() and s.screen.styleAt(0, 1) == Style()
    check s.screen.styleAt(1, 0) == Style()

  test "TC-C-4 Given a sub canvas When written Then its origin is its rect and it cannot write outside it":
    let s = newSurface(8, 2)
    let inner = s.canvas.sub(rect(2, 1, 3, 1))
    check inner.width == 3 and inner.height == 1
    discard inner.put(0, 0, "xyzw")
    check s.row(1) == "  xyz   "
    discard inner.put(0, -1, "no")
    check s.row(0) == "        "

  test "TC-C-5 Given cursor positions When set inside and outside the clip Then the last inside one is kept":
    let s = newSurface(8, 2)
    let c = s.within(rect(1, 1, 3, 1), rect(1, 1, 3, 1))
    check s.cursor.isNone
    c.setCursor(1, 0)
    check s.cursor == some((x: 2, y: 1))
    c.setCursor(5, 0)
    check s.cursor == some((x: 2, y: 1))
    c.setCursor(0, 0)
    check s.cursor == some((x: 1, y: 1))

  test "TC-C-6 Given text wider than the room When fitted Then it is cut at a cluster boundary with an ellipsis":
    let c = newSurface(1, 1).canvas
    check c.fit("short", 10) == "short"
    check c.fit("abcdef", 4) == "abc…"
    check c.fit("東京都庁", 5) == "東京…"
    check c.fit("東京都庁", 4) == "東…"
    check c.fit("abc", 0) == ""
    check c.textWidth(c.fit("東京都庁", 6)) <= 6

  test "TC-C-1 Given ambiguous width as wide When written Then the canvas uses the surface's options":
    let s = newSurface(4, 1, WidthOptions(ambiguousWide: true))
    check s.canvas.put(0, 0, "─") == 2
