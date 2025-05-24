# mouse.nim
## ターミナルでのマウス入力サポート
##
## このモジュールはマウス入力を有効化し、マウスイベントを
## 扱うための機能を提供します。

import std/terminal
import private/common

type
  MouseMode* = enum
    ## マウスモードの設定
    MouseNone,        ## マウス無効
    MouseX10,         ## 基本モード: クリックのみ
    MouseVT200,       ## 標準モード: クリックとリリース
    MouseButtonEvent, ## ボタンイベントモード
    MouseAnyEvent,    ## 任意のイベントモード（移動含む）
    MouseSGR,         ## SGRエンコーディングモード（推奨）
    MouseURXVT        ## URXVTエンコーディングモード

  MouseEventMask* = enum
    ## マウスイベントの種類のマスク
    MaskPress,      ## ボタン押下
    MaskRelease,    ## ボタン解放
    MaskClick,      ## クリック（押下+解放）
    MaskDoubleClick,## ダブルクリック
    MaskTripleClick,## トリプルクリック
    MaskMotion,     ## マウス移動
    MaskDrag        ## ドラッグ

var
  activeMouseMode: MouseMode = MouseNone
  activeMask: set[MouseEventMask] = {MaskPress, MaskRelease}

# マウスモードの設定用エスケープシーケンス
const
  # マウスモード有効化シーケンス
  MOUSE_X10_ON       = "\x1B[?9h"    # X10互換マウスモード
  MOUSE_VT200_ON     = "\x1B[?1000h" # 通常トラッキングモード
  MOUSE_BTN_EVENT_ON = "\x1B[?1002h" # ボタンイベントモード
  MOUSE_ANY_EVENT_ON = "\x1B[?1003h" # 任意のイベントモード
  
  # マウスモード無効化シーケンス
  MOUSE_X10_OFF       = "\x1B[?9l"
  MOUSE_VT200_OFF     = "\x1B[?1000l"
  MOUSE_BTN_EVENT_OFF = "\x1B[?1002l"
  MOUSE_ANY_EVENT_OFF = "\x1B[?1003l"
  
  # マウスエンコーディング設定
  MOUSE_SGR_ENC_ON    = "\x1B[?1006h" # SGRエンコーディング
  MOUSE_URXVT_ENC_ON  = "\x1B[?1015h" # URXVTエンコーディング
  
  # マウスエンコーディング無効化
  MOUSE_SGR_ENC_OFF   = "\x1B[?1006l"
  MOUSE_URXVT_ENC_OFF = "\x1B[?1015l"

proc disableMouseMode*() =
  ## すべてのマウスモードを無効にする
  if activeMouseMode != MouseNone:
    # すべてのモードを無効化
    stdout.write(MOUSE_X10_OFF)
    stdout.write(MOUSE_VT200_OFF)
    stdout.write(MOUSE_BTN_EVENT_OFF)
    stdout.write(MOUSE_ANY_EVENT_OFF)
    
    # エンコーディングも無効化
    stdout.write(MOUSE_SGR_ENC_OFF)
    stdout.write(MOUSE_URXVT_ENC_OFF)
    
    stdout.flushFile()
    activeMouseMode = MouseNone

proc enableMouseMode*(mode: MouseMode, mask: set[MouseEventMask] = {MaskPress, MaskRelease}): bool =
  ## 指定されたマウスモードを有効にする
  ## 
  ## mode: 使用するマウスモード
  ## mask: 取得したいイベントの種類
  ## 
  ## 戻り値:
  ## * true: 設定成功
  ## * false: 設定失敗または既に同じモードが設定済み
  
  if mode == activeMouseMode and mask == activeMask:
    return false
  
  # 現在のモードをクリア
  disableMouseMode()
  
  # 新しいモードを設定
  case mode
  of MouseNone:
    return true
  of MouseX10:
    stdout.write(MOUSE_X10_ON)
  of MouseVT200:
    stdout.write(MOUSE_VT200_ON)
  of MouseButtonEvent:
    stdout.write(MOUSE_VT200_ON)
    stdout.write(MOUSE_BTN_EVENT_ON)
  of MouseAnyEvent:
    stdout.write(MOUSE_VT200_ON)
    stdout.write(MOUSE_ANY_EVENT_ON)
  of MouseSGR:
    stdout.write(MOUSE_VT200_ON)
    if MaskMotion in mask:
      stdout.write(MOUSE_ANY_EVENT_ON)
    elif MaskDrag in mask:
      stdout.write(MOUSE_BTN_EVENT_ON)
    stdout.write(MOUSE_SGR_ENC_ON)
  of MouseURXVT:
    stdout.write(MOUSE_VT200_ON)
    if MaskMotion in mask:
      stdout.write(MOUSE_ANY_EVENT_ON)
    elif MaskDrag in mask:
      stdout.write(MOUSE_BTN_EVENT_ON)
    stdout.write(MOUSE_URXVT_ENC_ON)
  
  stdout.flushFile()
  activeMouseMode = mode
  activeMask = mask
  return true

proc getActiveMouseMode*(): MouseMode =
  ## 現在のマウスモードを取得
  return activeMouseMode

proc supportsMouseMode*(): bool =
  ## 現在の端末がマウスモードをサポートしているかを確認
  ## 
  ## 注意: これは正確な判定ではなく、単に現在の環境が
  ## 端末エミュレータである可能性を判定するのみです
  return terminal.isatty(stdout)

proc mouseOn*() =
  ## 標準的なマウスモードを有効にするショートカット
  discard enableMouseMode(MouseSGR, {MaskPress, MaskRelease, MaskDrag})

proc mouseOff*() =
  ## マウスモードを無効にするショートカット
  disableMouseMode()

# アプリケーション終了時のクリーンアップ
proc cleanup() {.noconv.} =
  if activeMouseMode != MouseNone:
    disableMouseMode()

# クリーンアップハンドラを登録
import std/exitprocs
addExitProc(cleanup)