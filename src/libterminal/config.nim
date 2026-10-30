# config.nim
## Configuration management for libterminal
##
## Provides centralized configuration with validation and defaults

import std/[tables, strutils, os, parseutils, strformat, logging]

type
  ConfigurationError* = object of CatchableError

type
  TerminalConfig* = ref object
    ## Main configuration object for the terminal library
    # Core settings
    enableLogging*: bool
    logLevel*: string
    logFile*: string
    
    # Terminal behavior
    rawModeFlags*: set[RawModeFlag]
    mouseSupport*: bool
    unicodeSupport*: bool
    colorSupport*: ColorSupportLevel
    
    # Performance settings
    bufferSize*: int
    maxBufferHistory*: int
    enableDifferentialUpdates*: bool
    refreshRate*: int  # Hz
    
    # Error handling
    retryAttempts*: int
    retryDelay*: int  # milliseconds
    enableRecovery*: bool
    
    # Feature flags
    enableAgents*: bool
    enableMetrics*: bool
    enableNineP*: bool
    
  ColorSupportLevel* = enum
    ## Color support levels
    CslNone = "none"
    CslBasic = "basic"        # 8 colors
    Csl256 = "256"            # 256 colors
    CslTrueColor = "truecolor" # 16.7M colors
    
  RawModeFlag* = enum
    ## Flags to customize raw mode behavior (redefined here for config)
    RmfDisableOutput,
    RmfNoSignalProcessing,
    RmfNoFlowControl,
    RmfDisableNewline,
    RmfMinimalMode

# Default configuration values (as template)
proc getDefaultConfig(): TerminalConfig =
  TerminalConfig(
    enableLogging: false,
    logLevel: "INFO",
    logFile: "",
    
    rawModeFlags: {},
    mouseSupport: true,
    unicodeSupport: true,
    colorSupport: CslTrueColor,
    
    bufferSize: 8192,
    maxBufferHistory: 1000,
    enableDifferentialUpdates: true,
    refreshRate: 60,
    
    retryAttempts: 3,
    retryDelay: 100,
    enableRecovery: true,
    
    enableAgents: false,
    enableMetrics: false,
    enableNineP: false
  )

var globalConfig*: TerminalConfig

proc newTerminalConfig*(): TerminalConfig =
  ## Creates a new configuration with default values
  getDefaultConfig()

proc initConfig*(): TerminalConfig =
  ## Initializes global configuration
  globalConfig = newTerminalConfig()
  return globalConfig

proc getConfig*(): TerminalConfig =
  ## Gets the global configuration, initializing if necessary
  if globalConfig.isNil:
    globalConfig = initConfig()
  return globalConfig

# Configuration loading and validation
proc parseColorSupport(value: string): ColorSupportLevel =
  ## Parses color support level from string
  case value.toLowerAscii()
  of "none", "0": CslNone
  of "basic", "8": CslBasic
  of "256": Csl256
  of "truecolor", "true", "16m": CslTrueColor
  else: CslTrueColor

proc parseRawModeFlags(value: string): set[RawModeFlag] =
  ## Parses raw mode flags from comma-separated string
  result = {}
  for flag in value.split(','):
    case flag.strip().toLowerAscii()
    of "disable_output": result.incl(RmfDisableOutput)
    of "no_signal": result.incl(RmfNoSignalProcessing)
    of "no_flow": result.incl(RmfNoFlowControl)
    of "no_newline": result.incl(RmfDisableNewline)
    of "minimal": result.incl(RmfMinimalMode)
    else: discard

