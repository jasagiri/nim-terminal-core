# Agent Integration for nim-libterminal

nim-libterminal now supports comprehensive agent integration, making it compatible with modern AI and agent frameworks. This document describes the agent capabilities and how to use them.

## Overview

The agent integration provides:

- **MCP Server**: Model Context Protocol server for LLM tool access
- **LLM Client**: Direct communication with language models
- **Agent Widgets**: Specialized UI components for agent interaction
- **Command Parser**: Intelligent command routing and processing
- **Agent Registry**: Management of multiple agent instances

## Quick Start

```nim
import libterminal

# Create terminal with agent support
var term = newTerminal()
term.init()

# Enable MCP server for tool access
if waitFor term.enableMcpServer(8080):
  echo "MCP Server running on port 8080"

# Enable LLM client (requires API key)
if waitFor term.enableLlmClient("your-openai-api-key", "gpt-3.5-turbo"):
  echo "LLM Client ready"

# List available agents
echo "Agents: ", term.listAgents()
```

## Features

### 1. MCP Server Integration

The MCP (Model Context Protocol) server provides terminal capabilities as tools that LLMs can use:

```nim
# Setup MCP server with default tools
let mcpServer = newMcpServer("terminal-server", 8080)
mcpServer.setupDefaultTools()    # execute_command, list_directory, read_file
mcpServer.setupDefaultResources() # terminal://output, terminal://pwd
```

**Available Tools:**
- `execute_command`: Execute shell commands
- `list_directory`: List directory contents  
- `read_file`: Read file contents

**Available Resources:**
- `terminal://output`: Terminal output buffer
- `terminal://pwd`: Current working directory

### 2. LLM Client

Direct communication with language models:

```nim
# Configure LLM client
let config = newLlmConfig(lpOpenAI, "api-key", "gpt-3.5-turbo")
let client = newLlmClient("terminal-llm", config)

# Send message
let message = AgentMessage(role: "user", content: "Explain this command: ls -la")
let response = await client.processMessage(message)
echo response.content
```

**Supported Providers:**
- OpenAI (GPT models)
- Anthropic (Claude models)  
- Local (compatible APIs)

### 3. Agent Widgets

Specialized UI components for agent interaction:

```nim
# Chat widget for conversations
let chat = newAgentChatWidget(0, 0, 80, 20)
chat.addMessage(AgentMessage(role: "user", content: "Hello"))
chat.render()

# Status widget for agent activity
let status = newAgentStatusWidget(0, 21, 80, 1)
status.setStatus("Processing", "Analyzing code...")
status.render()

# Command palette for suggestions
let palette = newCommandPaletteWidget(10, 5, 60, 10)
palette.show(@["/agent help", "/llm explain", "/tool execute"])
palette.render()

# Response widget with formatting
let response = newAgentResponseWidget(0, 22, 80, 10)
response.setContent("Code analysis complete...", {"color": "green"}.toTable)
response.render()
```

### 4. Command Parser

Intelligent parsing and routing of agent commands:

```nim
let parser = newCommandParser("/agent")

# Register command handlers
parser.registerHandler(ctLlm, proc(cmd: ParsedCommand): Future[string] {.async.} =
  # Handle LLM commands
  result = "LLM response: " & cmd.arguments.join(" ")
)

# Process commands
if parser.isAgentCommand("/agent llm explain recursion"):
  let response = await parser.processCommand("/agent llm explain recursion")
  echo response
```

**Command Types:**
- `/agent <subcommand>` - Agent management
- `/llm <message>` - LLM conversation
- `/tool <name> [args]` - Tool execution
- `/config <key> [value]` - Configuration
- `/help` - Help system

## Integration with Toumyou Terminal

Toumyou Terminal includes full agent integration:

```bash
# Start Toumyou with agent support
./toumyou

# In the terminal:
agents                    # Show agent status
/agent enable mcp         # Enable MCP server
/agent enable llm <key>   # Enable LLM client
/agent help              # Show agent commands
/llm explain this error  # Chat with LLM
/tool execute ls -la     # Execute via MCP tools
```

## Examples

### Basic Agent Terminal

```nim
import std/asyncdispatch
import libterminal

proc agentTerminalExample() {.async.} =
  var term = newTerminal()
  term.init()
  
  # Enable agent capabilities
  discard await term.enableMcpServer(8080)
  discard await term.enableLlmClient(getEnv("OPENAI_API_KEY"))
  
  echo "Agent-enabled terminal ready!"
  echo "Commands: /agent, /llm, /tool"
  
  term.shutdown()

waitFor agentTerminalExample()
```

