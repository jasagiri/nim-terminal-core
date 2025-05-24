# libterminal.nim
## A pure Nim terminal manipulation library
## 
## This library provides functionality for terminal manipulation, 
## including raw mode handling, input/output processing, and UI components.

import libterminal/raw
import libterminal/input
import libterminal/output
import libterminal/mouse
import libterminal/layout
import libterminal/widgets
import libterminal/shortcuts
import libterminal/databinding
import libterminal/private/unicode_utils
when not defined(noAgents):
  import libterminal/agents

export raw
export input
export output
export mouse.MouseMode, mouse.MouseEventMask
export layout
export widgets
export shortcuts
export databinding
when not defined(noAgents):
  export agents

# Export essential Unicode functionality
export unicode_utils.TextDirection, unicode_utils.LineWrapMode
export unicode_utils.getTextDirection, unicode_utils.displayWidth
export unicode_utils.splitLines, unicode_utils.isWordBoundary
export unicode_utils.graphemeLength, unicode_utils.splitIntoGraphemeClusters
export unicode_utils.visualPosToLogical, unicode_utils.logicalPosToVisual

const
  Version* = "0.1.0"   ## Library version

type
  Terminal* = object
    ## Main terminal object that encapsulates the terminal state
    rawMode: bool
    mouseEnabled: bool
    width: int
    height: int
    when not defined(noAgents):
      agentConfig: AgentConfig
      agentRegistry: AgentRegistry

proc newTerminal*(): Terminal =
  ## Creates a new Terminal object
  result = Terminal(
    rawMode: false,
    mouseEnabled: false,
    width: 0,
    height: 0
  )
  when not defined(noAgents):
    result.agentConfig = newAgentConfig()
    result.agentRegistry = newAgentRegistry()

proc init*(term: var Terminal) =
  ## Initializes the terminal in raw mode
  if not term.rawMode:
    term.rawMode = true
    raw.enterRawMode()
    # Initialize terminal size
    (term.width, term.height) = raw.getTerminalSize()

proc init*(term: var Terminal, enableMouse: bool) =
  ## Initializes the terminal in raw mode with optional mouse support
  term.init()
  if enableMouse:
    term.mouseEnabled = input.enableMouse()

proc shutdown*(term: var Terminal) =
  ## Restores the terminal to its original state
  if term.mouseEnabled:
    input.disableMouse()
    term.mouseEnabled = false
  
  if term.rawMode:
    term.rawMode = false
    discard raw.exitRawMode()

proc enableMouse*(term: var Terminal): bool =
  ## Enables mouse support in the terminal
  if term.rawMode:
    term.mouseEnabled = input.enableMouse()
    return term.mouseEnabled
  return false

proc disableMouse*(term: var Terminal) =
  ## Disables mouse support in the terminal
  if term.mouseEnabled:
    input.disableMouse()
    term.mouseEnabled = false

proc isRawMode*(term: Terminal): bool =
  ## Returns whether the terminal is in raw mode
  return term.rawMode

proc isMouseEnabled*(term: Terminal): bool =
  ## Returns whether mouse support is enabled
  return term.mouseEnabled

proc getDimensions*(term: Terminal): tuple[width: int, height: int] =
  ## Returns the dimensions of the terminal
  return (term.width, term.height)

proc updateDimensions*(term: var Terminal) =
  ## Updates the terminal dimensions
  if term.rawMode:
    (term.width, term.height) = raw.getTerminalSize()

# Agent Integration Methods
when not defined(noAgents):
  proc getAgentConfig*(term: Terminal): AgentConfig =
    ## Returns the agent configuration
    return term.agentConfig

  proc setAgentConfig*(term: var Terminal, config: AgentConfig) =
    ## Sets the agent configuration
    term.agentConfig = config

  proc getAgentRegistry*(term: Terminal): AgentRegistry =
    ## Returns the agent registry
    return term.agentRegistry

  proc enableMcpServer*(term: var Terminal, port: int = 8080): Future[bool] {.async.} =
    ## Enables MCP server for the terminal
    term.agentConfig.enableMcpServer(port)
    
    # Create and register MCP server
    let mcpServer = newMcpServer("terminal-mcp-server", port)
    term.agentRegistry.registerAgent(mcpServer)
    
    # Initialize the server
    result = await mcpServer.initialize()

  proc enableLlmClient*(term: var Terminal, apiKey: string, model: string = "gpt-3.5-turbo"): Future[bool] {.async.} =
    ## Enables LLM client for the terminal
    term.agentConfig.enableLlmClient(apiKey, model)
    
    # Create and register LLM client
    let llmConfig = newLlmConfig(lpOpenAI, apiKey, model)
    let llmClient = newLlmClient("terminal-llm-client", llmConfig)
    term.agentRegistry.registerAgent(llmClient)
    
    # Initialize the client
    result = await llmClient.initialize()

  proc addAgent*(term: var Terminal, agent: AgentInterface) =
    ## Adds an agent to the terminal registry
    term.agentRegistry.registerAgent(agent)

  proc removeAgent*(term: var Terminal, name: string): bool =
    ## Removes an agent from the terminal registry
    return term.agentRegistry.removeAgent(name)

  proc listAgents*(term: Terminal): seq[string] =
    ## Lists all registered agents
    return term.agentRegistry.listAgents()

  proc getAgent*(term: Terminal, name: string): Option[AgentInterface] =
    ## Gets an agent by name
    return term.agentRegistry.getAgent(name)

template withTerminal*(body: untyped) =
  ## A convenience template that initializes the terminal,
  ## executes the provided code, and ensures proper cleanup
  var term = newTerminal()
  try:
    term.init()
    body
  finally:
    term.shutdown()

template withMouseTerminal*(body: untyped) =
  ## A convenience template that initializes the terminal with mouse support,
  ## executes the provided code, and ensures proper cleanup
  var term = newTerminal()
  try:
    term.init(true)
    body
  finally:
    term.shutdown()