proc validateConfig(config: TerminalConfig): bool =
  ## Validates configuration values
  # Validate buffer size
  if config.bufferSize < 1024 or config.bufferSize > 1024 * 1024:
    raise newException(ConfigurationError, fmt"Invalid buffer size: {config.bufferSize}. Must be between 1024 and 1048576.")
  
  # Validate refresh rate
  if config.refreshRate < 1 or config.refreshRate > 240:
    raise newException(ConfigurationError, fmt"Invalid refresh rate: {config.refreshRate}. Must be between 1 and 240 Hz.")
  
  # Validate retry settings
  if config.retryAttempts < 0 or config.retryAttempts > 10:
    raise newException(ConfigurationError, fmt"Invalid retry attempts: {config.retryAttempts}. Must be between 0 and 10.")
  
  if config.retryDelay < 0 or config.retryDelay > 5000:
    raise newException(ConfigurationError, fmt"Invalid retry delay: {config.retryDelay}. Must be between 0 and 5000ms.")
  
  # Validate log level
  if config.logLevel notin ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]:
    raise newException(ConfigurationError, fmt"Invalid log level: {config.logLevel}. Must be one of: DEBUG, INFO, WARN, ERROR, FATAL.")
  
  return true

proc loadFromEnv*(config: TerminalConfig) =
  ## Loads configuration from environment variables
  # Core settings
  if existsEnv("LIBTERMINAL_ENABLE_LOGGING"):
    config.enableLogging = parseBool(getEnv("LIBTERMINAL_ENABLE_LOGGING", "false"))
  
  if existsEnv("LIBTERMINAL_LOG_LEVEL"):
    config.logLevel = getEnv("LIBTERMINAL_LOG_LEVEL")
  
  if existsEnv("LIBTERMINAL_LOG_FILE"):
    config.logFile = getEnv("LIBTERMINAL_LOG_FILE")
  
  # Terminal behavior
  if existsEnv("LIBTERMINAL_MOUSE_SUPPORT"):
    config.mouseSupport = parseBool(getEnv("LIBTERMINAL_MOUSE_SUPPORT", "true"))
  
  if existsEnv("LIBTERMINAL_UNICODE_SUPPORT"):
    config.unicodeSupport = parseBool(getEnv("LIBTERMINAL_UNICODE_SUPPORT", "true"))
  
  if existsEnv("LIBTERMINAL_COLOR_SUPPORT"):
    config.colorSupport = parseColorSupport(getEnv("LIBTERMINAL_COLOR_SUPPORT"))
  
  if existsEnv("LIBTERMINAL_RAW_MODE_FLAGS"):
    config.rawModeFlags = parseRawModeFlags(getEnv("LIBTERMINAL_RAW_MODE_FLAGS"))
  
  # Performance settings
  if existsEnv("LIBTERMINAL_BUFFER_SIZE"):
    discard parseInt(getEnv("LIBTERMINAL_BUFFER_SIZE"), config.bufferSize)
  
  if existsEnv("LIBTERMINAL_REFRESH_RATE"):
    discard parseInt(getEnv("LIBTERMINAL_REFRESH_RATE"), config.refreshRate)
  
  if existsEnv("LIBTERMINAL_ENABLE_DIFF_UPDATES"):
    config.enableDifferentialUpdates = parseBool(getEnv("LIBTERMINAL_ENABLE_DIFF_UPDATES", "true"))
  
  # Error handling
  if existsEnv("LIBTERMINAL_RETRY_ATTEMPTS"):
    discard parseInt(getEnv("LIBTERMINAL_RETRY_ATTEMPTS"), config.retryAttempts)
  
  if existsEnv("LIBTERMINAL_RETRY_DELAY"):
    discard parseInt(getEnv("LIBTERMINAL_RETRY_DELAY"), config.retryDelay)
  
  if existsEnv("LIBTERMINAL_ENABLE_RECOVERY"):
    config.enableRecovery = parseBool(getEnv("LIBTERMINAL_ENABLE_RECOVERY", "true"))
  
  # Feature flags
  if existsEnv("LIBTERMINAL_ENABLE_AGENTS"):
    config.enableAgents = parseBool(getEnv("LIBTERMINAL_ENABLE_AGENTS", "false"))
  
  if existsEnv("LIBTERMINAL_ENABLE_METRICS"):
    config.enableMetrics = parseBool(getEnv("LIBTERMINAL_ENABLE_METRICS", "false"))
  
  if existsEnv("LIBTERMINAL_ENABLE_NINEP"):
    config.enableNineP = parseBool(getEnv("LIBTERMINAL_ENABLE_NINEP", "false"))

