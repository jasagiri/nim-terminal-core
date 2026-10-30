# output.nim
## Terminal output formatting and display
##
## This module handles drawing to the terminal,
## including cursor control, colors, and text formatting.

# import std/strutils  # Reserved for future use
import std/unicode
import std/options
import std/strformat
import private/common
import private/color_utils
import private/unicode_utils

# terminal モジュールを最後にインポートして Style 型の競合を避ける
import std/terminal

export color_utils.RGBColor, color_utils.ColorMode
export unicode_utils.GraphemeCluster, unicode_utils.EmojiPresentation
# Export our Style type from common
export common.Style, common.Color, common.Attribute

type
  ExtendedColorInfo* = object
    ## 拡張された色情報（RGB/256色）
    case mode*: ColorMode
    of ColorBasic, ColorBright:
      # 基本色はStyle型にそのまま格納されるので追加情報なし
      discard
    of Color256:
      idx256Fg*: int
      idx256Bg*: int
    of ColorRGB:
      rgbFg*: RGBColor
      rgbBg*: RGBColor

  Cell* = object
    ## A single cell on the terminal screen
    ch*: Rune
    style*: common.Style  # 基本的なスタイル情報
    width*: int    # 文字の表示幅
    extColor*: Option[ExtendedColorInfo]  # 拡張色情報（存在する場合）

  Buffer* = object
    ## A buffer of cells representing the terminal content
    width*, height*: int
    cells*: seq[Cell]
    dirty*: bool
    lastBuffer*: seq[Cell]  # 前回描画時のバッファ（差分計算用）

  ColorStyle* = object
    ## 拡張された色情報を持つスタイル
    case mode*: ColorMode
    of ColorBasic, ColorBright:
      basicFg*: Color
      basicBg*: Color
    of Color256:
      idx256Fg*: int
      idx256Bg*: int
    of ColorRGB:
      rgbFg*: RGBColor
      rgbBg*: RGBColor
    attrs*: set[Attribute]  # 属性は共通

  DiffOp* = enum
    ## 差分描画の操作種別
    DiffNone,    # 変更なし
    DiffChar,    # 文字の変更
    DiffFg,      # 前景色の変更
    DiffBg,      # 背景色の変更
    DiffAttrs,   # 属性の変更
    DiffAll      # すべて変更

  CellDiff* = object
    ## セルの差分情報
    op*: DiffOp
    x*, y*: int
    cell*: Cell

# グローバル設定
var
  currentColorMode* = detectColorSupport()  # 現在の色モード
  lastFgColor: string = ""                  # 最後に設定した前景色（最適化用）
  lastBgColor: string = ""                  # 最後に設定した背景色（最適化用）
  lastAttrs: set[Attribute] = {}            # 最後に設定した属性（最適化用）

const
  defaultStyle* = common.Style(
    fg: ColorDefault,
    bg: ColorDefault,
    attrs: {}
  )

proc resetColorCache*() =
  ## 色キャッシュをリセット
  lastFgColor = ""
  lastBgColor = ""
  lastAttrs = {}

proc newBuffer*(width, height: int): Buffer =
  ## Creates a new buffer with the specified dimensions
  result = Buffer(
    width: width,
    height: height,
    dirty: true
  )
  # Initialize cells with spaces
  result.cells = newSeq[Cell](width * height)
  for i in 0..<(width * height):
    result.cells[i] = Cell(
      ch: ' '.Rune, 
      style: defaultStyle, 
      width: 1,
      extColor: none(ExtendedColorInfo)  # 拡張色情報はデフォルトでは使用しない
    )

proc `[]`*(buffer: Buffer, x, y: int): Cell =
  ## Gets the cell at the specified position
  if x < 0 or x >= buffer.width or y < 0 or y >= buffer.height:
    return Cell(
      ch: ' '.Rune, 
      style: defaultStyle, 
      width: 1, 
      extColor: none(ExtendedColorInfo)
    )
  return buffer.cells[y * buffer.width + x]

proc `[]=`*(buffer: var Buffer, x, y: int, cell: Cell) =
  ## Sets the cell at the specified position
  if x < 0 or x >= buffer.width or y < 0 or y >= buffer.height:
    return
  buffer.cells[y * buffer.width + x] = cell
  buffer.dirty = true

proc clear*(buffer: var Buffer) =
  ## Clears the buffer, filling it with spaces
  for i in 0..<(buffer.width * buffer.height):
    buffer.cells[i] = Cell(ch: ' '.Rune, style: defaultStyle, width: 1)
  buffer.dirty = true

proc resize*(buffer: var Buffer, width, height: int) =
  ## Resizes the buffer to the specified dimensions
  if width == buffer.width and height == buffer.height:
    return
    
  let oldBuffer = buffer
  buffer = newBuffer(width, height)
  
  # Copy cells from old buffer where possible
  let minWidth = min(oldBuffer.width, width)
  let minHeight = min(oldBuffer.height, height)
  
  for y in 0..<minHeight:
    for x in 0..<minWidth:
      buffer[x, y] = oldBuffer[x, y]

