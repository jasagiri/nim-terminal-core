## TC-L-*: 縦・横・格子・重ね・任意の割り付け、余白、見える所。

import std/unittest
import nim_unicode_width
import nim_terminal_core/[geometry, widget, layout]

proc leaf(c = fill()): Widget = newWidget().sized(c)

proc measured(w, h: int): Widget =
  result = newWidget(behavior = Behavior(measure: proc(available: Size, opts: WidthOptions): Size = size(w, h)))
  result.constraint = natural()

suite "layout":
  test "TC-L-1 Given a horizontal box of 30% and 70% When laid out in 81 columns Then the parts touch, do not overlap and fill the width":
    let a = leaf(percent(30))
    let b = leaf(percent(70))
    let box = hbox(a, b)
    layout(box, rect(0, 0, 81, 5))
    check a.rect == rect(0, 0, 24, 5)
    check b.rect == rect(24, 0, 57, 5)

  test "TC-L-1 Given a vertical box of 20%, 60%, 20% When laid out Then the sections stack from the top":
    let parts = @[leaf(percent(20)), leaf(percent(60)), leaf(percent(20))]
    let box = vbox(parts)
    layout(box, rect(0, 0, 10, 10))
    check parts[0].rect == rect(0, 0, 10, 2)
    check parts[1].rect == rect(0, 2, 10, 6)
    check parts[2].rect == rect(0, 8, 10, 2)

  test "TC-L-2 Given fixed, auto and weighted fill parts with a gap When laid out Then fixed and measured sizes are taken first and the rest is split by weight":
    let f = leaf(fixed(3))
    let m = measured(5, 2)
    let one = leaf(fill(1))
    let two = leaf(fill(2))
    let box = vbox(f, m, one, two).gapped(1)
    layout(box, rect(0, 0, 4, 20))      # 20 - 3 (gap) - 3 - 2 = 12: 4 と 8
    check f.rect == rect(0, 0, 4, 3)
    check m.rect == rect(0, 4, 4, 2)
    check one.rect == rect(0, 7, 4, 4)
    check two.rect == rect(0, 12, 4, 8)

  test "TC-L-2 Given fill parts that do not divide evenly When laid out Then the earlier ones get the extra cells":
    let parts = solve(10, [fill(), fill(), fill()])
    check parts == @[(offset: 0, size: 4), (offset: 4, size: 3), (offset: 7, size: 3)]

  test "TC-L-3 Given percents that sum to 100 When rounded Then they fill the length exactly, the largest remainders first":
    for total in 0 .. 50:
      let parts = solve(total, [percent(33), percent(33), percent(34)])
      check parts[0].size + parts[1].size + parts[2].size == total
    # 端数が同じなら前の項から
    check solve(10, [percent(25), percent(25), percent(50)]) == @[(offset: 0, size: 3), (offset: 3, size: 2), (offset: 5, size: 5)]

  test "TC-L-4 Given parts larger than the room When laid out Then the last ones are cut, none is negative, and none goes outside":
    let parts = solve(10, [fixed(6), fixed(6), fixed(6)])
    check parts == @[(offset: 0, size: 6), (offset: 6, size: 4), (offset: 10, size: 0)]
    let fills = solve(5, [fixed(5), fill()])
    check fills[1].size == 0

  test "TC-L-5 Given a 3 by 2 grid When six children are placed Then each fills its cell in row order, and a seventh gets nothing":
    var kids: seq[Widget]
    for i in 0 ..< 7: kids.add leaf()
    let g = grid([fill(), fill(), fill()], [fill(), fill()], kids)
    layout(g, rect(0, 0, 10, 9))
    check kids[0].rect == rect(0, 0, 5, 3)
    check kids[1].rect == rect(5, 0, 5, 3)
    check kids[2].rect == rect(0, 3, 5, 3)
    check kids[5].rect == rect(5, 6, 5, 3)
    check kids[6].rect.isEmpty and kids[6].shown.isEmpty

  test "TC-L-6 Given a stack When laid out Then every child gets the content rect":
    let a = leaf()
    let b = leaf()
    let s = stack(a, b).padded(edges(1))
    layout(s, rect(0, 0, 10, 5))
    check a.rect == rect(1, 1, 8, 3) and b.rect == rect(1, 1, 8, 3)

  test "TC-L-7 Given margins of 2 and padding of 1 When laid out Then the content area shrinks by both":
    let inner = leaf().spaced(edges(2))
    let box = vbox(inner).padded(edges(1))
    layout(box, rect(0, 0, 20, 10))
    check inner.rect == rect(3, 3, 14, 4)

  test "TC-L-8 Given an invisible child When laid out Then it takes no space and has no rect":
    let a = leaf(fixed(2))
    let hidden = leaf(fixed(3))
    hidden.visible = false
    let b = leaf()
    let box = vbox(a, hidden, b)
    layout(box, rect(0, 0, 5, 10))
    check b.rect == rect(0, 2, 5, 8)
    check hidden.rect.isEmpty and hidden.shown.isEmpty

  test "TC-L-9 Given nested layouts When resized and laid out again Then the result is the same as a fresh layout":
    proc build(): tuple[root, deep: Widget] =
      let deep = leaf(percent(50))
      let root = vbox(leaf(fixed(1)), hbox(leaf(fixed(4)), deep), leaf(fixed(1)))
      (root, deep)
    let (root, deep) = build()
    layout(root, rect(0, 0, 40, 12))
    layout(root, rect(0, 0, 60, 20))
    let (fresh, freshDeep) = build()
    layout(fresh, rect(0, 0, 60, 20))
    check deep.rect == freshDeep.rect
    check deep.rect == rect(4, 1, 30, 18)

  test "TC-L-10 Given a child placed partly outside its parent's padding When laid out Then it is shown only inside the parent":
    let kid = newWidget()
    let parent = newWidget(arrangement = arCustom)
    parent.behavior.arrange = proc(content: Rect, opts: WidthOptions): Rect =
      kid.place(rect(content.x - 3, content.y, 10, 2))
      content
    parent.add kid
    parent.padding = edges(0, 1)
    layout(parent, rect(5, 5, 8, 4))
    check kid.rect == rect(3, 5, 10, 2)
    check kid.shown == rect(6, 5, 6, 2)

  test "TC-L-10 Given a custom arrangement that does not place a child Then that child is not shown":
    let placed = newWidget()
    let left = newWidget()
    let parent = newWidget(arrangement = arCustom)
    parent.behavior.arrange = proc(content: Rect, opts: WidthOptions): Rect =
      placed.place(content)
      content
    parent.add placed
    parent.add left
    left.place(rect(0, 0, 3, 3))
    layout(parent, rect(0, 0, 5, 5))
    check left.shown.isEmpty and placed.shown == rect(0, 0, 5, 5)

  test "TC-L-2 Given a container of auto children When measured Then it is the sum along its direction plus gaps and padding":
    let box = vbox(measured(3, 1), measured(5, 2)).gapped(1).padded(edges(1))
    check box.measure(size(80, 24)) == size(7, 6)
