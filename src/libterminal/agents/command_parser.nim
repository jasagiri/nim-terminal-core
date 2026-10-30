## Command Parser for Agent Integration
## 
## Parses and routes agent commands in terminal applications

import std/[strutils, tables, sequtils, asyncdispatch]
# import std/options   # Reserved for future use
# import std/re        # Reserved for future use
# import agent_base    # Reserved for future use

type
  CommandType* = enum
    ## Types of agent commands
    ctAgent      ## Direct agent invocation (/agent help)
    ctLlm        ## LLM conversation (/llm what is...)
    ctTool       ## Tool execution (/tool execute ls)
    ctConfig     ## Configuration (/config set api_key)
    ctHelp       ## Help system (/help agents)
    ctUnknown    ## Unknown command

  ParsedCommand* = object
    ## A parsed agent command
    commandType*: CommandType
    command*: string
    subcommand*: string
    arguments*: seq[string]
    options*: Table[string, string]
    rawInput*: string

  CommandHandler* = proc(cmd: ParsedCommand): Future[string] {.async.}

  CommandParser* = ref object
    ## Command parser for agent functionality
    prefix*: string
    handlers*: Table[CommandType, CommandHandler]
    aliases*: Table[string, string]

proc newCommandParser*(prefix: string = "/agent"): CommandParser =
  ## Creates a new command parser
  result = CommandParser(
    prefix: prefix,
    handlers: initTable[CommandType, CommandHandler](),
    aliases: initTable[string, string]()
  )
  
  # Set up default aliases
  result.aliases["ai"] = "llm"
  result.aliases["chat"] = "llm"
  result.aliases["ask"] = "llm"
  result.aliases["run"] = "tool"
  result.aliases["exec"] = "tool"
  result.aliases["help"] = "help"
  result.aliases["?"] = "help"

proc isAgentCommand*(parser: CommandParser, input: string): bool =
  ## Checks if input is an agent command
  return input.strip().startsWith(parser.prefix)

proc parseCommand*(parser: CommandParser, input: string): ParsedCommand =
  ## Parses an agent command
  result = ParsedCommand(
    commandType: ctUnknown,
    rawInput: input
  )
  
  let trimmed = input.strip()
  if not trimmed.startsWith(parser.prefix):
    return result
  
  # Remove prefix
  let withoutPrefix = trimmed[parser.prefix.len..^1].strip()
  if withoutPrefix.len == 0:
    result.commandType = ctHelp
    return result
  
  # Split into parts
  let parts = withoutPrefix.split(Whitespace).filterIt(it.len > 0)
  if parts.len == 0:
    result.commandType = ctHelp
    return result
  
  # Get command and resolve aliases
  var command = parts[0].toLowerAscii()
  if command in parser.aliases:
    command = parser.aliases[command]
  
  result.command = command
  
  # Determine command type
  case command:
  of "agent":
    result.commandType = ctAgent
  of "llm", "ai", "chat", "ask":
    result.commandType = ctLlm
  of "tool", "run", "exec":
    result.commandType = ctTool
  of "config", "set", "get":
    result.commandType = ctConfig
  of "help", "?":
    result.commandType = ctHelp
  else:
    result.commandType = ctUnknown
  
  # Parse subcommand and arguments
  if parts.len > 1:
    result.subcommand = parts[1]
    
    # Parse arguments and options
    var i = 2
    while i < parts.len:
      let part = parts[i]
      if part.startsWith("--"):
        # Long option
        let optionParts = part[2..^1].split("=", 1)
        if optionParts.len == 2:
          result.options[optionParts[0]] = optionParts[1]
        else:
          result.options[optionParts[0]] = ""
      elif part.startsWith("-"):
        # Short option
        let option = part[1..^1]
        if i + 1 < parts.len and not parts[i + 1].startsWith("-"):
          result.options[option] = parts[i + 1]
          inc i
        else:
          result.options[option] = ""
      else:
        # Regular argument
        result.arguments.add(part)
      inc i

proc registerHandler*(parser: CommandParser, commandType: CommandType, handler: CommandHandler) =
  ## Registers a command handler
  parser.handlers[commandType] = handler

proc addAlias*(parser: CommandParser, alias: string, command: string) =
  ## Adds a command alias
  parser.aliases[alias] = command

proc removeAlias*(parser: CommandParser, alias: string) =
  ## Removes a command alias
  parser.aliases.del(alias)

proc processCommand*(parser: CommandParser, input: string): Future[string] {.async.} =
  ## Processes an agent command
  if not parser.isAgentCommand(input):
    return "Not an agent command"
  
  let parsed = parser.parseCommand(input)
  
  if parsed.commandType in parser.handlers:
    try:
      result = await parser.handlers[parsed.commandType](parsed)
    except Exception as e:
      result = "Error processing command: " & e.msg
  else:
    result = "Unknown command: " & parsed.command

proc getHelpText*(parser: CommandParser): string =
  ## Returns help text for agent commands
  result = "Agent Commands:\n\n"
  result.add("Usage: " & parser.prefix & " <command> [options] [arguments]\n\n")
  result.add("Commands:\n")
  result.add("  agent <subcommand>     - Agent management\n")
  result.add("  llm <message>          - Chat with LLM (aliases: ai, chat, ask)\n")
  result.add("  tool <name> [args]     - Execute tools (aliases: run, exec)\n")
  result.add("  config <key> [value]   - Configuration\n")
  result.add("  help                   - Show this help (alias: ?)\n\n")
  result.add("Examples:\n")
  result.add("  " & parser.prefix & " llm explain this code\n")
  result.add("  " & parser.prefix & " tool execute ls -la\n")
  result.add("  " & parser.prefix & " config set api_key sk-...\n")
  result.add("  " & parser.prefix & " help\n")

proc formatCommandOutput*(command: string, output: string, success: bool = true): string =
  ## Formats command output for display
  let status = if success: "✓" else: "✗"
  result = $"[{status}] {command}\n{output}"

proc extractQuotedString*(text: string): string =
  ## Extracts content from quoted strings
  if text.len >= 2:
    if (text[0] == '"' and text[^1] == '"') or (text[0] == '\'' and text[^1] == '\''):
      return text[1..^2]
  return text

proc joinArguments*(args: seq[string], startIdx: int = 0): string =
  ## Joins arguments into a single string
  if startIdx >= args.len:
    return ""
  return args[startIdx..^1].join(" ")

proc parseKeyValue*(text: string): tuple[key: string, value: string] =
  ## Parses key=value pairs
  let parts = text.split("=", 1)
  if parts.len == 2:
    result = (key: parts[0].strip(), value: parts[1].strip())
  else:
    result = (key: parts[0].strip(), value: "")

proc validateCommandSyntax*(parser: CommandParser, input: string): tuple[valid: bool, error: string] =
  ## Validates command syntax
  if not parser.isAgentCommand(input):
    return (false, "Not an agent command")
  
  let parsed = parser.parseCommand(input)
  
  case parsed.commandType:
  of ctUnknown:
    return (false, "Unknown command: " & parsed.command)
  of ctLlm:
    if parsed.arguments.len == 0 and parsed.subcommand.len == 0:
      return (false, "LLM command requires a message")
  of ctTool:
    if parsed.subcommand.len == 0:
      return (false, "Tool command requires a tool name")
  of ctConfig:
    if parsed.subcommand.len == 0:
      return (false, "Config command requires a key")
  else:
    discard
  
  return (true, "")