# Unicode文字幅の計算
proc runeWidth*(r: Rune): int =
  ## Unicodeルーンの表示幅を計算
  ## 
  ## 詳細な実装はunicode_utils.runeWidthに委譲
  ## この関数はoutput.nimで使用できるようラップしている
  return unicode_utils.runeWidth(r)

proc setCursor*(x, y: int) =
  ## Sets the cursor position
  stdout.setCursorPos(x, y)

proc hideCursor*() =
  ## Hides the cursor
  stdout.write(CursorHide)
  stdout.flushFile()

proc showCursor*() =
  ## Shows the cursor
  stdout.write(CursorShow)
  stdout.flushFile()

# 拡張色サポート
proc setRgbForeground*(r, g, b: uint8) =
  ## RGBで前景色を設定
  let colorStr = fmt"\e[38;2;{r};{g};{b}m"
  if lastFgColor != colorStr:
    stdout.write(colorStr)
    lastFgColor = colorStr

proc setRgbBackground*(r, g, b: uint8) =
  ## RGBで背景色を設定
  let colorStr = fmt"\e[48;2;{r};{g};{b}m"
  if lastBgColor != colorStr:
    stdout.write(colorStr)
    lastBgColor = colorStr

proc set256Foreground*(index: int) =
  ## 256色モードで前景色を設定
  let colorStr = fmt"\e[38;5;{index}m"
  if lastFgColor != colorStr:
    stdout.write(colorStr)
    lastFgColor = colorStr

proc set256Background*(index: int) =
  ## 256色モードで背景色を設定
  let colorStr = fmt"\e[48;5;{index}m"
  if lastBgColor != colorStr:
    stdout.write(colorStr)
    lastBgColor = colorStr

proc setStyle*(style: common.Style) =
  ## Sets the current terminal style based on detected color support
  # Reset first if needed
  var needReset = false
  
  if style.fg != ColorDefault or style.bg != ColorDefault or style.attrs != {}:
    stdout.write(AttrReset)
    needReset = true
    lastFgColor = ""
    lastBgColor = ""
    lastAttrs = {}
  
  # Set foreground color
  if style.fg != ColorDefault:
    case currentColorMode
    of ColorRGB:
      # RGB色
      let rgb = toRGB(style.fg)
      setRgbForeground(rgb.r, rgb.g, rgb.b)
    of Color256:
      # 256色
      let rgb = toRGB(style.fg)
      let index = to256Index(rgb)
      set256Foreground(index)
    else:
      # 基本色
      let colorStr = fmt"\e[{30 + ord(style.fg)}m"
      if lastFgColor != colorStr:
        stdout.write(colorStr)
        lastFgColor = colorStr
  
  # Set background color
  if style.bg != ColorDefault:
    case currentColorMode
    of ColorRGB:
      # RGB色
      let rgb = toRGB(style.bg)
      setRgbBackground(rgb.r, rgb.g, rgb.b)
    of Color256:
      # 256色
      let rgb = toRGB(style.bg)
      let index = to256Index(rgb)
      set256Background(index)
    else:
      # 基本色
      let colorStr = fmt"\e[{40 + ord(style.bg)}m"
      if lastBgColor != colorStr:
        stdout.write(colorStr)
        lastBgColor = colorStr
  
  # Set attributes
  if style.attrs != lastAttrs:
    for attr in style.attrs:
      case attr
      of AttrBoldAttr: stdout.write(AttrBold)
      of AttrDimAttr: stdout.write(AttrDim)
      of AttrItalicAttr: stdout.write(AttrItalic)
      of AttrUnderlineAttr: stdout.write(AttrUnderline)
      of AttrBlinkAttr: stdout.write(AttrBlink)
      of AttrReverseAttr: stdout.write(AttrReverse)
      of AttrHiddenAttr: stdout.write(AttrHidden)
      of AttrStrikethroughAttr: stdout.write(AttrStrikethrough)
      of AttrNormal: discard
    lastAttrs = style.attrs

# 直接RGBスタイルを設定する関数
proc setRGBStyle*(fgRGB: RGBColor, bgRGB: RGBColor, attrs: set[Attribute] = {}) =
  ## RGB色を直接指定してスタイルを設定
  ## 
  ## 端末のサポートに基づいて適切な色表現にフォールバック
  stdout.write(AttrReset)
  lastFgColor = ""
  lastBgColor = ""
  lastAttrs = {}
  
  # 端末の色モードに基づいて適切な色表現を使用
  case currentColorMode
  of ColorRGB:
    # RGB対応端末ではRGB値を直接使用
    setRgbForeground(fgRGB.r, fgRGB.g, fgRGB.b)
    setRgbBackground(bgRGB.r, bgRGB.g, bgRGB.b)
  of Color256:
    # 256色対応なら変換して使用
    set256Foreground(to256Index(fgRGB))
    set256Background(to256Index(bgRGB))
  else:
    # 基本色のみなら最も近い基本色を使用
    let fgBasic = closestBasicColor(fgRGB)
    let bgBasic = closestBasicColor(bgRGB)
    let fgStr = fmt"\e[{30 + ord(fgBasic)}m"
    let bgStr = fmt"\e[{40 + ord(bgBasic)}m"
    stdout.write(fgStr)
    stdout.write(bgStr)
    lastFgColor = fgStr
    lastBgColor = bgStr
  
  # 属性を設定
  if attrs != {}:
    for attr in attrs:
      case attr
      of AttrBoldAttr: stdout.write(AttrBold)
      of AttrDimAttr: stdout.write(AttrDim)
      of AttrItalicAttr: stdout.write(AttrItalic)
      of AttrUnderlineAttr: stdout.write(AttrUnderline)
      of AttrBlinkAttr: stdout.write(AttrBlink)
      of AttrReverseAttr: stdout.write(AttrReverse)
      of AttrHiddenAttr: stdout.write(AttrHidden)
      of AttrStrikethroughAttr: stdout.write(AttrStrikethrough)
      of AttrNormal: discard
    lastAttrs = attrs

