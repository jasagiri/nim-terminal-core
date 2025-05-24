# signals.nim
## シグナル処理のための内部モジュール
##
## このモジュールはシグナルのハンドリングを担当し、
## イベントとして変換して処理できるようにします。

import std/posix
import std/tables
import std/options

import common

# シグナルの種類を表す列挙型
type
  SignalType* = enum
    SigInt,    # SIGINT (Ctrl+C)
    SigWinch,  # SIGWINCH (ウィンドウサイズ変更)
    SigTerm,   # SIGTERM (終了要求)
    SigQuit,   # SIGQUIT (Ctrl+\)
    SigHup     # SIGHUP (端末切断)
    
  SignalHandler = proc (sig: cint) {.noconv.}

# シグナルイベント通知用の型
type 
  SignalCallback* = proc(sigType: SignalType) {.closure.}

var 
  signalCallbacks: seq[SignalCallback] = @[]
  signalEvents: seq[SignalType] = @[]
  signalLock: bool = false

# 元のシグナルハンドラを保存
var origSigIntHandler: SignalHandler
var origSigWinchHandler: SignalHandler
var origSigTermHandler: SignalHandler
var origSigQuitHandler: SignalHandler
var origSigHupHandler: SignalHandler

# シグナルを SignalType に変換
proc toSignalType(sig: cint): Option[SignalType] =
  # Hardcoded signal numbers for common platforms
  let sigInt = 2.cint    # SIGINT is typically 2
  let sigWinch = 28.cint # SIGWINCH is typically 28
  let sigTerm = 15.cint  # SIGTERM is typically 15
  let sigQuit = 3.cint   # SIGQUIT is typically 3
  let sigHup = 1.cint    # SIGHUP is typically 1
  
  if sig == sigInt:
    return some(SigInt)
  elif sig == sigWinch:
    return some(SigWinch)
  elif sig == sigTerm:
    return some(SigTerm)
  elif sig == sigQuit:
    return some(SigQuit)
  elif sig == sigHup:
    return some(SigHup)
  else:
    return none(SignalType)

# SIGINT ハンドラ
proc sigIntHandler(sig: cint) {.noconv.} =
  let sigType = toSignalType(sig)
  if sigType.isSome and not signalLock:
    signalLock = true
    signalEvents.add(sigType.get)
    for callback in signalCallbacks:
      try:
        callback(sigType.get)
      except:
        discard
    signalLock = false

# SIGWINCH ハンドラ
proc sigWinchHandler(sig: cint) {.noconv.} =
  let sigType = toSignalType(sig)
  if sigType.isSome and not signalLock:
    signalLock = true
    signalEvents.add(sigType.get)
    for callback in signalCallbacks:
      try:
        callback(sigType.get)
      except:
        discard
    signalLock = false

# SIGTERM ハンドラ
proc sigTermHandler(sig: cint) {.noconv.} =
  let sigType = toSignalType(sig)
  if sigType.isSome and not signalLock:
    signalLock = true
    signalEvents.add(sigType.get)
    for callback in signalCallbacks:
      try:
        callback(sigType.get)
      except:
        discard
    signalLock = false

# SIGQUIT ハンドラ
proc sigQuitHandler(sig: cint) {.noconv.} =
  let sigType = toSignalType(sig)
  if sigType.isSome and not signalLock:
    signalLock = true
    signalEvents.add(sigType.get)
    for callback in signalCallbacks:
      try:
        callback(sigType.get)
      except:
        discard
    signalLock = false

# SIGHUP ハンドラ
proc sigHupHandler(sig: cint) {.noconv.} =
  let sigType = toSignalType(sig)
  if sigType.isSome and not signalLock:
    signalLock = true
    signalEvents.add(sigType.get)
    for callback in signalCallbacks:
      try:
        callback(sigType.get)
      except:
        discard
    signalLock = false

proc registerSignalHandlers*(): bool =
  ## 全シグナルハンドラを登録
  # シンプルな実装に置き換え（型の問題を回避）
  var sa: Sigaction
  
  # SIGINT
  sa.sa_handler = sigIntHandler
  sa.sa_flags = 0
  discard sigemptyset(sa.sa_mask)
  
  # Hardcoded signal numbers for common platforms
  let sigInt = 2.cint    # SIGINT is typically 2
  let sigWinch = 28.cint # SIGWINCH is typically 28
  let sigTerm = 15.cint  # SIGTERM is typically 15
  let sigQuit = 3.cint   # SIGQUIT is typically 3
  let sigHup = 1.cint    # SIGHUP is typically 1
  
  discard sigaction(sigInt, sa, nil)
  
  # SIGWINCH
  sa.sa_handler = sigWinchHandler
  discard sigaction(sigWinch, sa, nil)
  
  # SIGTERM
  sa.sa_handler = sigTermHandler
  discard sigaction(sigTerm, sa, nil)
  
  # SIGQUIT
  sa.sa_handler = sigQuitHandler
  discard sigaction(sigQuit, sa, nil)
  
  # SIGHUP
  sa.sa_handler = sigHupHandler
  discard sigaction(sigHup, sa, nil)
  
  return true

proc restoreSignalHandlers*() =
  ## 全シグナルハンドラを元に戻す
  ## 
  ## シンプルな実装に置き換え（型の問題を回避）
  var sa: Sigaction
  
  # デフォルトのシグナルハンドラを設定
  sa.sa_flags = 0
  discard sigemptyset(sa.sa_mask)
  
  # デフォルトハンドラに戻す
  sa.sa_handler = SIG_DFL
  
  # Hardcoded signal numbers for common platforms
  let sigInt = 2.cint    # SIGINT is typically 2
  let sigWinch = 28.cint # SIGWINCH is typically 28
  let sigTerm = 15.cint  # SIGTERM is typically 15
  let sigQuit = 3.cint   # SIGQUIT is typically 3
  let sigHup = 1.cint    # SIGHUP is typically 1
  
  discard sigaction(sigInt, sa, nil)
  discard sigaction(sigWinch, sa, nil)
  discard sigaction(sigTerm, sa, nil)
  discard sigaction(sigQuit, sa, nil)
  discard sigaction(sigHup, sa, nil)

proc addSignalCallback*(callback: SignalCallback) =
  ## シグナル発生時に呼び出されるコールバックを追加します
  signalCallbacks.add(callback)

proc removeSignalCallback*(callback: SignalCallback) =
  ## 登録されたコールバックを削除します
  let idx = signalCallbacks.find(callback)
  if idx >= 0:
    signalCallbacks.delete(idx)

proc getSignalEvent*(): Option[SignalType] =
  ## シグナルイベントキューから次のシグナルイベントを取得します
  ##
  ## シグナルイベントがない場合はnoneを返します
  if signalEvents.len > 0:
    result = some(signalEvents[0])
    signalEvents.delete(0)
  else:
    result = none(SignalType)

proc clearSignalEvents*() =
  ## シグナルイベントキューをクリアします
  signalEvents.setLen(0)

proc setSignalFlag*(sigType: SignalType) =
  ## テスト用: シグナルイベントをキューに追加します
  signalEvents.add(sigType)

# シャットダウン時にすべてのハンドラを復元
import std/exitprocs
addExitProc(proc() {.noconv.} =
  restoreSignalHandlers()
)