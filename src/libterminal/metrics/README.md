# Metrics Support in libterminal

## Overview

libterminal provides optional 9P protocol support for exposing metrics and debugging information. This allows external tools to monitor and debug running applications without modifying the application code.

## Design Decision

We chose to include 9P support as an **optional feature** within the library rather than requiring external commands because:

1. **Tight Integration**: Direct access to actor internals and message queues
2. **Zero Configuration**: Works out of the box when enabled
3. **Real-time Data**: No serialization/IPC overhead
4. **Opt-in**: Can be completely disabled at compile time with `-d:no9p`

## Usage

### Enabling Metrics

```nim
import libterminal/actors/app_actor
import libterminal/metrics/ninep_actor

# In your app initialization
let metricsServer = spawn(NinePActor, some(app))
app.cast(EnableMetrics(server: metricsServer))
```

### Accessing Metrics

From another terminal:
```bash
# Mount the 9P filesystem
9p -a localhost:9999 ls /metrics/actors/

# Read specific metric
9p -a localhost:9999 read /metrics/actors/actor_1/state

# Monitor continuously
watch -n 1 '9p -a localhost:9999 read /metrics/app/fps'
```

### Available Metrics

- `/metrics/actors/<id>/state` - Actor state (running, stopped, etc.)
- `/metrics/actors/<id>/messages_in` - Messages received
- `/metrics/actors/<id>/messages_out` - Messages sent
- `/metrics/actors/<id>/uptime` - Time since actor started
- `/metrics/actors/<id>/last_error` - Last error message
- `/metrics/app/fps` - Application frame rate
- `/metrics/app/memory` - Memory usage
- `/metrics/app/widgets_count` - Number of active widgets

## Alternative Approaches

If you prefer not to use the built-in 9P support:

1. **JSON Export**: `app.exportMetrics()` returns JSON
2. **Custom Protocol**: Implement your own metrics protocol
3. **File Export**: Write metrics to a file periodically
4. **External Tool**: Use process inspection tools

## Security Considerations

- 9P server binds to localhost by default
- Can be configured to require authentication
- Metrics are read-only by default
- Sensitive data should not be exposed