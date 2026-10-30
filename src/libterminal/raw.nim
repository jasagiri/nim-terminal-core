# raw.nim
## Low-level terminal control module
##
## This module provides direct control over the terminal,
## including raw mode handling and terminal information.

import std/posix
import std/terminal
import std/options
# import private/common  # Currently unused, reserved for future use
import private/signals
when defined(test):
  import private/test_utils

# Import critical posix types directly
type
  Termios = object
    c_iflag, c_oflag, c_cflag, c_lflag: uint32
    c_cc: array[20, uint8]
    c_ispeed, c_ospeed: uint32
    
  Cflag = uint32

# Common termios constants (these may vary by platform)
const
  INPCK = 0x0010
  ISTRIP = 0x0020
  OPOST = 0x0001
  CSIZE = 0x0030
  PARENB = 0x0100
  CS8 = 0x0020
  ECHO = 0x0008
  ICANON = 0x0002
  IEXTEN = 0x8000
  ISIG = 0x0001
  IXON = 0x0400
  IXOFF = 0x1000
  ICRNL = 0x0100
  INLCR = 0x0040
  VMIN = 6
  VTIME = 5
  TCSAFLUSH = 2

# Low-level termios functions (required for terminal control)
when not defined(test):
  proc tcgetattr(fd: cint, termios_p: var Termios): cint {.importc, header: "<termios.h>".}
  proc tcsetattr(fd: cint, optional_actions: cint, termios_p: Termios): cint {.importc, header: "<termios.h>".}

export signals.SignalType

type
  TerminalError* = object of CatchableError
    ## Exception raised for terminal-related errors
  
  RawModeFlag* = enum
    ## Flags to customize raw mode behavior
    RawModeDisableOutput,     # Disable output processing
    RawModeNoSignalProcessing, # Disable signal processing (Ctrl+C, etc)
    RawModeNoFlowControl,     # Disable flow control (Ctrl+S, Ctrl+Q)
    RawModeDisableNewline,    # Disable CR to NL translation
    RawModeMinimalMode        # Minimal changes, just raw I/O

var
  originalTermios: Termios
  isRawMode = false
  isInitialized = false
  lastKnownSize: tuple[width: int, height: int] = (0, 0)
  registeredSignals = false

# Forward declaration
proc exitRawMode*(): bool

# シグナル処理関連
proc signalCallback(sigType: SignalType) =
  ## シグナル発生時のコールバック関数
  case sigType
  of SigWinch:
    # ウィンドウサイズ変更時、サイズを更新
    lastKnownSize = (terminalWidth(), terminalHeight())
  of SigInt, SigQuit:
    # Ctrl+Cなどは、input.nimでイベントとして処理するため、ここでは何もしない
    discard
  of SigTerm, SigHup:
    # 終了シグナルは、終了処理を行う
    if isRawMode:
      discard exitRawMode()

proc registerSignalHandlers() =
  ## 必要なシグナルハンドラを登録する
  if registeredSignals:
    return
    
  # シグナルコールバックを設定
  addSignalCallback(signalCallback)
  
  # シグナルハンドラを登録
  discard signals.registerSignalHandlers()
  
  registeredSignals = true

proc customizeRawMode(raw: var Termios, flags: set[RawModeFlag]) =
  ## rawモードの設定を細かくカスタマイズする
  
  # 基本設定
  # Input flags
  raw.c_iflag = raw.c_iflag and not Cflag(INPCK or ISTRIP)
  
  # Output flags
  if RawModeDisableOutput in flags:
    raw.c_oflag = raw.c_oflag and not Cflag(OPOST)
  
  # Control flags - set 8 bit chars
  raw.c_cflag = (raw.c_cflag and not Cflag(CSIZE or PARENB)) or CS8
  
  # Local flags - disable echoing, canonical mode
  raw.c_lflag = raw.c_lflag and not Cflag(ECHO or ICANON or IEXTEN)
  
  # 特定のフラグに基づいた追加設定
  if RawModeNoSignalProcessing in flags:
    # シグナル処理を無効化
    raw.c_lflag = raw.c_lflag and not Cflag(ISIG)
  
  if RawModeNoFlowControl in flags:
    # フロー制御を無効化
    raw.c_iflag = raw.c_iflag and not Cflag(IXON or IXOFF)
  
  if RawModeDisableNewline in flags:
    # CR to NL変換を無効化
    raw.c_iflag = raw.c_iflag and not Cflag(ICRNL or INLCR)
  
  if RawModeMinimalMode in flags:
    # 最小限の変更のみ
    raw.c_lflag = raw.c_lflag and not Cflag(ECHO or ICANON)
    # 他の設定はデフォルトのまま
  
  # Control chars - set return condition (min bytes, timeout)
  raw.c_cc[VMIN] = 0  # Return as soon as data is available
  raw.c_cc[VTIME] = 1 # Wait up to 1/10 second

