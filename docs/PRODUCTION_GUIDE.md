# nim-libterminal Production Deployment Guide

Version: 0.5.0

## Overview

This guide covers best practices for deploying nim-libterminal in production environments, including configuration, monitoring, error handling, and performance optimization.

## Installation

### Package Manager Installation

```bash
# Via Nimble
nimble install libterminal

# Or add to your .nimble file
requires "libterminal >= 0.5.0"
```

### Source Installation

```bash
git clone https://github.com/your-org/nim-libterminal.git
cd nim-libterminal
nimble install
```

### Verification

```nim
import libterminal
echo "nim-libterminal version: ", Version
```

## Production Configuration

### Environment Variables

Set these environment variables for production deployment:

```bash
# Core Configuration
export LIBTERMINAL_ENABLE_LOGGING=true
export LIBTERMINAL_LOG_LEVEL=INFO
export LIBTERMINAL_LOG_FILE=/var/log/myapp/terminal.log

# Performance Settings
export LIBTERMINAL_BUFFER_SIZE=16384
export LIBTERMINAL_REFRESH_RATE=60
export LIBTERMINAL_ENABLE_DIFF_UPDATES=true

# Error Handling
export LIBTERMINAL_RETRY_ATTEMPTS=3
export LIBTERMINAL_RETRY_DELAY=100
export LIBTERMINAL_ENABLE_RECOVERY=true

# Feature Flags
export LIBTERMINAL_MOUSE_SUPPORT=true
export LIBTERMINAL_UNICODE_SUPPORT=true
export LIBTERMINAL_COLOR_SUPPORT=truecolor
```

### Configuration File

Create `/etc/myapp/terminal.conf`:

```ini
# Core settings
enable_logging=true
log_level=INFO
log_file=/var/log/myapp/terminal.log

# Terminal behavior
mouse_support=true
unicode_support=true
color_support=truecolor

# Performance settings
buffer_size=16384
refresh_rate=60
enable_diff_updates=true

# Error handling
retry_attempts=3
retry_delay=100
enable_recovery=true
```

### Application Configuration

```nim
import libterminal

proc setupProduction() =
  let config = getConfig()
  
  # Load from environment and config file
  config.loadFromEnv()
  if fileExists("/etc/myapp/terminal.conf"):
    discard config.loadFromFile("/etc/myapp/terminal.conf")
  
  # Apply configuration
  if not config.applyConfig():
    raise newException(ConfigurationError, "Failed to apply terminal configuration")
  
  # Setup logging
  if config.enableLogging:
    discard initTerminalLogging(
      level = case config.logLevel
        of "DEBUG": lvlDebug
        of "INFO": lvlInfo  
        of "WARN": lvlWarn
        of "ERROR": lvlError
        of "FATAL": lvlFatal
        else: lvlInfo,
      logFile = config.logFile
    )

# Call during application startup
setupProduction()
```

## Error Handling Strategy

### Exception Hierarchy

nim-libterminal uses a structured exception hierarchy for better error handling:

```nim
try:
  var term = newTerminal()
  term.init()
  # ... application logic
except RawModeError as e:
  logError(fmt"Raw mode failed: {e.msg}")
  # Attempt fallback mode or exit gracefully
except MouseError as e:
  logWarn(fmt"Mouse support unavailable: {e.msg}")
  # Continue without mouse support
except SizeError as e:
  logError(fmt"Invalid terminal size: {e.msg}")
  # Exit or use default size
except LibTerminalError as e:
  logError(fmt"Terminal error in {e.component}: {e.msg}")
  if e.recoverable:
    # Attempt recovery
    discard
  else:
    # Exit gracefully
    quit(1)
```

### Result Types for Critical Operations

Use Result types for operations where exceptions might be too heavy:

