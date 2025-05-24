## Base Agent Interface
## 
## Defines the core agent interface and common types for agent functionality

import std/[asyncdispatch, json, tables, options]

type
  AgentMessage* = object
    ## A message in agent communication
    role*: string        # "user", "assistant", "system"
    content*: string     # Message content
    metadata*: JsonNode  # Additional metadata

  AgentResponse* = object
    ## Response from an agent
    success*: bool
    content*: string
    error*: string
    metadata*: JsonNode

  AgentCapabilities* = object
    ## Capabilities that an agent provides
    tools*: seq[string]
    resources*: seq[string]
    maxTokens*: int
    supportsStreaming*: bool

  AgentInterface* = ref object of RootObj
    ## Base interface for all agents
    name*: string
    description*: string
    capabilities*: AgentCapabilities

method getName*(agent: AgentInterface): string {.base.} =
  ## Returns the agent name
  return agent.name

method getDescription*(agent: AgentInterface): string {.base.} =
  ## Returns the agent description
  return agent.description

method getCapabilities*(agent: AgentInterface): AgentCapabilities {.base.} =
  ## Returns the agent capabilities
  return agent.capabilities

method processMessage*(agent: AgentInterface, message: AgentMessage): Future[AgentResponse] {.base, async.} =
  ## Process a message and return a response
  result = AgentResponse(
    success: false,
    content: "",
    error: "Not implemented",
    metadata: newJObject()
  )

method initialize*(agent: AgentInterface): Future[bool] {.base, async.} =
  ## Initialize the agent
  result = true

method shutdown*(agent: AgentInterface): Future[void] {.base, async.} =
  ## Shutdown the agent
  discard

type
  AgentRegistry* = ref object
    ## Registry for managing multiple agents
    agents*: Table[string, AgentInterface]

proc newAgentRegistry*(): AgentRegistry =
  ## Creates a new agent registry
  result = AgentRegistry(
    agents: initTable[string, AgentInterface]()
  )

proc registerAgent*(registry: AgentRegistry, agent: AgentInterface) =
  ## Registers an agent in the registry
  registry.agents[agent.name] = agent

proc getAgent*(registry: AgentRegistry, name: string): Option[AgentInterface] =
  ## Gets an agent by name
  if name in registry.agents:
    result = some(registry.agents[name])
  else:
    result = none(AgentInterface)

proc listAgents*(registry: AgentRegistry): seq[string] =
  ## Lists all registered agent names
  for name in registry.agents.keys:
    result.add(name)

proc removeAgent*(registry: AgentRegistry, name: string): bool =
  ## Removes an agent from the registry
  if name in registry.agents:
    registry.agents.del(name)
    return true
  return false