proc setColorStyle*(style: ColorStyle) =
  ## 拡張色情報を使用してスタイルを設定
  # リセット
  stdout.write(AttrReset)
  lastFgColor = ""
  lastBgColor = ""
  lastAttrs = {}
  
  # 色モードに基づいて色を設定
  case style.mode
  of ColorBasic, ColorBright:
    # 基本色
    if style.basicFg != ColorDefault:
      let colorStr = fmt"\e[{30 + ord(style.basicFg)}m"
      if lastFgColor != colorStr:
        stdout.write(colorStr)
        lastFgColor = colorStr
    
    if style.basicBg != ColorDefault:
      let colorStr = fmt"\e[{40 + ord(style.basicBg)}m"
      if lastBgColor != colorStr:
        stdout.write(colorStr)
        lastBgColor = colorStr
      
  of Color256:
    # 256色
    if style.idx256Fg >= 0:
      set256Foreground(style.idx256Fg)
    
    if style.idx256Bg >= 0:
      set256Background(style.idx256Bg)
    
  of ColorRGB:
    # RGB色
    setRgbForeground(style.rgbFg.r, style.rgbFg.g, style.rgbFg.b)
    setRgbBackground(style.rgbBg.r, style.rgbBg.g, style.rgbBg.b)
  
  # 属性設定
  if style.attrs != lastAttrs:
    for attr in style.attrs:
      case attr
      of AttrBoldAttr: stdout.write(AttrBold)
      of AttrDimAttr: stdout.write(AttrDim)
      of AttrItalicAttr: stdout.write(AttrItalic)
      of AttrUnderlineAttr: stdout.write(AttrUnderline)
      of AttrBlinkAttr: stdout.write(AttrBlink)
      of AttrReverseAttr: stdout.write(AttrReverse)
      of AttrHiddenAttr: stdout.write(AttrHidden)
      of AttrStrikethroughAttr: stdout.write(AttrStrikethrough)
      of AttrNormal: discard
    lastAttrs = style.attrs

