## Test agent widgets compilation
import ../src/libterminal/agents/agent_widgets
import ../src/libterminal/agents/agent_base
import ../src/libterminal/widget_base
import ../src/libterminal/widgets
import std/json

# Test that we can create agent widgets
block testAgentChatWidget:
  let widget = newAgentChatWidget(0, 0, 80, 24)
  assert widget != nil
  assert widget.id == "agent_chat"
  
  # Test adding messages
  let msg = AgentMessage(
    role: "user",
    content: "Hello",
    metadata: newJObject()
  )
  widget.addMessage(msg)
  assert widget.messages.len == 1

block testAgentStatusWidget:
  let widget = newAgentStatusWidget(0, 0, 40, 1)
  assert widget != nil
  assert widget.status == "Ready"
  
  widget.setStatus("Processing", "Running task")
  assert widget.status == "Processing"
  assert widget.activity == "Running task"

block testCommandPaletteWidget:
  let widget = newCommandPaletteWidget(0, 0, 60, 10)
  assert widget != nil
  assert not widget.visible
  
  widget.show(@["command1", "command2"])
  assert widget.visible
  assert widget.suggestions.len == 2

block testAgentResponseWidget:
  let widget = newAgentResponseWidget(0, 0, 80, 20)
  assert widget != nil
  
  widget.setContent("Test response content")
  assert widget.content == "Test response content"

echo "All agent widget tests passed!"