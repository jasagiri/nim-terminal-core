# test_signals.nim
## Signal handling related tests

import unittest
import std/options
import ../src/libterminal
import ../src/libterminal/private/signals

suite "Signal handling":
  test "Signal handler registration and restoration":
    # Register signal handlers
    check(registerSignalHandlers())
    
    # Restore handlers
    restoreSignalHandlers()
  
  test "Signal callbacks":
    var callbackCalled = false
    var receivedSignal: SignalType
    
    # Test callback
    proc testCallback(sigType: SignalType) =
      callbackCalled = true
      receivedSignal = sigType
    
    # Register callback
    addSignalCallback(testCallback)
    
    # Remove callback
    removeSignalCallback(testCallback)
    
    # Clear signal events
    clearSignalEvents()
    
    # Verify signal events are empty
    check(getSignalEvent().isNone)
  
  test "Multiple signal callbacks":
    var callback1Called = false
    var callback2Called = false
    
    proc callback1(sigType: SignalType) =
      callback1Called = true
    
    proc callback2(sigType: SignalType) =
      callback2Called = true
    
    # Register multiple callbacks
    addSignalCallback(callback1)
    addSignalCallback(callback2)
    
    # Remove callbacks
    removeSignalCallback(callback1)
    removeSignalCallback(callback2)
    
    # Clear events
    clearSignalEvents()
  
  test "Signal event queue":
    # Clear any existing events
    clearSignalEvents()
    
    # Initially empty
    check(getSignalEvent().isNone)
    
    # Cannot test actual signal generation without sending real signals
    # which would interfere with the test runner
  
  test "Signal type enumeration":
    # Test that signal types are defined as SignalType enum
    let sigInt: SignalType = SigInt
    let sigWinch: SignalType = SigWinch
    let sigTerm: SignalType = SigTerm
    let sigQuit: SignalType = SigQuit
    let sigHup: SignalType = SigHup
    
    # Check they exist
    check(sigInt == SigInt)
    check(sigWinch == SigWinch)
    check(sigTerm == SigTerm)
    check(sigQuit == SigQuit)
    check(sigHup == SigHup)

when isMainModule:
  # Run tests
  discard