proc loadFromFile*(config: TerminalConfig, filename: string): bool =
  ## Loads configuration from a file (simple key=value format)
  if not fileExists(filename):
    raise newException(ConfigurationError, fmt"Configuration file not found: {filename}")
  
  try:
    let content = readFile(filename)
    for line in content.splitLines():
      let trimmed = line.strip()
      if trimmed.len == 0 or trimmed.startsWith('#'):
        continue
      
      let parts = trimmed.split('=', 1)
      if parts.len != 2:
        continue
      
      let key = parts[0].strip()
      let value = parts[1].strip()
      
      case key.toLowerAscii()
      of "enable_logging":
        config.enableLogging = parseBool(value)
      of "log_level":
        config.logLevel = value
      of "log_file":
        config.logFile = value
      of "mouse_support":
        config.mouseSupport = parseBool(value)
      of "unicode_support":
        config.unicodeSupport = parseBool(value)
      of "color_support":
        config.colorSupport = parseColorSupport(value)
      of "raw_mode_flags":
        config.rawModeFlags = parseRawModeFlags(value)
      of "buffer_size":
        discard parseInt(value, config.bufferSize)
      of "refresh_rate":
        discard parseInt(value, config.refreshRate)
      of "enable_diff_updates":
        config.enableDifferentialUpdates = parseBool(value)
      of "retry_attempts":
        discard parseInt(value, config.retryAttempts)
      of "retry_delay":
        discard parseInt(value, config.retryDelay)
      of "enable_recovery":
        config.enableRecovery = parseBool(value)
      of "enable_agents":
        config.enableAgents = parseBool(value)
      of "enable_metrics":
        config.enableMetrics = parseBool(value)
      of "enable_ninep":
        config.enableNineP = parseBool(value)
      else:
        discard  # Unknown keys are ignored
    
    return true
  except:
    raise newException(ConfigurationError, fmt"Failed to read configuration file: {filename}")

proc applyConfig*(config: TerminalConfig): bool =
  ## Applies and validates the configuration
  try:
    discard validateConfig(config)
  except ConfigurationError:
    return false
  
  # Apply configuration to various subsystems
  when compiles(initTerminalLogging):
    if config.enableLogging:
      let logLevel = case config.logLevel
        of "DEBUG": lvlDebug
        of "INFO": lvlInfo
        of "WARN": lvlWarn
        of "ERROR": lvlError
        of "FATAL": lvlFatal
        else: lvlInfo
      
      discard initTerminalLogging(logLevel, config.logFile)
  
  return true

# Convenience functions
proc setLogLevel*(level: string) =
  ## Sets the global log level
  let config = getConfig()
  config.logLevel = level
  discard applyConfig(config)

proc enableFeature*(feature: string, enabled: bool = true) =
  ## Enables or disables a feature
  let config = getConfig()
  case feature.toLowerAscii()
  of "logging":
    config.enableLogging = enabled
  of "mouse":
    config.mouseSupport = enabled
  of "unicode":
    config.unicodeSupport = enabled
  of "agents":
    config.enableAgents = enabled
  of "metrics":
    config.enableMetrics = enabled
  of "ninep":
    config.enableNineP = enabled
  of "recovery":
    config.enableRecovery = enabled
  of "diff_updates":
    config.enableDifferentialUpdates = enabled
  else:
    discard
  discard applyConfig(config)

proc isFeatureEnabled*(feature: string): bool =
  ## Checks if a feature is enabled
  let config = getConfig()
  case feature.toLowerAscii()
  of "logging":
    config.enableLogging
  of "mouse":
    config.mouseSupport
  of "unicode":
    config.unicodeSupport
  of "agents":
    config.enableAgents
  of "metrics":
    config.enableMetrics
  of "ninep":
    config.enableNineP
  of "recovery":
    config.enableRecovery
  of "diff_updates":
    config.enableDifferentialUpdates
  else:
    false