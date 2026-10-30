# logging.nim
## Production logging module for libterminal
##
## Provides structured logging with appropriate levels for production use

import std/[logging, strformat, times, os]

type
  LibTerminalLogger* = ref object
    logger: Logger
    level: Level
    
  TerminalLogLevel* = enum
    ## Log levels specifically for terminal operations
    TllDebug = "DEBUG"
    TllInfo = "INFO"
    TllWarn = "WARN"
    TllError = "ERROR"
    TllFatal = "FATAL"

var globalLogger*: LibTerminalLogger

proc newLibTerminalLogger*(level: Level = lvlInfo, filename: string = ""): LibTerminalLogger =
  ## Creates a new logger instance for terminal operations
  result = LibTerminalLogger(level: level)
  
  if filename.len > 0:
    let logDir = parentDir(filename)
    if not dirExists(logDir):
      createDir(logDir)
    result.logger = newFileLogger(filename, levelThreshold = level)
  else:
    result.logger = newConsoleLogger(levelThreshold = level)

proc initTerminalLogging*(level: Level = lvlInfo, logFile: string = ""): LibTerminalLogger =
  ## Initializes global logging for the terminal library
  globalLogger = newLibTerminalLogger(level, logFile)
  return globalLogger

proc logTerminal*(level: TerminalLogLevel, msg: string, component: string = "TERMINAL") =
  ## Main logging function for terminal operations
  if globalLogger.isNil:
    globalLogger = initTerminalLogging()
  
  let timestamp = now().format("yyyy-MM-dd HH:mm:ss")
  let logMsg = fmt"[{timestamp}] [{component}] {msg}"
  
  case level
  of TllDebug:
    globalLogger.logger.log(lvlDebug, logMsg)
  of TllInfo:
    globalLogger.logger.log(lvlInfo, logMsg)
  of TllWarn:
    globalLogger.logger.log(lvlWarn, logMsg)
  of TllError:
    globalLogger.logger.log(lvlError, logMsg)
  of TllFatal:
    globalLogger.logger.log(lvlFatal, logMsg)

# Convenience functions
proc logDebug*(msg: string, component: string = "TERMINAL") =
  logTerminal(TllDebug, msg, component)

proc logInfo*(msg: string, component: string = "TERMINAL") =
  logTerminal(TllInfo, msg, component)

proc logWarn*(msg: string, component: string = "TERMINAL") =
  logTerminal(TllWarn, msg, component)

proc logError*(msg: string, component: string = "TERMINAL") =
  logTerminal(TllError, msg, component)

proc logFatal*(msg: string, component: string = "TERMINAL") =
  logTerminal(TllFatal, msg, component)

# Special terminal operation logging
proc logRawModeChange*(entering: bool, success: bool) =
  let action = if entering: "ENTER" else: "EXIT"
  let status = if success: "SUCCESS" else: "FAILED"
  logInfo(fmt"Raw mode {action}: {status}", "RAW_MODE")

proc logMouseEvent*(enabled: bool, success: bool) =
  let action = if enabled: "ENABLE" else: "DISABLE"
  let status = if success: "SUCCESS" else: "FAILED"
  logInfo(fmt"Mouse {action}: {status}", "MOUSE")

proc logTerminalSize*(width, height: int) =
  logDebug(fmt"Terminal size: {width}x{height}", "SIZE")

proc logSignalReceived*(signalName: string) =
  logInfo(fmt"Signal received: {signalName}", "SIGNAL")

proc logPerformanceMetric*(operation: string, duration: float) =
  logDebug(fmt"Performance - {operation}: {duration:.3f}ms", "PERF")