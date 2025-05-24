## LLM Client Integration
## 
## Provides direct LLM communication capabilities for terminal applications

import std/[asyncdispatch, json, httpclient, strutils, tables, options, sequtils]
import agent_base

type
  LlmProvider* = enum
    ## Supported LLM providers
    lpOpenAI = "openai"
    lpAnthropic = "anthropic"
    lpLocal = "local"

  LlmConfig* = object
    ## LLM configuration
    provider*: LlmProvider
    apiKey*: string
    model*: string
    baseUrl*: string
    maxTokens*: int
    temperature*: float

  LlmClient* = ref object of AgentInterface
    ## LLM client implementation
    config*: LlmConfig
    client*: AsyncHttpClient
    conversationHistory*: seq[AgentMessage]

proc newLlmConfig*(provider: LlmProvider, apiKey: string, model: string): LlmConfig =
  ## Creates a new LLM configuration
  result = LlmConfig(
    provider: provider,
    apiKey: apiKey,
    model: model,
    maxTokens: 4096,
    temperature: 0.7
  )
  
  case provider:
  of lpOpenAI:
    result.baseUrl = "https://api.openai.com/v1"
  of lpAnthropic:
    result.baseUrl = "https://api.anthropic.com/v1"
  of lpLocal:
    result.baseUrl = "http://localhost:8000/v1"

proc newLlmClient*(name: string, config: LlmConfig): LlmClient =
  ## Creates a new LLM client
  result = LlmClient(
    name: name,
    description: "LLM Client for direct AI communication",
    config: config,
    client: newAsyncHttpClient(),
    conversationHistory: @[]
  )
  
  # Set up headers based on provider
  case config.provider:
  of lpOpenAI:
    result.client.headers = newHttpHeaders([
      ("Authorization", "Bearer " & config.apiKey),
      ("Content-Type", "application/json")
    ])
  of lpAnthropic:
    result.client.headers = newHttpHeaders([
      ("x-api-key", config.apiKey),
      ("Content-Type", "application/json"),
      ("anthropic-version", "2023-06-01")
    ])
  of lpLocal:
    result.client.headers = newHttpHeaders([
      ("Content-Type", "application/json")
    ])

proc formatMessagesForOpenAI(messages: seq[AgentMessage]): JsonNode =
  ## Formats messages for OpenAI API
  result = newJArray()
  for msg in messages:
    result.add(%*{
      "role": msg.role,
      "content": msg.content
    })

proc formatMessagesForAnthropic(messages: seq[AgentMessage]): JsonNode =
  ## Formats messages for Anthropic API
  var systemPrompt = ""
  var chatMessages = newJArray()
  
  for msg in messages:
    if msg.role == "system":
      if systemPrompt.len > 0:
        systemPrompt.add("\n")
      systemPrompt.add(msg.content)
    else:
      chatMessages.add(%*{
        "role": msg.role,
        "content": msg.content
      })
  
  result = %*{
    "system": systemPrompt,
    "messages": chatMessages
  }

proc sendRequest(client: LlmClient, messages: seq[AgentMessage]): Future[AgentResponse] {.async.} =
  ## Sends a request to the LLM API
  try:
    var requestBody: JsonNode
    var endpoint: string
    
    case client.config.provider:
    of lpOpenAI, lpLocal:
      endpoint = client.config.baseUrl & "/chat/completions"
      requestBody = %*{
        "model": client.config.model,
        "messages": formatMessagesForOpenAI(messages),
        "max_tokens": client.config.maxTokens,
        "temperature": client.config.temperature
      }
    
    of lpAnthropic:
      endpoint = client.config.baseUrl & "/messages"
      let formatted = formatMessagesForAnthropic(messages)
      requestBody = %*{
        "model": client.config.model,
        "max_tokens": client.config.maxTokens,
        "temperature": client.config.temperature,
        "system": formatted["system"],
        "messages": formatted["messages"]
      }
    
    let response = await client.client.request(endpoint, httpMethod = HttpPost, body = $requestBody)
    
    if response.code == Http200:
      let responseJson = parseJson(await response.body)
      var content: string
      
      case client.config.provider:
      of lpOpenAI, lpLocal:
        content = responseJson["choices"][0]["message"]["content"].getStr()
      of lpAnthropic:
        content = responseJson["content"][0]["text"].getStr()
      
      result = AgentResponse(
        success: true,
        content: content,
        error: "",
        metadata: responseJson
      )
    else:
      let errorBody = await response.body
      result = AgentResponse(
        success: false,
        content: "",
        error: "API Error " & $response.code & ": " & errorBody,
        metadata: newJObject()
      )
      
  except Exception as e:
    result = AgentResponse(
      success: false,
      content: "",
      error: "Request failed: " & e.msg,
      metadata: newJObject()
    )

method initialize*(client: LlmClient): Future[bool] {.async.} =
  ## Initializes the LLM client
  # Add system message if none exists
  if client.conversationHistory.len == 0:
    client.conversationHistory.add(AgentMessage(
      role: "system",
      content: "You are a helpful AI assistant integrated into a terminal application. You can help with terminal commands, file operations, and general programming tasks.",
      metadata: newJObject()
    ))
  
  result = true

method shutdown*(client: LlmClient): Future[void] {.async.} =
  ## Shuts down the LLM client
  client.client.close()

method processMessage*(client: LlmClient, message: AgentMessage): Future[AgentResponse] {.async.} =
  ## Process a message through the LLM
  # Add user message to history
  client.conversationHistory.add(message)
  
  # Send request to LLM
  let response = await client.sendRequest(client.conversationHistory)
  
  # Add assistant response to history if successful
  if response.success:
    client.conversationHistory.add(AgentMessage(
      role: "assistant",
      content: response.content,
      metadata: newJObject()
    ))
  
  return response

proc addSystemMessage*(client: LlmClient, content: string) =
  ## Adds a system message to the conversation
  client.conversationHistory.add(AgentMessage(
    role: "system",
    content: content,
    metadata: newJObject()
  ))

proc clearHistory*(client: LlmClient) =
  ## Clears the conversation history (keeps system messages)
  let systemMessages = client.conversationHistory.filterIt(it.role == "system")
  client.conversationHistory = systemMessages

proc getHistory*(client: LlmClient): seq[AgentMessage] =
  ## Gets the conversation history
  return client.conversationHistory

proc setTemperature*(client: LlmClient, temperature: float) =
  ## Sets the temperature for responses
  client.config.temperature = max(0.0, min(2.0, temperature))

proc setMaxTokens*(client: LlmClient, maxTokens: int) =
  ## Sets the maximum tokens for responses
  client.config.maxTokens = max(1, maxTokens)