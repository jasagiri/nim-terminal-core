# hello_world.nim
## A simple Hello World example for the libterminal library
## 
## This example demonstrates basic terminal initialization,
## printing text with colors, and terminal cleanup.

import std/os
import libterminal

proc main() =
  # Initialize terminal
  var term = newTerminal()
  term.init()
  
  try:
    # Get terminal size
    let (width, height) = raw.getTerminalSize()
    
    # Create a buffer for drawing
    var buffer = newBuffer(width, height)
    
    # Clear the screen
    clearScreen()
    
    # Print a centered "Hello, World!" message
    let message = "Hello, World!"
    let x = (width - message.len) div 2
    let y = height div 2
    
    # Print with colors
    let style = Style(
      fg: ColorGreen,
      bg: ColorDefault,
      attrs: {AttrBoldAttr}
    )
    buffer.print(x, y, message, style)
    
    # Print instructions
    buffer.print(x, y + 2, "Press any key to exit...", Style(
      fg: ColorCyan,
      bg: ColorDefault,
      attrs: {}
    ))
    
    # Draw the buffer to the screen
    drawBuffer(buffer)
    
    # Wait for a keypress
    discard input.pollEvent()
    
  finally:
    # Ensure terminal is restored to original state
    term.shutdown()

when isMainModule:
  main()