```nim
proc safeSizeCheck(): TerminalResult[tuple[width: int, height: int]] =
  let (w, h) = getTerminalSize()
  validateTerminalSize(w, h)

# Usage
let sizeResult = safeSizeCheck()
if sizeResult.isOk:
  let (width, height) = sizeResult.get()
  # Use validated size
else:
  logError("Size validation failed")
  # Use fallback values
  let (width, height) = (80, 24)
```

### Recovery Strategies

```nim
proc robustTerminalInit(maxRetries: int = 3): bool =
  for attempt in 1..maxRetries:
    try:
      var term = newTerminal()
      term.init()
      return true
    except RawModeError:
      logWarn(fmt"Raw mode init failed, attempt {attempt}/{maxRetries}")
      if attempt == maxRetries:
        logError("All raw mode init attempts failed")
        return false
      sleep(100 * attempt)  # Exponential backoff
  
  return false
```

## Logging and Monitoring

### Structured Logging

Enable structured logging for better observability:

```nim
# Initialize with structured logging
discard initTerminalLogging(lvlInfo, "/var/log/myapp/terminal.log")

# Log important events
logInfo("Application started", "MAIN")
logRawModeChange(entering = true, success = true)
logTerminalSize(width, height)
logPerformanceMetric("buffer_draw", 2.5)  # 2.5ms

# Log errors with context
proc handleTerminalError(e: LibTerminalError) =
  logError(fmt"Component: {e.component}, Code: {e.errorCode}, Recoverable: {e.recoverable}, Message: {e.msg}")
```

### Performance Monitoring

```nim
import times

template measurePerformance(operation: string, body: untyped): untyped =
  let start = epochTime()
  body
  let duration = (epochTime() - start) * 1000  # Convert to milliseconds
  logPerformanceMetric(operation, duration)

# Usage
measurePerformance("screen_render"):
  buffer.clear()
  ui.render(buffer)
  buffer.drawBuffer()
```

### Health Checks

```nim
proc terminalHealthCheck(): bool =
  try:
    # Check if terminal is responsive
    let (width, height) = getTerminalSize()
    if width <= 0 or height <= 0:
      logError("Invalid terminal dimensions")
      return false
    
    # Check if we can write to terminal
    setCursorPos(0, 0)
    
    # Check raw mode status
    if not isRawModeActive():
      logWarn("Raw mode not active")
      return false
    
    return true
  except:
    logError("Terminal health check failed")
    return false

# Run periodically
proc healthCheckLoop() =
  while running:
    if not terminalHealthCheck():
      logError("Terminal health check failed - initiating recovery")
      # Trigger recovery procedures
    sleep(5000)  # Check every 5 seconds
```

## Performance Optimization

### Buffer Management

```nim
# Reuse buffers to avoid allocation overhead
var screenBuffer: Buffer
var backBuffer: Buffer

proc initBuffers(width, height: int) =
  screenBuffer = newBuffer(width, height)
  backBuffer = newBuffer(width, height)

proc efficientRender() =
  # Clear back buffer
  backBuffer.clear()
  
  # Render to back buffer
  ui.render(backBuffer)
  
  # Swap buffers for next frame
  swap(screenBuffer, backBuffer)
  
  # Draw only differences
  screenBuffer.drawBuffer()
```

### Differential Updates

```nim
# Enable differential updates for better performance
enableFeature("diff_updates", true)

# Track dirty regions for optimized updates
type DirtyRegion = object
  x, y, width, height: int

var dirtyRegions: seq[DirtyRegion]

proc markDirty(x, y, width, height: int) =
  dirtyRegions.add(DirtyRegion(x: x, y: y, width: width, height: height))

proc optimizedUpdate() =
  for region in dirtyRegions:
    # Update only dirty regions
    buffer.drawRegion(region.x, region.y, region.width, region.height)
  dirtyRegions.setLen(0)
```

### Memory Optimization

