## ファイルを見る: 左にディレクトリの木 (開くときに読み込む)、右に選んだディレクトリのファイルの表。
## 読めなかったディレクトリは下の行に理由を出す。表の見出しを押すと並べ替える。Ctrl+Q で終わる。

import std/[os, algorithm]
import nim_terminal_core

let problem = newLabel("", role = roMuted)

proc dirsIn(path: string): seq[string] {.raises: [].} =
  try:
    for kind, p in walkDir(path):
      if kind in {pcDir, pcLinkToDir}: result.add p
  except OSError as e:
    problem.setText("読めない: " & path & ": " & e.msg)
  result.sort()

proc filesIn(path: string): seq[seq[string]] {.raises: [].} =
  try:
    for kind, p in walkDir(path):
      if kind == pcFile: result.add @[p.extractFilename, $getFileSize(p)]
  except OSError as e:
    problem.setText("読めない: " & path & ": " & e.msg)

let start = getCurrentDir()
let tree = newTreeView(@[newTreeNode(start.extractFilename, start, hasChildren = true)])
let table = newTableView([column("名前"), column("大きさ", fixed(10), alRight)])
tree.onExpand = proc(n: TreeNode) =
  if n.children.len == 0:
    for d in dirsIn(n.id): n.add newTreeNode(d.extractFilename, d, hasChildren = true)
tree.onSelect = proc(n: TreeNode) = table.setRows(filesIn(n.id))
table.setRows(filesIn(start))

let app = newApp(vbox(hbox(tree.widget.sized(percent(35)), table.widget).gapped(1),
                      problem.widget.sized(fixed(1))))
discard app.shortcuts.add("ctrl+q", "終わる", proc() = app.quit())   # Why discard: 空の表に足すので重ならない
let ended = app.run()
if ended.isFailure: quit("files: " & ended.error, 2)
