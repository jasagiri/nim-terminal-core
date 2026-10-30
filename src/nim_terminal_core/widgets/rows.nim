## 行を並べて 1 つを選ぶウィジェット (ListBox・TreeView・TableView) の、見える範囲の計算。

proc followTop*(top, selected, rows, count: int): int {.raises: [].} =
  ## 選んでいる行 (無ければ -1) が見えるように動かした、見える最初の行。末尾の後ろに空きを作らない。
  result = top
  let r = max(rows, 1)
  if selected >= 0:
    if selected < result: result = selected
    if selected >= result + r: result = selected - r + 1
  result = max(0, min(result, max(0, count - r)))

proc clampTop*(top, rows, count: int): int {.raises: [].} =
  ## 選びに関わらず、見える最初の行を範囲に収める (ホイールで送ったとき)。
  max(0, min(top, max(0, count - max(rows, 1))))

proc clampIndex*(index, count: int): int {.raises: [].} =
  ## 項目の範囲に収めた位置。項目が無ければ -1。
  if count == 0: -1 else: max(0, min(index, count - 1))
