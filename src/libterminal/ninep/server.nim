# ninep/server.nim
## 9P server implementation

import std/asyncnet
import std/asyncdispatch
import std/tables
import std/options
import std/strformat
import std/times
import protocol

type
  FileSystem* = ref object of RootObj
    ## Virtual filesystem interface
    
  File* = ref object
    ## Virtual file representation
    path*: string
    qid*: Qid
    isDir*: bool
    content*: proc(): string
    children*: Table[string, File]
    mode*: uint32
    
  Fid* = ref object
    ## File identifier
    file*: File
    offset*: uint64
    
  Session* = ref object
    ## Client session
    fids*: Table[uint32, Fid]
    msize*: uint32
    version*: string
    
  NinePServer* = ref object
    ## 9P server
    socket*: AsyncSocket
    fs*: FileSystem
    sessions*: Table[AsyncSocket, Session]
    running*: bool

proc newFile*(path: string, isDir = false, 
              content: proc(): string = nil): File =
  result = File(
    path: path,
    isDir: isDir,
    content: content,
    children: initTable[string, File](),
    mode: if isDir: DMDIR or 0o755'u32 else: 0o644'u32
  )
  # Generate unique QID
  result.qid = Qid(
    qtype: if isDir: 0x80'u8 else: 0x00'u8,
    vers: 0,
    path: hash(path).uint64
  )

proc addChild*(parent: File, name: string, child: File) =
  if parent.isDir:
    parent.children[name] = child

proc getFile*(fs: FileSystem, path: string): Option[File] {.base.} =
  ## Get file by path
  none(File)

proc stat*(file: File): Stat =
  ## Get file statistics
  let now = epochTime().uint32
  result = Stat(
    size: 0,  # Will be calculated
    typ: 0,
    dev: 0,
    qid: file.qid,
    mode: file.mode,
    atime: now,
    mtime: now,
    length: if file.isDir: 0 else: file.content().len.uint64,
    name: file.path.split("/")[^1],
    uid: "terminal",
    gid: "terminal",
    muid: "terminal"
  )

