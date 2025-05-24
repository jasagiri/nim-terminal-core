## MCP Server Integration
## 
## Provides MCP (Model Context Protocol) server capabilities for nim-libterminal,
## allowing LLMs to interact with terminal functionality as tools.

import std/[asyncdispatch, json, tables, options, strutils, os, httpcore, asynchttpserver, osproc]
import agent_base
import ../widgets

type
  McpTool* = object
    ## MCP tool definition
    name*: string
    description*: string
    inputSchema*: JsonNode

  McpResource* = object
    ## MCP resource definition  
    uri*: string
    name*: string
    description*: string
    mimeType*: string

  McpServerCapabilities* = object
    ## MCP server capabilities
    tools*: seq[McpTool]
    resources*: seq[McpResource]
    logging*: bool
    prompts*: bool

  McpServer* = ref object of AgentInterface
    ## MCP server implementation
    port*: int
    server*: AsyncHttpServer
    mcpCapabilities*: McpServerCapabilities
    tools*: Table[string, proc(args: JsonNode): Future[JsonNode] {.async, gcsafe.}]
    resources*: Table[string, proc(): Future[string] {.async, gcsafe.}]
    running*: bool

proc newMcpServer*(name: string, port: int = 8080): McpServer =
  ## Creates a new MCP server
  result = McpServer(
    name: name,
    description: "Terminal MCP Server providing terminal capabilities",
    port: port,
    server: newAsyncHttpServer(),
    tools: initTable[string, proc(args: JsonNode): Future[JsonNode] {.async, gcsafe.}](),
    resources: initTable[string, proc(): Future[string] {.async, gcsafe.}](),
    running: false
  )
  
  result.mcpCapabilities = McpServerCapabilities(
    tools: @[],
    resources: @[],
    logging: true,
    prompts: false
  )

proc registerTool*(server: McpServer, name: string, description: string, 
                  inputSchema: JsonNode, handler: proc(args: JsonNode): Future[JsonNode] {.async, gcsafe.}) =
  ## Registers a tool with the MCP server
  let tool = McpTool(
    name: name,
    description: description,
    inputSchema: inputSchema
  )
  
  server.mcpCapabilities.tools.add(tool)
  server.tools[name] = handler

proc registerResource*(server: McpServer, uri: string, name: string, 
                      description: string, mimeType: string,
                      provider: proc(): Future[string] {.async, gcsafe.}) =
  ## Registers a resource with the MCP server
  let resource = McpResource(
    uri: uri,
    name: name,
    description: description,
    mimeType: mimeType
  )
  
  server.mcpCapabilities.resources.add(resource)
  server.resources[uri] = provider

proc setupDefaultTools*(server: McpServer) =
  ## Sets up default terminal tools
  
  # Execute command tool
  server.registerTool(
    "execute_command",
    "Execute a shell command in the terminal",
    %*{
      "type": "object",
      "properties": {
        "command": {"type": "string", "description": "Command to execute"},
        "workingDir": {"type": "string", "description": "Working directory (optional)"}
      },
      "required": ["command"]
    },
    proc(args: JsonNode): Future[JsonNode] {.async.} =
      let command = args["command"].getStr()
      let workingDir = if "workingDir" in args: args["workingDir"].getStr() else: getCurrentDir()
      
      try:
        let oldDir = getCurrentDir()
        if workingDir != oldDir:
          setCurrentDir(workingDir)
        
        let output = execProcess(command)
        
        if workingDir != oldDir:
          setCurrentDir(oldDir)
        
        result = %*{
          "success": true,
          "output": output,
          "command": command,
          "workingDir": workingDir
        }
      except OSError as e:
        result = %*{
          "success": false,
          "error": e.msg,
          "command": command
        }
  )
  
  # List directory tool
  server.registerTool(
    "list_directory",
    "List contents of a directory",
    %*{
      "type": "object",
      "properties": {
        "path": {"type": "string", "description": "Directory path to list"},
        "showHidden": {"type": "boolean", "description": "Show hidden files"}
      },
      "required": ["path"]
    },
    proc(args: JsonNode): Future[JsonNode] {.async.} =
      let path = args["path"].getStr()
      let showHidden = if "showHidden" in args: args["showHidden"].getBool() else: false
      
      try:
        var files: seq[JsonNode] = @[]
        for kind, filePath in walkDir(path):
          let name = extractFilename(filePath)
          if not showHidden and name.startsWith("."):
            continue
            
          files.add(%*{
            "name": name,
            "path": filePath,
            "type": if kind == pcDir: "directory" else: "file"
          })
        
        result = %*{
          "success": true,
          "path": path,
          "files": files
        }
      except OSError as e:
        result = %*{
          "success": false,
          "error": e.msg,
          "path": path
        }
  )
  
  # Read file tool
  server.registerTool(
    "read_file",
    "Read contents of a file",
    %*{
      "type": "object",
      "properties": {
        "path": {"type": "string", "description": "File path to read"},
        "maxBytes": {"type": "integer", "description": "Maximum bytes to read"}
      },
      "required": ["path"]
    },
    proc(args: JsonNode): Future[JsonNode] {.async.} =
      let path = args["path"].getStr()
      let maxBytes = if "maxBytes" in args: args["maxBytes"].getInt() else: 1024 * 1024  # 1MB default
      
      try:
        let content = readFile(path)
        let truncated = content.len > maxBytes
        let finalContent = if truncated: content[0..<maxBytes] else: content
        
        result = %*{
          "success": true,
          "path": path,
          "content": finalContent,
          "size": content.len,
          "truncated": truncated
        }
      except IOError as e:
        result = %*{
          "success": false,
          "error": e.msg,
          "path": path
        }
  )