```nim
# Use object pools for frequently created objects
type ObjectPool[T] = object
  objects: seq[T]
  index: int

proc newObjectPool[T](size: int): ObjectPool[T] =
  result.objects = newSeq[T](size)
  result.index = 0

proc borrow[T](pool: var ObjectPool[T]): var T =
  result = pool.objects[pool.index]
  pool.index = (pool.index + 1) mod pool.objects.len

# Event pool for high-frequency event handling
var eventPool = newObjectPool[Event](1000)

proc processEvents() =
  while true:
    var event = eventPool.borrow()
    if not pollEventInto(event):  # Hypothetical in-place polling
      break
    handleEvent(event)
```

## Security Considerations

### Input Sanitization

```nim
proc sanitizeInput(input: string): string =
  # Remove control characters except allowed ones
  result = ""
  for ch in input:
    if ch.ord >= 32 or ch in ['\n', '\t']:
      result.add(ch)

proc safeTextInput(widget: TextInput, event: KeyEvent) =
  if event.key == KeyNone and event.ch != '\0':
    let sanitized = sanitizeInput($event.ch)
    widget.text.add(sanitized)
```

### Privilege Management

```nim
# Drop unnecessary privileges after initialization
when defined(posix):
  import posix
  
  proc dropPrivileges() =
    # Drop to non-root user if running as root
    if getuid() == 0:
      let uid = getpwnam("myapp").pw_uid
      let gid = getgrnam("myapp").gr_gid
      
      if setgid(gid) != 0 or setuid(uid) != 0:
        raise newException(LibTerminalError, "Failed to drop privileges")
      
      logInfo("Privileges dropped successfully")
```

### Resource Limits

```nim
# Set resource limits to prevent abuse
when defined(posix):
  import posix
  
  proc setResourceLimits() =
    var rlim: RLimit
    
    # Limit memory usage (100MB)
    rlim.rlim_cur = 100 * 1024 * 1024
    rlim.rlim_max = 100 * 1024 * 1024
    discard setrlimit(RLIMIT_AS, rlim.addr)
    
    # Limit file descriptors
    rlim.rlim_cur = 256
    rlim.rlim_max = 256
    discard setrlimit(RLIMIT_NOFILE, rlim.addr)
```

## Deployment Patterns

### Systemd Service

Create `/etc/systemd/system/myapp.service`:

```ini
[Unit]
Description=My Terminal Application
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=myapp
Group=myapp
ExecStart=/usr/local/bin/myapp
Environment=LIBTERMINAL_ENABLE_LOGGING=true
Environment=LIBTERMINAL_LOG_LEVEL=INFO
Environment=LIBTERMINAL_LOG_FILE=/var/log/myapp/terminal.log
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myapp

[Install]
WantedBy=multi-user.target
```

### Docker Deployment

```dockerfile
FROM nimlang/nim:alpine

# Install dependencies
RUN apk add --no-cache ncurses-dev

# Copy application
COPY . /app
WORKDIR /app

# Build application
RUN nimble build -d:release

# Create non-root user
RUN adduser -D -s /bin/sh myapp

# Set up logging
RUN mkdir -p /var/log/myapp && chown myapp:myapp /var/log/myapp

USER myapp

# Environment variables
ENV LIBTERMINAL_ENABLE_LOGGING=true
ENV LIBTERMINAL_LOG_LEVEL=INFO
ENV LIBTERMINAL_LOG_FILE=/var/log/myapp/terminal.log

EXPOSE 8080
CMD ["./myapp"]
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        env:
        - name: LIBTERMINAL_ENABLE_LOGGING
          value: "true"
        - name: LIBTERMINAL_LOG_LEVEL
          value: "INFO"
        - name: LIBTERMINAL_LOG_FILE
          value: "/var/log/myapp/terminal.log"
        volumeMounts:
        - name: logs
          mountPath: /var/log/myapp
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: logs
        emptyDir: {}
```

## Troubleshooting

### Common Issues

#### Raw Mode Initialization Fails

```bash
# Check terminal capabilities
echo $TERM
infocmp $TERM

# Verify terminal device
ls -la /dev/tty*
```

