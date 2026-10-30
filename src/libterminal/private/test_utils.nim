# test_utils.nim
## Test utilities for headless environments

import posix

# Import base types
type
  Termios* = object
    c_iflag*, c_oflag*, c_cflag*, c_lflag*: uint32
    c_cc*: array[20, uint8]
    c_ispeed*, c_ospeed*: uint32

const
  ICRNL* = 0x0100
  IXON* = 0x0400
  OPOST* = 0x0001
  ECHO* = 0x0008
  ICANON* = 0x0002
  ISIG* = 0x0001
  IEXTEN* = 0x8000
  NCCS* = 20
  TIOCGWINSZ* = 0x5413'u64  # Linux value

type
  IOctl_WinSize* = object
    ws_row*, ws_col*: cushort
    ws_xpixel*, ws_ypixel*: cushort

var isTestMode* = false
var mockTerminalSize* = (width: 80, height: 24)

proc enableTestMode*() =
  ## Enable test mode for headless environments
  isTestMode = true

proc disableTestMode*() =
  ## Disable test mode
  isTestMode = false

proc setMockTerminalSize*(width, height: int) =
  ## Set mock terminal size for tests
  mockTerminalSize = (width: width, height: height)

# Override isatty for tests
proc isattyTest*(fd: FileHandle): bool =
  if isTestMode:
    return true  # Always return true in test mode
  else:
    return isatty(fd.cint) == 1

# Mock termios for test mode
type
  MockTermios = object
    c_iflag: uint32
    c_oflag: uint32
    c_cflag: uint32
    c_lflag: uint32
    c_cc: array[NCCS, uint8]

var mockTermios: MockTermios
var mockTermiosSet = false

proc tcgetattrTest*(fd: cint, termios: ptr Termios): cint =
  if isTestMode:
    # Initialize with reasonable defaults
    termios.c_iflag = uint32(ICRNL or IXON)
    termios.c_oflag = uint32(OPOST)
    termios.c_lflag = uint32(ECHO or ICANON or ISIG or IEXTEN)
    termios.c_cflag = 0
    return 0
  else:
    # Not available in test mode
    return -1

proc tcsetattrTest*(fd: cint, optional_actions: cint, termios: ptr Termios): cint =
  if isTestMode:
    # Store the settings in mock
    mockTermios.c_iflag = termios.c_iflag
    mockTermios.c_oflag = termios.c_oflag
    mockTermios.c_cflag = termios.c_cflag
    mockTermios.c_lflag = termios.c_lflag
    mockTermiosSet = true
    return 0
  else:
    # Not available in test mode
    return -1

proc ioctlTest*(fd: cint, request: culong, argp: pointer): cint =
  if isTestMode and request == TIOCGWINSZ:
    # Return mock window size
    let winsize = cast[ptr IOctl_WinSize](argp)
    winsize.ws_row = mockTerminalSize.height.cushort
    winsize.ws_col = mockTerminalSize.width.cushort
    return 0
  else:
    when defined(macosx) or defined(linux):
      return ioctl(fd, request, argp).cint
    else:
      return -1