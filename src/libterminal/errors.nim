# errors.nim
## Enhanced error handling for production use
##
## Defines specific error types and recovery strategies for terminal operations

import std/[strformat, typetraits]

type
  # Base terminal exception
  LibTerminalError* = object of CatchableError
    ## Base exception for all libterminal errors
    component*: string
    errorCode*: TerminalErrorCode
    recoverable*: bool
    
  TerminalErrorCode* = enum
    ## Specific error codes for terminal operations
    TecUnknown = "UNKNOWN"
    TecRawModeFailure = "RAW_MODE_FAILURE"
    TecTerminalNotSupported = "TERMINAL_NOT_SUPPORTED"
    TecMouseNotSupported = "MOUSE_NOT_SUPPORTED"
    TecInvalidTerminalSize = "INVALID_TERMINAL_SIZE"
    TecSignalHandlingFailure = "SIGNAL_HANDLING_FAILURE"
    TecBufferOverflow = "BUFFER_OVERFLOW"
    TecInvalidInput = "INVALID_INPUT"
    TecResourceExhausted = "RESOURCE_EXHAUSTED"
    TecPermissionDenied = "PERMISSION_DENIED"
    TecConfigurationError = "CONFIGURATION_ERROR"
    
  # Specific exception types
  RawModeError* = object of LibTerminalError
    ## Thrown when raw mode operations fail
    
  MouseError* = object of LibTerminalError
    ## Thrown when mouse operations fail
    
  SizeError* = object of LibTerminalError
    ## Thrown when terminal size operations fail
    
  BufferError* = object of LibTerminalError
    ## Thrown when buffer operations fail
    
  ConfigurationError* = object of LibTerminalError
    ## Thrown when configuration is invalid

proc newLibTerminalError*(code: TerminalErrorCode, msg: string, 
                         component: string = "TERMINAL", 
                         recoverable: bool = true): ref LibTerminalError =
  ## Creates a new LibTerminalError with proper context
  result = newException(LibTerminalError, msg)
  result.component = component
  result.errorCode = code
  result.recoverable = recoverable

proc newRawModeError*(msg: string, recoverable: bool = true): ref RawModeError =
  ## Creates a RawModeError
  result = newException(RawModeError, msg)
  result.component = "RAW_MODE"
  result.errorCode = TecRawModeFailure
  result.recoverable = recoverable

proc newMouseError*(msg: string, recoverable: bool = true): ref MouseError =
  ## Creates a MouseError
  result = newException(MouseError, msg)
  result.component = "MOUSE"
  result.errorCode = TecMouseNotSupported
  result.recoverable = recoverable

proc newSizeError*(msg: string, recoverable: bool = false): ref SizeError =
  ## Creates a SizeError
  result = newException(SizeError, msg)
  result.component = "SIZE"
  result.errorCode = TecInvalidTerminalSize
  result.recoverable = recoverable

proc newBufferError*(msg: string, recoverable: bool = true): ref BufferError =
  ## Creates a BufferError
  result = newException(BufferError, msg)
  result.component = "BUFFER"
  result.errorCode = TecBufferOverflow
  result.recoverable = recoverable

proc newConfigurationError*(msg: string): ref ConfigurationError =
  ## Creates a ConfigurationError
  result = newException(ConfigurationError, msg)
  result.component = "CONFIG"
  result.errorCode = TecConfigurationError
  result.recoverable = false

# Result types for better error handling
type
  TerminalResult*[T] = object
    ## Result type that can hold either a value or an error
    case success*: bool
    of true:
      value*: T
    of false:
      error*: ref LibTerminalError

proc ok*[T](value: T): TerminalResult[T] =
  ## Creates a successful result
  TerminalResult[T](success: true, value: value)

proc err*[T](error: ref LibTerminalError): TerminalResult[T] =
  ## Creates an error result
  TerminalResult[T](success: false, error: error)

proc isOk*[T](res: TerminalResult[T]): bool =
  ## Checks if result is successful
  res.success

proc isErr*[T](res: TerminalResult[T]): bool =
  ## Checks if result is an error
  not res.success

proc get*[T](res: TerminalResult[T]): T =
  ## Gets the value from a successful result, raises exception if error
  if res.success:
    return res.value
  else:
    raise res.error

proc getOr*[T](res: TerminalResult[T], default: T): T =
  ## Gets the value or returns default if error
  if res.success:
    return res.value
  else:
    return default

# Error recovery strategies
type
  ErrorRecoveryStrategy* = enum
    ## Strategies for recovering from errors
    ErsIgnore,           # Ignore the error and continue
    ErsRetry,            # Retry the operation
    ErsFailsafe,         # Use a safe fallback
    ErsAbort             # Abort the operation

proc getRecoveryStrategy*(error: ref LibTerminalError): ErrorRecoveryStrategy =
  ## Determines the best recovery strategy for an error
  if not error.recoverable:
    return ErsAbort
    
  case error.errorCode
  of TecRawModeFailure:
    ErsRetry
  of TecMouseNotSupported:
    ErsFailsafe
  of TecInvalidTerminalSize:
    ErsFailsafe
  of TecSignalHandlingFailure:
    ErsFailsafe
  of TecBufferOverflow:
    ErsRetry
  of TecPermissionDenied:
    ErsAbort
  of TecConfigurationError:
    ErsAbort
  else:
    ErsIgnore

# Safe operation wrapper
template withErrorHandling*(body: untyped): untyped =
  ## Template for safe execution with automatic error handling
  try:
    body
  except LibTerminalError as e:
    when compiles(logError):
      logError(fmt"Error in {e.component}: {e.msg} (Code: {e.errorCode})")
    let strategy = getRecoveryStrategy(e)
    case strategy
    of ErsIgnore:
      discard
    of ErsAbort:
      raise e
    else:
      raise e  # For now, just re-raise. Could implement retry logic here.

# Validation helpers
proc validateTerminalSize*(width, height: int): TerminalResult[tuple[width: int, height: int]] =
  ## Validates terminal size values
  if width <= 0 or height <= 0:
    return err[tuple[width: int, height: int]](
      newSizeError(fmt"Invalid terminal size: {width}x{height}. Both dimensions must be positive.")
    )
  
  if width > 10000 or height > 10000:
    return err[tuple[width: int, height: int]](
      newSizeError(fmt"Terminal size too large: {width}x{height}. Maximum supported is 10000x10000.")
    )
  
  return ok((width: width, height: height))

proc validateBufferBounds*(x, y, width, height: int): TerminalResult[bool] =
  ## Validates buffer coordinates
  if x < 0 or y < 0:
    return err[bool](
      newBufferError(fmt"Negative coordinates not allowed: ({x}, {y})")
    )
  
  if x >= width or y >= height:
    return err[bool](
      newBufferError(fmt"Coordinates out of bounds: ({x}, {y}) for size {width}x{height}")
    )
  
  return ok(true)