# 差分計算
proc calculateDiff*(oldBuffer, newBuffer: Buffer): seq[CellDiff] =
  ## 2つのバッファの差分を計算
  result = @[]
  
  # サイズが異なる場合は全体を差分として処理
  if oldBuffer.width != newBuffer.width or oldBuffer.height != newBuffer.height:
    for y in 0..<newBuffer.height:
      for x in 0..<newBuffer.width:
        result.add(CellDiff(
          op: DiffAll,
          x: x,
          y: y,
          cell: newBuffer[x, y]
        ))
    return result
  
  # セルごとに差分を調べる
  for y in 0..<newBuffer.height:
    for x in 0..<newBuffer.width:
      let oldCell = oldBuffer[x, y]
      let newCell = newBuffer[x, y]
      
      # 変更がない場合はスキップ
      let basicStyleUnchanged = 
        oldCell.ch == newCell.ch and
        oldCell.style.fg == newCell.style.fg and
        oldCell.style.bg == newCell.style.bg and
        oldCell.style.attrs == newCell.style.attrs
      
      # 拡張色情報の比較
      let extColorUnchanged = 
        (oldCell.extColor.isNone and newCell.extColor.isNone) or
        (oldCell.extColor.isSome and newCell.extColor.isSome and 
         oldCell.extColor.get.mode == newCell.extColor.get.mode and
         (
           (oldCell.extColor.get.mode == ColorRGB and
            oldCell.extColor.get.rgbFg == newCell.extColor.get.rgbFg and
            oldCell.extColor.get.rgbBg == newCell.extColor.get.rgbBg) or
           (oldCell.extColor.get.mode == Color256 and
            oldCell.extColor.get.idx256Fg == newCell.extColor.get.idx256Fg and
            oldCell.extColor.get.idx256Bg == newCell.extColor.get.idx256Bg)
         )
        )
      
      # 基本スタイルと拡張色の両方が変更されていない場合はスキップ
      if basicStyleUnchanged and extColorUnchanged:
        continue
      
      # 変更の種類を判定
      var op = DiffNone
      
      # 文字の変更
      if oldCell.ch != newCell.ch:
        op = if op == DiffNone: DiffChar else: DiffAll
      
      # 基本スタイルの変更
      if oldCell.style.fg != newCell.style.fg:
        op = if op == DiffNone: DiffFg 
             elif op == DiffChar: DiffAll
             elif op == DiffBg: DiffAll
             else: op
      
      if oldCell.style.bg != newCell.style.bg:
        op = if op == DiffNone: DiffBg
             elif op == DiffChar: DiffAll
             elif op == DiffFg: DiffAll
             else: op
      
      if oldCell.style.attrs != newCell.style.attrs:
        op = if op == DiffNone: DiffAttrs else: DiffAll
        
      # 拡張色情報の変更検出
      let oldHasExt = oldCell.extColor.isSome
      let newHasExt = newCell.extColor.isSome
      
      if oldHasExt != newHasExt:
        # 拡張色の有無が変わった
        op = if op == DiffNone or op == DiffFg or op == DiffBg: DiffAll else: op
      elif oldHasExt and newHasExt:
        # 両方とも拡張色情報あり
        let oldExt = oldCell.extColor.get
        let newExt = newCell.extColor.get
        
        if oldExt.mode != newExt.mode:
          # 色モードが変わった
          op = if op == DiffNone or op == DiffFg or op == DiffBg: DiffAll else: op
        else:
          # 同じ色モードでの比較
          case oldExt.mode
          of ColorRGB:
            if oldExt.rgbFg != newExt.rgbFg:
              op = if op == DiffNone: DiffFg 
                   elif op == DiffChar or op == DiffBg: DiffAll
                   else: op
            if oldExt.rgbBg != newExt.rgbBg:
              op = if op == DiffNone: DiffBg
                   elif op == DiffChar or op == DiffFg: DiffAll
                   else: op
          of Color256:
            if oldExt.idx256Fg != newExt.idx256Fg:
              op = if op == DiffNone: DiffFg 
                   elif op == DiffChar or op == DiffBg: DiffAll
                   else: op
            if oldExt.idx256Bg != newExt.idx256Bg:
              op = if op == DiffNone: DiffBg
                   elif op == DiffChar or op == DiffFg: DiffAll
                   else: op
          else:
            # 基本色モードは通常のスタイルで比較済み
            discard
      
      # 差分情報を追加
      if op != DiffNone:
        result.add(CellDiff(
          op: op,
          x: x,
          y: y,
          cell: newCell
        ))

