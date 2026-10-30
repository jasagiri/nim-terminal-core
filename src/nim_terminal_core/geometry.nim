## 画面の上の矩形と、四辺の幅 (余白)。位置はセルで数え、右と下の端は含まない。

type
  Rect* = object
    x*, y*, width*, height*: int

  Size* = object
    width*, height*: int

  Edges* = object
    top*, right*, bottom*, left*: int

proc rect*(x, y, width, height: int): Rect {.raises: [].} =
  Rect(x: x, y: y, width: max(width, 0), height: max(height, 0))

proc size*(width, height: int): Size {.raises: [].} = Size(width: max(width, 0), height: max(height, 0))

proc edges*(all: int): Edges {.raises: [].} = Edges(top: all, right: all, bottom: all, left: all)
proc edges*(vertical, horizontal: int): Edges {.raises: [].} =
  Edges(top: vertical, right: horizontal, bottom: vertical, left: horizontal)
proc edges*(top, right, bottom, left: int): Edges {.raises: [].} =
  Edges(top: top, right: right, bottom: bottom, left: left)

proc right*(r: Rect): int {.raises: [].} = r.x + r.width
proc bottom*(r: Rect): int {.raises: [].} = r.y + r.height
proc isEmpty*(r: Rect): bool {.raises: [].} = r.width <= 0 or r.height <= 0
proc size*(r: Rect): Size {.raises: [].} = Size(width: r.width, height: r.height)

proc contains*(r: Rect, x, y: int): bool {.raises: [].} =
  x >= r.x and x < r.right and y >= r.y and y < r.bottom

proc intersect*(a, b: Rect): Rect {.raises: [].} =
  ## 重なり。重ならなければ幅か高さが 0。
  let x = max(a.x, b.x)
  let y = max(a.y, b.y)
  rect(x, y, min(a.right, b.right) - x, min(a.bottom, b.bottom) - y)

proc inset*(r: Rect, e: Edges): Rect {.raises: [].} =
  ## 四辺を内へ縮める。縮めすぎた幅と高さは 0。
  rect(r.x + e.left, r.y + e.top, r.width - e.left - e.right, r.height - e.top - e.bottom)

proc horizontal*(e: Edges): int {.raises: [].} = e.left + e.right
proc vertical*(e: Edges): int {.raises: [].} = e.top + e.bottom