proc enterRawMode*(flags: set[RawModeFlag] = {
    RawModeDisableOutput, 
    RawModeNoFlowControl, 
    RawModeDisableNewline
  }): bool {.discardable.} =
  ## 端末をrawモードに設定します。
  ## フラグを指定することで、rawモードの挙動をカスタマイズできます。
  ## 
  ## 戻り値:
  ## * true: 成功
  ## * false: 既にrawモードになっている場合
  if isRawMode:
    return false
  
  # シグナルハンドラを登録
  registerSignalHandlers()
  
  # 現在の端末設定を保存
  when defined(test):
    var testTermios = test_utils.Termios()
    if test_utils.tcgetattrTest(STDIN_FILENO, addr testTermios) < 0:
      raise newException(TerminalError, "Failed to get terminal attributes")
    # Copy to our Termios type
    originalTermios.c_iflag = testTermios.c_iflag
    originalTermios.c_oflag = testTermios.c_oflag
    originalTermios.c_cflag = testTermios.c_cflag
    originalTermios.c_lflag = testTermios.c_lflag
  else:
    discard tcgetattr(STDIN_FILENO, originalTermios)
  isInitialized = true
  
  # 新しい設定を作成
  var raw = originalTermios
  
  # カスタマイズ設定を適用
  customizeRawMode(raw, flags)
  
  # 設定を適用
  when defined(test):
    var testRaw = test_utils.Termios(
      c_iflag: raw.c_iflag,
      c_oflag: raw.c_oflag,
      c_cflag: raw.c_cflag,
      c_lflag: raw.c_lflag
    )
    if test_utils.tcsetattrTest(STDIN_FILENO, TCSAFLUSH, addr testRaw) < 0:
      raise newException(TerminalError, "Failed to set terminal to raw mode")
  else:
    if tcsetattr(STDIN_FILENO, TCSAFLUSH, raw) < 0:
      raise newException(TerminalError, "Failed to set terminal to raw mode")
  
  # 初期サイズを記録
  lastKnownSize = (terminalWidth(), terminalHeight())
  
  isRawMode = true
  return true

proc exitRawMode*(): bool {.discardable.} =
  ## 端末を元の状態に戻します。
  ##
  ## 戻り値:
  ## * true: 成功
  ## * false: 既に通常モードになっている場合
  if not isRawMode:
    return false
    
  if isInitialized:
    # 元の端末設定を復元
    when defined(test):
      var testOriginal = test_utils.Termios(
        c_iflag: originalTermios.c_iflag,
        c_oflag: originalTermios.c_oflag,
        c_cflag: originalTermios.c_cflag,
        c_lflag: originalTermios.c_lflag
      )
      discard test_utils.tcsetattrTest(STDIN_FILENO, TCSAFLUSH, addr testOriginal)
    else:
      discard tcsetattr(STDIN_FILENO, TCSAFLUSH, originalTermios)
    isRawMode = false
    return true
  
  return false

proc getTerminalSize*(): tuple[width: int, height: int] =
  ## 端末のサイズ（列数、行数）を取得します。
  ## 
  ## ウィンドウリサイズイベントが検出された場合はその値を返し、
  ## それ以外の場合は現在のサイズを計測して返します。
  if isRawMode and lastKnownSize.width > 0 and lastKnownSize.height > 0:
    # キャッシュされたサイズを返す（リサイズイベント検出後に更新される）
    return lastKnownSize
  else:
    # 現在のサイズを計測
    when defined(test):
      let size = test_utils.mockTerminalSize
    else:
      let size = (terminalWidth(), terminalHeight())
    lastKnownSize = size
    return size

proc forceTerminalSizeUpdate*() =
  ## 端末サイズの情報を強制的に更新します。
  ## リサイズイベントが検出されない場合などに使用します。
  when defined(test):
    lastKnownSize = test_utils.mockTerminalSize
  else:
    lastKnownSize = (terminalWidth(), terminalHeight())

proc isRawModeEnabled*(): bool =
  ## 端末が現在rawモードになっているかを確認します。
  return isRawMode

proc getLastSignalEvent*(): Option[SignalType] =
  ## 最後に発生したシグナルイベントを取得します。
  ## イベントがない場合はnoneを返します。
  return getSignalEvent()

# クリーンアップハンドラ
proc cleanup() {.noconv.} =
  if isRawMode:
    discard exitRawMode()
  
  # シグナルハンドラを元に戻す
  if registeredSignals:
    restoreSignalHandlers()
    
# クリーンアップハンドラを設定
import std/exitprocs
addExitProc(cleanup)