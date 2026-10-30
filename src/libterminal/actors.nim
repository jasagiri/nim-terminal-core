# actors.nim
## Actor-based terminal UI framework

import actors/actor
import actors/widget_actor
import actors/app_actor

when defined(ninep):
  import actors/actor_metrics
  
export actor
export widget_actor
export app_actor

when defined(ninep):
  export actor_metrics