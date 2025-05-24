# basic_colors.nim
#
# Nim Terminal Library color demonstration
# Shows basic colors, 256 colors and RGB colors based on terminal capabilities

import std/strformat
import std/terminal
import std/math
import std/os

# We only need the color utilities directly
import ../src/libterminal/private/color_utils

proc main() =
  # Clear the screen and set basic info
  stdout.write("\e[2J")  # Clear screen
  stdout.write("\e[1;1H")  # Move cursor to top-left
  
  # Show current color support
  let mode = detectColorSupport()
  echo "Current terminal color support: ", case mode
    of ColorBasic: "Basic colors (8 colors)"
    of ColorBright: "Bright colors (16 colors)"
    of Color256: "256 colors"
    of ColorRGB: "RGB/True Color (16+ million colors)"
  
  echo "\nThis terminal will use the best available color mode.\n"
  
  # Show basic colors
  echo "Basic ANSI colors:"
  for i in 0..7:
    # Set background color
    stdout.write("\e[4", $i, "m  \e[0m ")
  stdout.write("\n")
  
  # Show bright colors
  if mode >= ColorBright:
    echo "\nBright colors:"
    for i in 0..7:
      # Bold/bright background colors
      stdout.write("\e[10", $i, "m  \e[0m ")
    stdout.write("\n")
  
  # Show 256 color palette sample
  if mode >= Color256:
    echo "\n256 color palette (sample):"
    
    # Show a few colors from the 6x6x6 color cube
    for i in 16..51:  # First two rows
      stdout.write("\e[48;5;", $i, "m  \e[0m")
      if (i - 16) mod 6 == 5:
        stdout.write("\n")
    stdout.write("\n")
  
  # Show RGB colors (gradient)
  if mode >= ColorRGB:
    echo "\nRGB color gradient:"
    
    # Create red to blue gradient
    for i in 0..20:
      let t = i.float / 20.0
      let r = int(255.0 * (1.0 - t))
      let b = int(255.0 * t)
      
      # Use RGB escape sequence
      stdout.write("\e[48;2;", $r, ";0;", $b, "m  \e[0m")
    stdout.write("\n")
  
  # Restore terminal settings
  stdout.write("\e[0m\n")

main()