# 最適化描画
proc drawOptimized*(buffer: var Buffer) =
  ## 差分に基づいた最適化描画を行う
  # 前回の描画バッファがなければ全体描画
  if buffer.lastBuffer.len == 0 or 
     buffer.lastBuffer.len != buffer.cells.len:
    # 全体を描画
    hideCursor()
    stdout.write(AttrReset)
    eraseScreen()
    
    var lastX = -1
    var lastY = -1
    var lastStyle: common.Style
    
    for y in 0..<buffer.height:
      for x in 0..<buffer.width:
        let cell = buffer[x, y]
        
        # 位置が連続していない場合はカーソル移動
        if x != lastX + 1 or y != lastY:
          setCursor(x, y)
        
        # スタイル設定
        if cell.extColor.isSome and 
           (currentColorMode == ColorRGB or currentColorMode == Color256):
          # 拡張色情報が存在し、端末がサポートしている場合はそれを使用
          let extColor = cell.extColor.get
          
          # モードに応じた色設定
          case extColor.mode
          of ColorRGB:
            if currentColorMode == ColorRGB:
              # RGB色を直接使用
              setRgbForeground(extColor.rgbFg.r, extColor.rgbFg.g, extColor.rgbFg.b)
              setRgbBackground(extColor.rgbBg.r, extColor.rgbBg.g, extColor.rgbBg.b)
            else:
              # RGB未対応の場合は256色に変換
              set256Foreground(to256Index(extColor.rgbFg))
              set256Background(to256Index(extColor.rgbBg))
          of Color256:
            # 256色設定
            set256Foreground(extColor.idx256Fg)
            set256Background(extColor.idx256Bg)
          else:
            # 基本色の場合は通常のスタイルを使用
            if cell.style != lastStyle:
              setStyle(cell.style)
              lastStyle = cell.style
        else:
          # 拡張色情報がない場合は通常のスタイルを使用
          if cell.style != lastStyle:
            setStyle(cell.style)
            lastStyle = cell.style
        
        # 文字描画
        stdout.write($cell.ch)
        
        # 位置更新
        lastX = x
        lastY = y
        
        # 全角文字の場合は次の位置をスキップ
        if cell.width > 1:
          lastX += cell.width - 1
          # x += cell.width - 1  # TODO: Fix wide character handling
    
    # バッファをコピー
    buffer.lastBuffer = buffer.cells
    showCursor()
    stdout.flushFile()
    return
  
  # 差分を計算
  var oldBuffer = Buffer(
    width: buffer.width,
    height: buffer.height,
    cells: buffer.lastBuffer
  )
  
  let diffs = calculateDiff(oldBuffer, buffer)
  
  # 差分がなければ何もしない
  if diffs.len == 0:
    return
  
  # 効率化判定: 差分が多すぎる場合は全画面更新
  if diffs.len > buffer.width * buffer.height div 3:
    # 全体を描画
    hideCursor()
    stdout.write(AttrReset)
    eraseScreen()
    
    var lastX = -1
    var lastY = -1
    var lastStyle: common.Style
    
    for y in 0..<buffer.height:
      for x in 0..<buffer.width:
        let cell = buffer[x, y]
        
        # 位置が連続していない場合はカーソル移動
        if x != lastX + 1 or y != lastY:
          setCursor(x, y)
        
        # スタイル設定
        if cell.extColor.isSome and 
           (currentColorMode == ColorRGB or currentColorMode == Color256):
          # 拡張色情報が存在し、端末がサポートしている場合はそれを使用
          let extColor = cell.extColor.get
          
          # モードに応じた色設定
          case extColor.mode
          of ColorRGB:
            if currentColorMode == ColorRGB:
              # RGB色を直接使用
              setRgbForeground(extColor.rgbFg.r, extColor.rgbFg.g, extColor.rgbFg.b)
              setRgbBackground(extColor.rgbBg.r, extColor.rgbBg.g, extColor.rgbBg.b)
            else:
              # RGB未対応の場合は256色に変換
              set256Foreground(to256Index(extColor.rgbFg))
              set256Background(to256Index(extColor.rgbBg))
          of Color256:
            # 256色設定
            set256Foreground(extColor.idx256Fg)
            set256Background(extColor.idx256Bg)
          else:
            # 基本色の場合は通常のスタイルを使用
            if cell.style != lastStyle:
              setStyle(cell.style)
              lastStyle = cell.style
        else:
          # 拡張色情報がない場合は通常のスタイルを使用
          if cell.style != lastStyle:
            setStyle(cell.style)
            lastStyle = cell.style
        
        # 文字描画
        stdout.write($cell.ch)
        
        # 位置更新
        lastX = x
        lastY = y
        
        # 全角文字の場合は次の位置をスキップ
        if cell.width > 1:
          lastX += cell.width - 1
          # x += cell.width - 1  # TODO: Fix wide character handling
  else:
    # 部分更新
    hideCursor()
    
    var lastX = -1
    var lastY = -1
    var lastStyle: common.Style
    
    for diff in diffs:
      # カーソル移動
      if diff.x != lastX + 1 or diff.y != lastY:
        setCursor(diff.x, diff.y)
      
      # 変更の種類に応じた処理
      let cell = diff.cell
      
      case diff.op
      of DiffChar:
        # 文字のみ変更
        stdout.write($cell.ch)
      of DiffFg, DiffBg, DiffAttrs, DiffAll:
        # スタイル変更を含む
        
        # 拡張色情報があれば使用
        if cell.extColor.isSome and 
           (currentColorMode == ColorRGB or currentColorMode == Color256):
          let extColor = cell.extColor.get
          
          # モードに応じた色設定
          case extColor.mode
          of ColorRGB:
            if currentColorMode == ColorRGB:
              # RGB色を直接使用
              setRgbForeground(extColor.rgbFg.r, extColor.rgbFg.g, extColor.rgbFg.b)
              setRgbBackground(extColor.rgbBg.r, extColor.rgbBg.g, extColor.rgbBg.b)
            else:
              # RGB未対応の場合は256色に変換
              set256Foreground(to256Index(extColor.rgbFg))
              set256Background(to256Index(extColor.rgbBg))
          of Color256:
            # 256色設定
            set256Foreground(extColor.idx256Fg)
            set256Background(extColor.idx256Bg)
          else:
            # 基本色の場合は通常のスタイルを使用
            setStyle(cell.style)
            lastStyle = cell.style
        else:
          # 基本スタイルを使用
          setStyle(cell.style)
          lastStyle = cell.style
          
        stdout.write($cell.ch)
      of DiffNone:
        discard
      
      # 位置更新
      lastX = diff.x
      lastY = diff.y
      
      # 全角文字の場合
      if diff.cell.width > 1:
        lastX += diff.cell.width - 1
  
  # バッファをコピー
  buffer.lastBuffer = buffer.cells
  showCursor()
  stdout.flushFile()

proc drawBuffer*(buffer: var Buffer) =
  ## バッファの内容を端末に描画
  ## 
  ## 最適化描画を使用して効率的に描画
  drawOptimized(buffer)
  buffer.dirty = false