**Solution:**
```nim
# Fallback for limited terminals
proc initWithFallback() =
  try:
    enterRawMode()
  except RawModeError:
    logWarn("Full raw mode unavailable, using minimal mode")
    enterRawMode({RawModeMinimalMode})
```

#### Mouse Events Not Working

**Diagnostics:**
```bash
# Test mouse support manually
printf '\e[?1000h'  # Enable mouse
printf '\e[?1006h'  # Enable SGR format
# Click in terminal - should see escape sequences
printf '\e[?1000l'  # Disable mouse
```

**Solution:**
```nim
proc enableMouseWithFallback(): bool =
  result = enableMouse()
  if not result:
    logWarn("Mouse support not available in this terminal")
    # Continue without mouse support
    result = true
```

#### Performance Issues

**Diagnostics:**
```nim
# Enable performance logging
enableFeature("logging", true)
setLogLevel("DEBUG")

# Monitor buffer operations
logPerformanceMetric("buffer_creation", creationTime)
logPerformanceMetric("differential_update", updateTime)
```

**Solutions:**
1. Reduce refresh rate: `export LIBTERMINAL_REFRESH_RATE=30`
2. Increase buffer size: `export LIBTERMINAL_BUFFER_SIZE=32768`
3. Enable differential updates: `export LIBTERMINAL_ENABLE_DIFF_UPDATES=true`

### Debug Mode

Enable comprehensive debugging:

```nim
when defined(debug):
  proc enableDebugMode() =
    setLogLevel("DEBUG")
    enableFeature("logging", true)
    
    # Log all events
    proc debugEventHandler(event: Event) =
      case event.kind
      of EvKey:
        logDebug(fmt"Key: {event.key.key}, char: {event.key.ch}")
      of EvMouse:
        logDebug(fmt"Mouse: {event.mouse.action} at ({event.mouse.x}, {event.mouse.y})")
      of EvResize:
        logDebug(fmt"Resize: {event.width}x{event.height}")
      else:
        logDebug("Other event")
```

## Monitoring and Alerting

### Metrics Collection

```nim
type Metrics = object
  frameRate: float
  memoryUsage: int
  errorCount: int
  userEvents: int

var metrics: Metrics

proc updateMetrics() =
  # Update frame rate
  metrics.frameRate = calculateFrameRate()
  
  # Update memory usage
  when defined(nimMemStats):
    metrics.memoryUsage = getMemUsage()
  
  # Log metrics periodically
  if frameCounter mod 300 == 0:  # Every 5 seconds at 60 FPS
    logInfo(fmt"Metrics - FPS: {metrics.frameRate:.1f}, Memory: {metrics.memoryUsage} bytes, Errors: {metrics.errorCount}")
```

### Health Endpoints

```nim
# For applications with HTTP interface
proc healthHandler(): string =
  try:
    if terminalHealthCheck():
      return """{"status": "healthy", "terminal": "ok"}"""
    else:
      return """{"status": "unhealthy", "terminal": "failed"}"""
  except:
    return """{"status": "error", "terminal": "exception"}"""

proc readinessHandler(): string =
  if isRawModeActive():
    return """{"status": "ready"}"""
  else:
    return """{"status": "not_ready"}"""
```

## Best Practices Summary

1. **Configuration**: Use environment variables and configuration files
2. **Error Handling**: Implement comprehensive error handling with recovery strategies
3. **Logging**: Enable structured logging for observability
4. **Performance**: Use differential updates and buffer reuse
5. **Security**: Sanitize input and drop unnecessary privileges
6. **Monitoring**: Implement health checks and metrics collection
7. **Deployment**: Use proper service management and resource limits
8. **Testing**: Test on target terminal environments before deployment

## Support and Resources

- **Issues**: Report issues at [GitHub Issues](https://github.com/your-org/nim-libterminal/issues)
- **Documentation**: [API Reference](API_REFERENCE.md)
- **Examples**: See `/examples` directory
- **Community**: [Nim Discord](https://discord.gg/nim) #terminal channel