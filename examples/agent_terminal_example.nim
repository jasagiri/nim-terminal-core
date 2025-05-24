## Agent Terminal Example
## 
## Demonstrates how to use nim-libterminal with agent capabilities,
## including MCP server, LLM client, and agent-aware widgets.

import std/[asyncdispatch, os, strutils]
import ../src/libterminal

proc setupAgentTerminal(): Future[void] {.async.} =
  ## Sets up a terminal with agent capabilities
  var term = newTerminal()
  
  try:
    term.init(true)  # Initialize with mouse support
    
    echo "Setting up agent-enabled terminal..."
    
    # Enable MCP server (requires no API key for local tools)
    let mcpEnabled = await term.enableMcpServer(8080)
    if mcpEnabled:
      echo "✓ MCP Server enabled on port 8080"
    else:
      echo "✗ Failed to enable MCP Server"
    
    # Try to enable LLM client if API key is available
    let apiKey = getEnv("OPENAI_API_KEY")
    if apiKey.len > 0:
      let llmEnabled = await term.enableLlmClient(apiKey, "gpt-3.5-turbo")
      if llmEnabled:
        echo "✓ LLM Client enabled with OpenAI"
      else:
        echo "✗ Failed to enable LLM Client"
    else:
      echo "ℹ Set OPENAI_API_KEY environment variable to enable LLM features"
    
    # List available agents
    echo "\nRegistered agents:"
    let agents = term.listAgents()
    for agent in agents:
      echo "  - " & agent
    
    echo "\nAgent-enabled terminal ready!"
    echo "Features available:"
    echo "  - MCP Server for tool access"
    if apiKey.len > 0:
      echo "  - LLM Client for AI interaction"
    echo "  - Agent registry management"
    echo "\nPress any key to continue..."
    
    discard readChar(stdin)
    
  finally:
    term.shutdown()

proc demonstrateAgentWidgets(): Future[void] {.async.} =
  ## Demonstrates agent-specific widgets
  var term = newTerminal()
  
  try:
    term.init()
    
    echo "Creating agent-specific widgets..."
    
    # Create agent chat widget
    let chatWidget = newAgentChatWidget(0, 0, 80, 20)
    
    # Add some sample messages
    chatWidget.addMessage(AgentMessage(
      role: "system",
      content: "Welcome to the agent-enabled terminal!",
      metadata: newJObject()
    ))
    
    chatWidget.addMessage(AgentMessage(
      role: "user", 
      content: "Hello, can you help me with terminal commands?",
      metadata: newJObject()
    ))
    
    chatWidget.addMessage(AgentMessage(
      role: "assistant",
      content: "Of course! I can help you with various terminal operations like file management, process execution, and system information.",
      metadata: newJObject()
    ))
    
    # Create status widget
    let statusWidget = newAgentStatusWidget(0, 21, 80, 1)
    statusWidget.setStatus("Ready", "Agent system initialized")
    
    # Create command palette widget
    let paletteWidget = newCommandPaletteWidget(10, 5, 60, 10)
    let suggestions = @[
      "/agent help",
      "/llm explain this code",
      "/tool execute ls -la",
      "/config set api_key"
    ]
    paletteWidget.show(suggestions)
    
    # Render widgets
    chatWidget.render()
    statusWidget.render()
    paletteWidget.render()
    
    echo "\n\nAgent widgets demonstrated above."
    echo "Press any key to continue..."
    discard readChar(stdin)
    
  finally:
    term.shutdown()

proc demonstrateCommandParsing(): Future[void] {.async.} =
  ## Demonstrates agent command parsing
  echo "Testing agent command parsing..."
  
  let parser = newCommandParser("/agent")
  
  # Test various commands
  let testCommands = @[
    "/agent help",
    "/agent llm what is recursion?",
    "/agent tool execute pwd",
    "/agent config set api_key sk-1234",
    "/agent ai explain terminal commands",
    "/agent run ls -la /tmp"
  ]
  
  for cmd in testCommands:
    echo "\nInput: " & cmd
    if parser.isAgentCommand(cmd):
      let parsed = parser.parseCommand(cmd)
      echo "  Command: " & parsed.command
      echo "  Type: " & $parsed.commandType
      echo "  Subcommand: " & parsed.subcommand
      echo "  Arguments: " & $parsed.arguments
      echo "  Options: " & $parsed.options
      
      let (valid, error) = parser.validateCommandSyntax(cmd)
      if valid:
        echo "  Status: ✓ Valid"
      else:
        echo "  Status: ✗ " & error
    else:
      echo "  Status: Not an agent command"
  
  echo "\nCommand parsing demonstration complete."

proc demonstrateMcpIntegration(): Future[void] {.async.} =
  ## Demonstrates MCP server integration
  echo "Setting up MCP server integration..."
  
  # Create MCP server
  let mcpServer = newMcpServer("demo-terminal-server", 8081)
  
  # Setup default tools
  mcpServer.setupDefaultTools()
  mcpServer.setupDefaultResources()
  
  echo "MCP Server configured with tools:"
  for tool in mcpServer.mcpCapabilities.tools:
    echo "  - " & tool.name & ": " & tool.description
  
  echo "\nMCP Server configured with resources:"
  for resource in mcpServer.mcpCapabilities.resources:
    echo "  - " & resource.name & " (" & resource.uri & ")"
  
  echo "\nMCP server would be available at http://localhost:8081"
  echo "Tools can be called via POST /tools/call"
  echo "Resources can be accessed via GET /resources/<uri>"

proc main() {.async.} =
  ## Main demonstration function
  echo "=== nim-libterminal Agent Integration Demo ==="
  echo
  
  # Demonstrate command parsing
  await demonstrateCommandParsing()
  echo "\nPress Enter to continue..."
  discard readLine(stdin)
  
  # Demonstrate MCP integration
  await demonstrateMcpIntegration()
  echo "\nPress Enter to continue..."
  discard readLine(stdin)
  
  # Demonstrate agent widgets (requires terminal)
  echo "\nDemonstrating agent widgets..."
  await demonstrateAgentWidgets()
  
  # Setup full agent terminal
  echo "\nSetting up full agent terminal..."
  await setupAgentTerminal()
  
  echo "\n=== Demo Complete ==="
  echo "The nim-libterminal library now supports:"
  echo "✓ MCP Server integration for LLM tool access"
  echo "✓ LLM Client for direct AI communication"
  echo "✓ Agent-specific widgets (chat, status, command palette)"
  echo "✓ Command parsing and routing"
  echo "✓ Agent registry management"
  echo "✓ Backward compatibility with existing code"

when isMainModule:
  waitFor main()