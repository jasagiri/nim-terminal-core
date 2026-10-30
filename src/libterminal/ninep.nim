# ninep.nim
## 9P protocol support for metrics

when defined(ninep):
  import ninep/protocol
  import ninep/server
  import ninep/metrics_fs
  
  export protocol
  export server
  export metrics_fs
else:
  # Provide stub types when 9P is disabled
  type
    NinePServerActor* = ref object
    MetricsCollector* = ref object
    UpdateActorStats* = object
    UpdateMetric* = object
    
  template newNinePServerActor*(port: int, collector: ref): ref =
    nil
    
  template newMetricsCollector*(interval: int): ref =
    nil