### Custom Agent

```nim
import libterminal

type
  CustomAgent = ref object of AgentInterface

method processMessage(agent: CustomAgent, msg: AgentMessage): Future[AgentResponse] {.async.} =
  result = AgentResponse(
    success: true,
    content: "Custom response: " & msg.content,
    error: "",
    metadata: newJObject()
  )

# Register custom agent
let customAgent = CustomAgent(name: "custom", description: "Custom agent")
term.addAgent(customAgent)
```

### MCP Client Usage

```nim
# External application using Toumyou's MCP server
import std/[httpclient, json]

let client = newHttpClient()
let response = client.request("http://localhost:8080/tools/call", 
  httpMethod = HttpPost,
  body = $%*{
    "tool": "execute_command",
    "arguments": {
      "command": "ls -la"
    }
  }
)

echo await response.body
```

## Configuration

### Environment Variables

- `OPENAI_API_KEY`: OpenAI API key for LLM features
- `ANTHROPIC_API_KEY`: Anthropic API key for Claude
- `TOUMYOU_MCP_PORT`: Default MCP server port (default: 8080)

### Configuration File

```yaml
# config/agent.yaml
agents:
  mcp:
    enabled: true
    port: 8080
    tools: [execute_command, list_directory, read_file]
  
  llm:
    enabled: false
    provider: openai
    model: gpt-3.5-turbo
    max_tokens: 4096
    temperature: 0.7

commands:
  prefix: "/agent"
  aliases:
    ai: llm
    chat: llm
    run: tool
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   LLM Client    │    │   MCP Server     │    │  Agent Widgets  │
│   (OpenAI, etc) │    │   (Tools/Res)    │    │   (UI Components)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
              ┌──────────────────────────────────┐
              │      Agent Integration           │
              │   (Command Parser, Registry)     │
              └──────────────────────────────────┘
                                 │
              ┌──────────────────────────────────┐
              │        nim-libterminal           │
              │    (Terminal, Widgets, I/O)      │
              └──────────────────────────────────┘
                                 │
              ┌──────────────────────────────────┐
              │      Toumyou Terminal           │
              │   (Shell, Application Logic)    │
              └──────────────────────────────────┘
```

## Protocol Support

### Model Context Protocol (MCP)

Full MCP compatibility for LLM tool access:

- **Transport**: HTTP, stdio, in-memory
- **Tools**: Command execution, file operations, system access  
- **Resources**: Terminal state, output streams, filesystem
- **Security**: Sandboxed execution, permission controls

### Agent Communication Protocol (ACP)

Support for local agent communication:

- **Message Format**: JSON-based structured messages
- **Capabilities**: Agent discovery, task delegation
- **Streaming**: Real-time communication for long-running tasks

### Agent-to-Agent (A2A)

Integration with agent ecosystem:

- **Discovery**: Agent cards and capability advertising
- **Interop**: Cross-framework agent communication
- **Standards**: Compatible with existing A2A implementations

## Best Practices

### Security

- Always validate command inputs
- Use sandboxed execution for external commands
- Implement proper authentication for API access
- Limit resource access based on agent capabilities

### Performance

- Use async operations for all agent communication
- Implement proper error handling and timeouts
- Cache agent responses when appropriate
- Limit concurrent agent operations

### User Experience

- Provide clear feedback for agent operations
- Implement proper loading states
- Use consistent command syntax
- Offer helpful error messages and suggestions

## Troubleshooting

### Common Issues

1. **MCP Server fails to start**
   ```
   Error: Port 8080 already in use
   Solution: Use different port or kill existing process
   ```

2. **LLM Client authentication fails**
   ```
   Error: Invalid API key
   Solution: Check environment variables and API key format
   ```

3. **Command not recognized**
   ```
   Error: Unknown command: /agent xyz
   Solution: Use /agent help to see available commands
   ```

### Debug Mode

```nim
# Enable debug logging
when defined(debug):
  setLogLevel(lvlDebug)
  echo "Agent debug mode enabled"
```

## Contributing

Agent integration is actively developed. Contributions welcome:

- New agent implementations
- Additional MCP tools and resources
- UI widget improvements
- Protocol extensions
- Documentation and examples

## License

Agent integration follows the same Apache-2.0 license as nim-libterminal.