proc printAdvanced*(buffer: var Buffer, x, y: int, text: string,
                 style: common.Style) =
  ## グラフィームクラスタを考慮したテキスト描画（高度なUnicode対応）
  ## 
  ## Unicode結合文字や絵文字シーケンスを正しく処理する
  let clusters = unicode_utils.splitIntoGraphemeClusters(text)
  var xPos = x
  
  for cluster in clusters:
    # 画面幅を超える場合は描画を中止
    if xPos >= buffer.width:
      break
    
    # クラスタの最初の文字を描画
    # (すべての文字を表現できないが、最初の文字が基底文字と一般的)
    let mainRune = cluster.codePoints[0]
    let width = cluster.width  # クラスタ全体の幅を使用
    
    # セルを設定
    buffer[xPos, y] = Cell(
      ch: mainRune, 
      style: style, 
      width: width,
      extColor: none(ExtendedColorInfo)
    )
    
    # 全角文字やEmojiの場合は次のセルをスキップ用に設定
    if width > 1 and xPos + 1 < buffer.width:
      buffer[xPos + 1, y] = Cell(
        ch: ' '.Rune, 
        style: style, 
        width: 0,  # 幅0はスキップ用セルを意味する
        extColor: none(ExtendedColorInfo)
      )
    
    # 次の描画位置へ
    xPos += width

proc print*(buffer: var Buffer, x, y: int, text: string,
           style: common.Style) =
  ## 指定位置にスタイル付きテキストを描画
  var xPos = x
  
  for ch in text.toRunes():
    if xPos >= buffer.width:
      break
    
    let width = runeWidth(ch)
    if width <= 0:
      continue  # 制御文字や結合文字はスキップ
    
    # 文字をセット
    buffer[xPos, y] = Cell(ch: ch, style: style, width: width)
    
    # 全角文字の場合は追加のセルをスキップ
    if width > 1 and xPos + 1 < buffer.width:
      # スペースで埋める（描画時に全角文字として処理）
      buffer[xPos + 1, y] = Cell(ch: ' '.Rune, style: style, width: 0)
    
    xPos += width

proc print*(buffer: var Buffer, x, y: int, text: string) =
  ## デフォルトスタイルでテキストを描画
  let style = common.Style(
    fg: ColorDefault,
    bg: ColorDefault,
    attrs: {}
  )
  buffer.print(x, y, text, style)

proc printRGB*(buffer: var Buffer, x, y: int, text: string,
              fgRGB: RGBColor, bgRGB: RGBColor = RGBColor(r:0, g:0, b:0),
              attrs: set[Attribute] = {}) =
  ## RGB色でテキストを描画
  ## 
  ## 端末が対応していない場合は自動的に近似色にフォールバック
  
  # RGB色情報を一時的に保存するためのColorStyle
  var colorStyle = ColorStyle(
    mode: currentColorMode,
    attrs: attrs
  )
  
  # 通常のStyle（バッファ描画用）
  var style: common.Style
    
  # 端末の色モードに基づいて適切な色表現方法を選択
  case currentColorMode
  of ColorRGB:
    # RGB対応端末では実際のRGB値を使用
    colorStyle.rgbFg = fgRGB
    colorStyle.rgbBg = bgRGB
    
    # Style型はRGBを直接サポートしないため、近似の基本色を使用
    # （描画時は実際にはsetRgbForeground/setRgbBackgroundが使用される）
    style = common.Style(
      fg: closestBasicColor(fgRGB),
      bg: closestBasicColor(bgRGB),
      attrs: attrs
    )
    
  of Color256:
    # 256色対応なら256色インデックスを使用
    colorStyle.idx256Fg = to256Index(fgRGB)
    colorStyle.idx256Bg = to256Index(bgRGB)
    
    # Style型は256色インデックスを直接サポートしないため、近似の基本色を使用
    style = common.Style(
      fg: closestBasicColor(fgRGB),
      bg: closestBasicColor(bgRGB),
      attrs: attrs
    )
    
  else:
    # 基本色のみなら最も近い基本色を使用
    colorStyle.basicFg = closestBasicColor(fgRGB)
    colorStyle.basicBg = closestBasicColor(bgRGB)
    
    style = common.Style(
      fg: closestBasicColor(fgRGB),
      bg: closestBasicColor(bgRGB),
      attrs: attrs
    )
  
  # バッファに文字を描画（基本スタイル）
  buffer.print(x, y, text, style)
  
  # RGB/256色情報をCell.extColorフィールドに追加
  let pos = y * buffer.width + x
  let strLen = text.len
  
  # テキストの各文字に拡張色情報を追加
  for i in 0..<min(strLen, buffer.width - x):
    if pos + i < buffer.cells.len:
      var extColor: ExtendedColorInfo
      case currentColorMode
      of ColorRGB:
        extColor = ExtendedColorInfo(
          mode: ColorRGB,
          rgbFg: fgRGB,
          rgbBg: bgRGB
        )
      of Color256:
        extColor = ExtendedColorInfo(
          mode: Color256,
          idx256Fg: to256Index(fgRGB),
          idx256Bg: to256Index(bgRGB)
        )
      else:
        # 基本色モードでは拡張色情報は不要
        continue
        
      buffer.cells[pos + i].extColor = some(extColor)

