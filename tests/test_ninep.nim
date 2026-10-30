# test_ninep.nim
## Tests for 9P protocol implementation

when defined(ninep):
  import unittest
  import std/asyncdispatch
  import std/tables
  import std/options
  import ../src/libterminal/ninep/protocol
  import ../src/libterminal/ninep/server
  import ../src/libterminal/ninep/metrics_fs
  import ../src/libterminal/actors/actor

  suite "9P Protocol":
    test "Message encoding and decoding":
      # Test Tversion
      let tversion = NinePMessage(
        kind: Tversion,
        mtype: Tversion,
        tag: 1,
        msize: 8192,
        version: Version9P
      )
      
      let encoded = encode(tversion)
      let decoded = decode(encoded)
      
      check decoded.kind == Tversion
      check decoded.tag == 1
      check decoded.msize == 8192
      check decoded.version == Version9P
    
    test "Error response":
      let err = errorResponse(42, "Test error")
      check err.kind == Rerror
      check err.tag == 42
      check err.ename == "Test error"
    
    test "Qid creation":
      let qid = Qid(
        qtype: 0x80,
        vers: 1,
        path: 12345
      )
      check qid.qtype == 0x80
      check qid.vers == 1
      check qid.path == 12345
    
    test "Multiple message types":
      # Test Tattach
      let tattach = NinePMessage(
        kind: Tattach,
        mtype: Tattach,
        tag: 2,
        fid: 100,
        afid: NoFid,
        uname: "test",
        aname: ""
      )
      
      let encoded = encode(tattach)
      let decoded = decode(encoded)
      
      check decoded.kind == Tattach
      check decoded.fid == 100
      check decoded.afid == NoFid
      check decoded.uname == "test"
      check decoded.aname == ""

  suite "9P File System":
    test "File creation":
      let file = newFile("/test", false, proc(): string = "content")
      check file.path == "/test"
      check file.isDir == false
      check file.content() == "content"
      check file.qid.qtype == 0x00
    
    test "Directory creation":
      let dir = newFile("/dir", true)
      check dir.path == "/dir"
      check dir.isDir == true
      check dir.qid.qtype == 0x80
    
    test "File hierarchy":
      let root = newFile("/", true)
      let subdir = newFile("subdir", true)
      let file = newFile("test.txt", false, proc(): string = "hello")
      
      root.addChild("subdir", subdir)
      subdir.addChild("test.txt", file)
      
      check root.children.len == 1
      check root.children.hasKey("subdir")
      check subdir.children.len == 1
      check subdir.children.hasKey("test.txt")
    
    test "File stats":
      let file = newFile("test", false, proc(): string = "12345")
      let stat = file.stat()
      
      check stat.name == "test"
      check stat.qid.path == file.qid.path
      check stat.length == 5
      check stat.mode == 0o644'u32

  suite "Metrics File System":
    test "Metrics FS creation":
      var actorStats = initTable[string, ActorStats]()
      var appMetrics = initTable[string, string]()
      
      let fs = newMetricsFS(addr actorStats, addr appMetrics)
      check fs.root.isDir == true
      check fs.root.children.hasKey("actors")
      check fs.root.children.hasKey("app")
      check fs.root.children.hasKey("version")
    
    test "Actor stats files":
      let stats = ActorStats(
        messagesReceived: 10,
        messagesSent: 5,
        lastError: "none",
        state: asRunning,
        uptime: 100.5
      )
      
      let files = createActorFiles(stats)
      check files.len == 5
      check files["state"].content() == "asRunning"
      check files["messages_in"].content() == "10"
      check files["messages_out"].content() == "5"
      check files["last_error"].content() == "none"
      check files["uptime"].content() == "100.50s"
    
    test "File tree building":
      var actorStats = initTable[string, ActorStats]()
      var appMetrics = initTable[string, string]()
      
      actorStats["actor_1"] = ActorStats(
        messagesReceived: 100,
        state: asRunning,
        uptime: 50.0
      )
      
      appMetrics["fps"] = "60"
      appMetrics["memory"] = "1024MB"
      
      let fs = newMetricsFS(addr actorStats, addr appMetrics)
      fs.buildFileTree()
      
      # Check structure
      check fs.root.children["actors"].children.hasKey("actor_1")
      check fs.root.children["app"].children.hasKey("fps")
      check fs.root.children["app"].children.hasKey("memory")
    
    test "Path resolution":
      var actorStats = initTable[string, ActorStats]()
      var appMetrics = initTable[string, string]()
      
      let fs = newMetricsFS(addr actorStats, addr appMetrics)
      
      # Test root
      let rootOpt = fs.getFile("/")
      check rootOpt.isSome
      check rootOpt.get.path == "/"
      
      # Test subdirectory
      let actorsOpt = fs.getFile("/actors")
      check actorsOpt.isSome
      check actorsOpt.get.isDir
      
      # Test non-existent
      let noneOpt = fs.getFile("/nonexistent")
      check noneOpt.isNone

  suite "Metrics Collector":
    test "Collector creation":
      let collector = newMetricsCollector(500)
      check collector.updateInterval == 500
      check collector.stats.len == 0
      check collector.appMetrics.len == 0
    
    test "Stats update":
      let collector = newMetricsCollector()
      let update = UpdateActorStats(
        actorId: "test_actor",
        stats: ActorStats(
          messagesReceived: 42,
          state: asRunning
        )
      )
      
      # Simulate update
      collector.stats[update.actorId] = update.stats
      check collector.stats.len == 1
      check collector.stats["test_actor"].messagesReceived == 42

  suite "9P Server Actor":
    test "Server actor creation":
      let collector = spawn(MetricsCollector)
      let server = newNinePServerActor(9999, collector)
      
      check server.port == 9999
      check server.metricsCollector == collector

else:
  # When 9P is disabled
  import unittest
  
  suite "9P Protocol (disabled)":
    test "9P compilation flag":
      check not defined(ninep)