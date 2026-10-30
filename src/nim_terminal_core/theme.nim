## 見た目の役割ごとのスタイルと、枠の字。ウィジェットは色を直に書かず、役割で引く。

import nim_terminal_io/screen

type
  Role* = enum
    roNormal            ## 地の文字
    roMuted             ## 控えめ: 空の欄の案内、無効のウィジェット、区切り
    roFocused           ## 入力を受けているウィジェット (ボタン・入力欄・チェックボックス)
    roSelected          ## 入力を受けている一覧の、選んでいる行
    roSelectedInactive  ## 入力を受けていない一覧の、選んでいる行
    roBorder            ## 枠
    roTitle             ## 枠の題・見出し
    roHeader            ## 表の見出しの行・タブの並び
    roAccent            ## 進み具合の済んだ所・開いているタブ
    roMatch             ## 当たった文字 (絞り込み)

  BorderChars* = object
    horizontal*, vertical*, topLeft*, topRight*, bottomLeft*, bottomRight*: string

  Theme* = object
    styles*: array[Role, Style]
    border*: BorderChars

const
  LightBorder* = BorderChars(horizontal: "─", vertical: "│", topLeft: "┌", topRight: "┐",
                             bottomLeft: "└", bottomRight: "┘")
  AsciiBorder* = BorderChars(horizontal: "-", vertical: "|", topLeft: "+", topRight: "+",
                             bottomLeft: "+", bottomRight: "+")
    ## 罫線は East Asian Ambiguous で、曖昧な幅を 2 とする端末では崩れる。そのときに使う

proc defaultTheme*(): Theme {.raises: [].} =
  ## 端末の既定の色の上で、反転・太字・下線と 16 色だけを使う。
  result.border = LightBorder
  result.styles[roMuted] = Style(fg: indexed(8))
  result.styles[roFocused] = Style(reverse: true)
  result.styles[roSelected] = Style(reverse: true)
  result.styles[roSelectedInactive] = Style(underline: true)
  result.styles[roBorder] = Style(fg: indexed(8))
  result.styles[roTitle] = Style(bold: true)
  result.styles[roHeader] = Style(bold: true, underline: true)
  result.styles[roAccent] = Style(fg: indexed(6), bold: true)
  result.styles[roMatch] = Style(bold: true, underline: true)

proc `[]`*(t: Theme, r: Role): Style {.raises: [].} = t.styles[r]