proc printRGBAdvanced*(buffer: var Buffer, x, y: int, text: string,
                    fgRGB: RGBColor, bgRGB: RGBColor = RGBColor(r:0, g:0, b:0),
                    attrs: set[Attribute] = {}) =
  ## グラフィームクラスタを考慮したRGB色テキスト描画
  ## 
  ## Unicode結合文字や絵文字シーケンスを正しく処理する
  
  # 通常のスタイル（基本的なフォールバック用）
  var style: common.Style
    
  # 端末の色モードに基づいて適切な色表現方法を選択
  case currentColorMode
  of ColorRGB:
    style = common.Style(
      fg: closestBasicColor(fgRGB),
      bg: closestBasicColor(bgRGB),
      attrs: attrs
    )
  of Color256:
    style = common.Style(
      fg: closestBasicColor(fgRGB),
      bg: closestBasicColor(bgRGB),
      attrs: attrs
    )
  else:
    style = common.Style(
      fg: closestBasicColor(fgRGB),
      bg: closestBasicColor(bgRGB),
      attrs: attrs
    )
  
  # グラフィームクラスタに基づいた描画
  let clusters = unicode_utils.splitIntoGraphemeClusters(text)
  var xPos = x
  
  for cluster in clusters:
    # 画面幅を超える場合は描画を中止
    if xPos >= buffer.width:
      break
    
    # クラスタの最初の文字を描画
    let mainRune = cluster.codePoints[0]
    let width = cluster.width
    
    # 拡張色情報を作成
    var extColor: Option[ExtendedColorInfo]
    
    if currentColorMode in {ColorRGB, Color256}:
      var colorInfo: ExtendedColorInfo
      
      case currentColorMode
      of ColorRGB:
        colorInfo = ExtendedColorInfo(
          mode: ColorRGB,
          rgbFg: fgRGB,
          rgbBg: bgRGB
        )
      of Color256:
        colorInfo = ExtendedColorInfo(
          mode: Color256,
          idx256Fg: to256Index(fgRGB),
          idx256Bg: to256Index(bgRGB)
        )
      else:
        # 基本色モードでは拡張情報なし
        discard
      
      extColor = some(colorInfo)
    else:
      extColor = none(ExtendedColorInfo)
    
    # セルを設定
    buffer[xPos, y] = Cell(
      ch: mainRune, 
      style: style, 
      width: width,
      extColor: extColor
    )
    
    # 全角文字やEmojiの場合は次のセルをスキップ用に設定
    if width > 1 and xPos + 1 < buffer.width:
      buffer[xPos + 1, y] = Cell(
        ch: ' '.Rune, 
        style: style, 
        width: 0,
        extColor: extColor
      )
    
    # 次の描画位置へ
    xPos += width

proc printColorName*(buffer: var Buffer, x, y: int, text: string,
                   colorName: X11ColorName, bgColorName: X11ColorName = Black,
                   attrs: set[Attribute] = {}) =
  ## 色名でテキストを描画
  ## 
  ## 端末が対応していない場合は自動的に近似色にフォールバック
  let fgRGB = x11ColorMap[colorName]
  let bgRGB = x11ColorMap[bgColorName]
  
  # RGB値が分かったので、printRGB関数を使用
  buffer.printRGB(x, y, text, fgRGB, bgRGB, attrs)

proc printColorNameAdvanced*(buffer: var Buffer, x, y: int, text: string,
                          colorName: X11ColorName, bgColorName: X11ColorName = Black,
                          attrs: set[Attribute] = {}) =
  ## グラフィームクラスタを考慮した名前付き色テキスト描画
  ## 
  ## Unicode結合文字や絵文字シーケンスを正しく処理する
  let fgRGB = x11ColorMap[colorName]
  let bgRGB = x11ColorMap[bgColorName]
  
  # RGB値が分かったので拡張関数を使用
  buffer.printRGBAdvanced(x, y, text, fgRGB, bgRGB, attrs)

proc clearScreen*() =
  ## 画面をクリア
  stdout.write(EraseDisplay)
  setCursor(0, 0)
  stdout.flushFile()

proc setCursorStyle*(style: string) =
  ## カーソルスタイルを変更
  ## 
  ## styleは以下の値が使用可能:
  ## - "block" - ブロックカーソル
  ## - "block-blink" - 点滅するブロックカーソル
  ## - "underline" - 下線カーソル
  ## - "underline-blink" - 点滅する下線カーソル
  ## - "bar" - 縦棒カーソル
  ## - "bar-blink" - 点滅する縦棒カーソル
  ##
  ## 注意: 全ての端末が全てのスタイルをサポートしているわけではない
  case style
  of "block":
    stdout.write("\e[2 q")
  of "block-blink":
    stdout.write("\e[1 q")
  of "underline":
    stdout.write("\e[4 q")
  of "underline-blink":
    stdout.write("\e[3 q")
  of "bar":
    stdout.write("\e[6 q")
  of "bar-blink":
    stdout.write("\e[5 q")
  else:
    # 不明なスタイルはデフォルトを使用
    stdout.write("\e[0 q")
  stdout.flushFile()

proc setColorMode*(mode: ColorMode) =
  ## 使用する色モードを設定
  currentColorMode = mode

#-----------------------------------------------------------------
# Enhanced Unicode text support
#-----------------------------------------------------------------

