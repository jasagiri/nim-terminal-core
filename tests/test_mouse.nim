# test_mouse.nim
## Mouse functionality tests

import unittest
import ../src/libterminal/mouse

suite "Mouse mode":
  test "MouseMode enumeration":
    # Basic check - verify enumeration values exist
    check(MouseNone is MouseMode)
    check(MouseX10 is MouseMode)
    check(MouseVT200 is MouseMode)
    check(MouseButtonEvent is MouseMode)
    check(MouseAnyEvent is MouseMode)
    check(MouseSGR is MouseMode)
    check(MouseURXVT is MouseMode)
  
  test "Initial state":
    # Mouse mode is disabled in initial state
    check(getActiveMouseMode() == MouseNone)
  
  test "Mouse mode enable and disable":
    # Enable mouse mode
    # Note: Mouse mode may not be enabled if not in a real terminal,
    # so we don't check the return value
    discard enableMouseMode(MouseX10)
    
    # Check if mode has changed
    # (Conditional test as terminal may not support it)
    if getActiveMouseMode() != MouseNone:
      check(getActiveMouseMode() == MouseX10)
      
      # Switch to another mode
      discard enableMouseMode(MouseSGR)
      check(getActiveMouseMode() == MouseSGR)
      
      # Disable mouse mode
      disableMouseMode()
      check(getActiveMouseMode() == MouseNone)
    else:
      # Skip if terminal doesn't support mouse mode
      skip()
  
  test "Mouse mode support check":
    # This function should return true in most environments
    let supported = supportsMouseMode()
    check(supported is bool)
  
  test "Mouse mode switching":
    # Multiple switches to the same mode
    let result1 = enableMouseMode(MouseSGR)
    let result2 = enableMouseMode(MouseSGR)  # Second time should return false
    
    if result1:  # Only check if mouse mode is supported
      check(not result2)  # Fails because it's the same mode
      
      # Different mode
      check(enableMouseMode(MouseVT200))
      
      # Cleanup
      disableMouseMode()
    else:
      skip()
  
  test "Switching between various mouse modes":
    # Test all modes
    for mode in [MouseX10, MouseVT200, MouseButtonEvent, 
                MouseAnyEvent, MouseSGR, MouseURXVT]:
      discard enableMouseMode(mode)
      if getActiveMouseMode() != MouseNone:
        check(getActiveMouseMode() == mode)
      disableMouseMode()
    
    # Cleanup
    disableMouseMode()

# Ensure mouse mode is disabled at test end
# addTeardown is not available in this unittest version