proc handleVersion(server: NinePServer, client: AsyncSocket, 
                   msg: NinePMessage): Future[NinePMessage] {.async.} =
  ## Handle Tversion
  let session = Session(
    fids: initTable[uint32, Fid](),
    msize: min(msg.msize, 8192'u32),
    version: if msg.version == Version9P: Version9P else: "unknown"
  )
  server.sessions[client] = session
  
  return NinePMessage(
    kind: Rversion,
    mtype: Rversion,
    tag: msg.tag,
    rmsize: session.msize,
    rversion: session.version
  )

proc handleAttach(server: NinePServer, client: AsyncSocket,
                  msg: NinePMessage): Future[NinePMessage] {.async.} =
  ## Handle Tattach
  let session = server.sessions[client]
  
  # Get root directory
  let rootOpt = server.fs.getFile("/")
  if rootOpt.isNone:
    return errorResponse(msg.tag, "No root directory")
  
  let root = rootOpt.get
  session.fids[msg.fid] = Fid(file: root, offset: 0)
  
  return NinePMessage(
    kind: Rattach,
    mtype: Rattach,
    tag: msg.tag,
    qid: root.qid
  )

proc handleWalk(server: NinePServer, client: AsyncSocket,
                msg: NinePMessage): Future[NinePMessage] {.async.} =
  ## Handle Twalk
  let session = server.sessions[client]
  
  if msg.wfid notin session.fids:
    return errorResponse(msg.tag, "Unknown fid")
  
  var current = session.fids[msg.wfid].file
  var qids: seq[Qid] = @[]
  
  # Walk the path
  for name in msg.wname:
    if not current.isDir:
      break
    if name notin current.children:
      break
    current = current.children[name]
    qids.add(current.qid)
  
  # Create new fid if successful
  if qids.len == msg.wname.len or msg.wname.len == 0:
    session.fids[msg.newfid] = Fid(file: current, offset: 0)
  
  return NinePMessage(
    kind: Rwalk,
    mtype: Rwalk,
    tag: msg.tag,
    nwqid: uint16(qids.len),
    wqid: qids
  )

proc handleOpen(server: NinePServer, client: AsyncSocket,
                msg: NinePMessage): Future[NinePMessage] {.async.} =
  ## Handle Topen
  let session = server.sessions[client]
  
  if msg.ofid notin session.fids:
    return errorResponse(msg.tag, "Unknown fid")
  
  let fid = session.fids[msg.ofid]
  
  return NinePMessage(
    kind: Ropen,
    mtype: Ropen,
    tag: msg.tag,
    oqid: fid.file.qid,
    iounit: session.msize - 24  # Leave room for header
  )

proc handleRead(server: NinePServer, client: AsyncSocket,
                msg: NinePMessage): Future[NinePMessage] {.async.} =
  ## Handle Tread
  let session = server.sessions[client]
  
  if msg.rfid notin session.fids:
    return errorResponse(msg.tag, "Unknown fid")
  
  let fid = session.fids[msg.rfid]
  var data: seq[byte]
  
  if fid.file.isDir:
    # Return directory listing
    var dirData = ""
    for name, child in fid.file.children:
      let stat = child.stat()
      # Simplified - would need proper stat encoding
      dirData.add(fmt"{name}\n")
    data = cast[seq[byte]](dirData)
  else:
    # Return file content
    if fid.file.content != nil:
      let content = fid.file.content()
      let start = min(msg.offset.int, content.len)
      let finish = min(start + msg.count.int, content.len)
      if start < finish:
        data = cast[seq[byte]](content[start..<finish])
  
  return NinePMessage(
    kind: Rread,
    mtype: Rread,
    tag: msg.tag,
    data: data
  )

proc handleStat(server: NinePServer, client: AsyncSocket,
                msg: NinePMessage): Future[NinePMessage] {.async.} =
  ## Handle Tstat
  let session = server.sessions[client]
  
  if msg.sfid notin session.fids:
    return errorResponse(msg.tag, "Unknown fid")
  
  let fid = session.fids[msg.sfid]
  
  return NinePMessage(
    kind: Rstat,
    mtype: Rstat,
    tag: msg.tag,
    stat: fid.file.stat()
  )

proc handleMessage(server: NinePServer, client: AsyncSocket,
                   msg: NinePMessage): Future[NinePMessage] {.async.} =
  ## Route message to appropriate handler
  case msg.kind
  of Tversion:
    return await server.handleVersion(client, msg)
  of Tattach:
    return await server.handleAttach(client, msg)
  of Twalk:
    return await server.handleWalk(client, msg)
  of Topen:
    return await server.handleOpen(client, msg)
  of Tread:
    return await server.handleRead(client, msg)
  of Tstat:
    return await server.handleStat(client, msg)
  else:
    return errorResponse(msg.tag, "Not implemented")

proc handleClient(server: NinePServer, client: AsyncSocket) {.async.} =
  ## Handle client connection
  try:
    while true:
      # Read message size
      let sizeData = await client.recv(4)
      if sizeData.len != 4:
        break
        
      var size: uint32
      littleEndian32(addr size, unsafeAddr sizeData[0])
      
      # Read rest of message
      let msgData = await client.recv(int(size) - 4)
      if msgData.len != int(size) - 4:
        break
      
      # Decode and handle
      let fullData = sizeData & msgData
      let request = decode(cast[seq[byte]](fullData))
      let response = await server.handleMessage(client, request)
      
      # Send response
      let responseData = encode(response)
      await client.send(cast[string](responseData))
      
  except:
    echo "Client error: ", getCurrentExceptionMsg()
  finally:
    server.sessions.del(client)
    client.close()

proc serve*(server: NinePServer, port = 9999) {.async.} =
  ## Start 9P server
  server.socket = newAsyncSocket()
  server.socket.setSockOpt(OptReuseAddr, true)
  server.socket.bindAddr(Port(port))
  server.socket.listen()
  server.running = true
  
  echo fmt"9P server listening on port {port}"
  
  while server.running:
    let client = await server.socket.accept()
    asyncCheck server.handleClient(client)

proc newNinePServer*(fs: FileSystem): NinePServer =
  NinePServer(
    fs: fs,
    sessions: initTable[AsyncSocket, Session](),
    running: false
  )