proc printMultiLine*(buffer: var Buffer, x, y: int, text: string,
                     style: common.Style, maxWidth: int = 0, 
                     wrapMode: unicode_utils.LineWrapMode = unicode_utils.WrapWord): int =
  ## Print multi-line text with proper wrapping
  ## Returns the number of lines written
  ## 
  ## Args:
  ##   buffer: The target buffer
  ##   x, y: Starting position
  ##   text: Text to print
  ##   style: Text style
  ##   maxWidth: Maximum width (0 means use from x to buffer width)
  ##   wrapMode: How to wrap text (WrapNone, WrapCharacter, WrapWord)
  ##
  ## Returns:
  ##   Number of lines written
  
  # Calculate effective max width if not specified
  let effectiveMaxWidth = if maxWidth <= 0: buffer.width - x else: maxWidth
  
  # Split text into lines with proper wrapping
  let lines = unicode_utils.splitLines(text, effectiveMaxWidth, wrapMode)
  
  # Print each line
  for i, line in lines:
    if y + i >= buffer.height:
      break
    buffer.printAdvanced(x, y + i, line, style)
  
  return lines.len

proc printMultiLineRGB*(buffer: var Buffer, x, y: int, text: string,
                      fgRGB: RGBColor, bgRGB: RGBColor = RGBColor(r:0, g:0, b:0),
                      attrs: set[Attribute] = {}, maxWidth: int = 0,
                      wrapMode: unicode_utils.LineWrapMode = unicode_utils.WrapWord): int =
  ## Print multi-line text with proper wrapping and RGB colors
  ## Returns the number of lines written
  
  # Calculate effective max width if not specified
  let effectiveMaxWidth = if maxWidth <= 0: buffer.width - x else: maxWidth
  
  # Split text into lines with proper wrapping
  let lines = unicode_utils.splitLines(text, effectiveMaxWidth, wrapMode)
  
  # Print each line
  for i, line in lines:
    if y + i >= buffer.height:
      break
    buffer.printRGBAdvanced(x, y + i, line, fgRGB, bgRGB, attrs)
  
  return lines.len

proc printBidirectional*(buffer: var Buffer, x, y: int, text: string, style: common.Style) =
  ## Print text with proper bidirectional handling
  ## 
  ## Detects text direction and formats accordingly, handling mixed RTL/LTR text
  let dir = unicode_utils.getTextDirection(text)
  
  if dir == unicode_utils.RightToLeft:
    # For RTL text, calculate width and right-align
    let width = unicode_utils.displayWidth(text)
    let alignedX = max(0, x - width)
    buffer.printAdvanced(alignedX, y, text, style)
  else:
    # For LTR text, print normally
    buffer.printAdvanced(x, y, text, style)

proc printTextWithCursor*(buffer: var Buffer, x, y: int, text: string, 
                         cursorPos: int, style: common.Style, cursorStyle: common.Style) =
  ## Print text with a cursor at the specified logical position
  ## 
  ## Args:
  ##   buffer: The target buffer
  ##   x, y: Starting position
  ##   text: Text to print
  ##   cursorPos: Cursor position in text (logical, not visual)
  ##   style: Normal text style
  ##   cursorStyle: Style for the character at cursor position
  
  # Convert logical cursor position to visual position
  var visualPos = 0
  if cursorPos > 0 and cursorPos <= text.len:
    visualPos = unicode_utils.logicalPosToVisual(text, cursorPos)
  
  # Split text into grapheme clusters
  let clusters = unicode_utils.splitIntoGraphemeClusters(text)
  var xPos = x
  var currentVisualPos = 0
  
  for cluster in clusters:
    # Skip if beyond screen width
    if xPos >= buffer.width:
      break
    
    # Determine style based on cursor position
    let useStyle = if currentVisualPos == visualPos: cursorStyle else: style
    
    # Get main rune from cluster
    let mainRune = cluster.codePoints[0]
    let width = cluster.width
    
    # Set cell with appropriate style
    buffer[xPos, y] = Cell(
      ch: mainRune,
      style: useStyle,
      width: width,
      extColor: none(ExtendedColorInfo)
    )
    
    # Handle wide characters
    if width > 1 and xPos + 1 < buffer.width:
      buffer[xPos + 1, y] = Cell(
        ch: ' '.Rune,
        style: useStyle,
        width: 0,
        extColor: none(ExtendedColorInfo)
      )
    
    # Move to next position
    xPos += width
    currentVisualPos += width

  # If cursor is at the end of text, show it
  if cursorPos == text.len and xPos < buffer.width:
    buffer[xPos, y] = Cell(
      ch: ' '.Rune,
      style: cursorStyle,
      width: 1,
      extColor: none(ExtendedColorInfo)
    )
    
# Export the LineWrapMode enum from unicode_utils
export unicode_utils.LineWrapMode, unicode_utils.TextDirection

# Export unicode utility functions
export unicode_utils.getTextDirection, unicode_utils.displayWidth
export unicode_utils.visualPosToLogical, unicode_utils.logicalPosToVisual