proc setupDefaultResources*(server: McpServer) =
  ## Sets up default terminal resources
  
  # Terminal output resource
  server.registerResource(
    "terminal://output",
    "Terminal Output",
    "Current terminal output buffer",
    "text/plain",
    proc(): Future[string] {.async.} =
      # This would typically read from a terminal output buffer
      result = "Terminal output would go here"
  )
  
  # Current directory resource
  server.registerResource(
    "terminal://pwd",
    "Current Directory",
    "Current working directory",
    "text/plain",
    proc(): Future[string] {.async, gcsafe.} =
      result = getCurrentDir()
  )

proc handleRequest(server: McpServer, req: Request): Future[void] {.async, gcsafe.} =
  ## Handles HTTP requests for the MCP server
  let path = req.url.path
  
  case req.reqMethod:
  of HttpGet:
    if path == "/capabilities":
      let response = %*{
        "tools": server.mcpCapabilities.tools,
        "resources": server.mcpCapabilities.resources,
        "logging": server.mcpCapabilities.logging,
        "prompts": server.mcpCapabilities.prompts
      }
      await req.respond(Http200, $response, newHttpHeaders([("Content-Type", "application/json")]))
    elif path.startsWith("/resources/"):
      let uri = path[11..^1]  # Remove "/resources/" prefix
      if uri in server.resources:
        let content = await server.resources[uri]()
        await req.respond(Http200, content)
      else:
        await req.respond(Http404, "Resource not found")
    else:
      await req.respond(Http404, "Not found")
      
  of HttpPost:
    if path == "/tools/call":
      try:
        let bodyStr = req.body
        let request = parseJson(bodyStr)
        let toolName = request["tool"].getStr()
        let args = request["arguments"]
        
        if toolName in server.tools:
          let result = await server.tools[toolName](args)
          await req.respond(Http200, $result, newHttpHeaders([("Content-Type", "application/json")]))
        else:
          let error = %*{"error": "Tool not found", "tool": toolName}
          await req.respond(Http404, $error, newHttpHeaders([("Content-Type", "application/json")]))
      except JsonParsingError:
        let error = %*{"error": "Invalid JSON in request body"}
        await req.respond(Http400, $error, newHttpHeaders([("Content-Type", "application/json")]))
    else:
      await req.respond(Http404, "Not found")
      
  else:
    await req.respond(Http405, "Method not allowed")

method initialize*(server: McpServer): Future[bool] {.async.} =
  ## Initializes the MCP server
  try:
    server.setupDefaultTools()
    server.setupDefaultResources()
    
    server.server.listen(Port(server.port))
    server.running = true
    
    echo "MCP Server started on port ", server.port
    
    # Start handling requests in background
    proc serveHandler(req: Request) {.async, gcsafe.} =
      await server.handleRequest(req)
    
    asyncCheck server.server.serve(Port(server.port), serveHandler)
    
    result = true
  except:
    result = false

method shutdown*(server: McpServer): Future[void] {.async.} =
  ## Shuts down the MCP server
  server.running = false
  server.server.close()
  echo "MCP Server stopped"

method processMessage*(server: McpServer, message: AgentMessage): Future[AgentResponse] {.async.} =
  ## Process messages via MCP protocol
  try:
    let content = parseJson(message.content)
    if "tool" in content and "arguments" in content:
      let toolName = content["tool"].getStr()
      let args = content["arguments"]
      
      if toolName in server.tools:
        let result = await server.tools[toolName](args)
        return AgentResponse(
          success: true,
          content: $result,
          error: "",
          metadata: newJObject()
        )
      else:
        return AgentResponse(
          success: false,
          content: "",
          error: "Tool not found: " & toolName,
          metadata: newJObject()
        )
    else:
      return AgentResponse(
        success: false,
        content: "",
        error: "Invalid MCP request format",
        metadata: newJObject()
      )
  except JsonParsingError:
    return AgentResponse(
      success: false,
      content: "",
      error: "Invalid JSON in message",
      metadata: newJObject()
    )