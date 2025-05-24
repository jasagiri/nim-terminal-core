## Agent Integration Module for nim-libterminal
## 
## This module provides agent capabilities for terminal applications,
## including MCP server integration, LLM communication, and agent-aware widgets.

import agents/agent_base
import agents/mcp_server
import agents/llm_client
import agents/agent_widgets
import agents/command_parser

export agent_base
export mcp_server
export llm_client
export agent_widgets
export command_parser

const
  AgentVersion* = "0.1.0"   ## Agent integration version

type
  AgentCapability* = enum
    ## Available agent capabilities
    acMcpServer      ## MCP Server for LLM tool access
    acLlmClient      ## Direct LLM communication
    acCommandParsing ## Command parsing and routing
    acAgentWidgets   ## Agent-specific UI widgets

  AgentConfig* = object
    ## Configuration for agent functionality
    capabilities*: set[AgentCapability]
    mcpPort*: int
    llmApiKey*: string
    llmModel*: string
    commandPrefix*: string

proc newAgentConfig*(): AgentConfig =
  ## Creates a default agent configuration
  result = AgentConfig(
    capabilities: {acCommandParsing, acAgentWidgets},
    mcpPort: 8080,
    llmApiKey: "",
    llmModel: "gpt-3.5-turbo",
    commandPrefix: "/agent"
  )

proc enableMcpServer*(config: var AgentConfig, port: int = 8080) =
  ## Enables MCP server capability
  config.capabilities.incl(acMcpServer)
  config.mcpPort = port

proc enableLlmClient*(config: var AgentConfig, apiKey: string, model: string = "gpt-3.5-turbo") =
  ## Enables LLM client capability
  config.capabilities.incl(acLlmClient)
  config.llmApiKey = apiKey
  config.llmModel = model

proc setCommandPrefix*(config: var AgentConfig, prefix: string) =
  ## Sets the command prefix for agent commands
  config.commandPrefix = prefix