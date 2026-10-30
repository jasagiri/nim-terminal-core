# ninep/protocol.nim
## 9P2000 protocol implementation

import std/endians
import std/options

type
  # 9P message types
  MessageType* = enum
    Tversion = 100
    Rversion = 101
    Tauth = 102
    Rauth = 103
    Tattach = 104
    Rattach = 105
    Terror = 106
    Rerror = 107
    Tflush = 108
    Rflush = 109
    Twalk = 110
    Rwalk = 111
    Topen = 112
    Ropen = 113
    Tcreate = 114
    Rcreate = 115
    Tread = 116
    Rread = 117
    Twrite = 118
    Rwrite = 119
    Tclunk = 120
    Rclunk = 121
    Tremove = 122
    Rremove = 123
    Tstat = 124
    Rstat = 125
    Twstat = 126
    Rwstat = 127

  Qid* = object
    qtype*: uint8
    vers*: uint32
    path*: uint64

  Stat* = object
    size*: uint16
    typ*: uint16
    dev*: uint32
    qid*: Qid
    mode*: uint32
    atime*: uint32
    mtime*: uint32
    length*: uint64
    name*: string
    uid*: string
    gid*: string
    muid*: string

  NinePMessage* = object
    size*: uint32
    mtype*: MessageType
    tag*: uint16
    case kind*: MessageType
    of Tversion:
      msize*: uint32
      version*: string
    of Rversion:
      rmsize*: uint32
      rversion*: string
    of Tattach:
      fid*: uint32
      afid*: uint32
      uname*: string
      aname*: string
    of Rattach:
      qid*: Qid
    of Twalk:
      wfid*: uint32
      newfid*: uint32
      nwname*: uint16
      wname*: seq[string]
    of Rwalk:
      nwqid*: uint16
      wqid*: seq[Qid]
    of Topen:
      ofid*: uint32
      mode*: uint8
    of Ropen:
      oqid*: Qid
      iounit*: uint32
    of Tread:
      rfid*: uint32
      offset*: uint64
      count*: uint32
    of Rread:
      data*: seq[byte]
    of Tstat:
      sfid*: uint32
    of Rstat:
      stat*: Stat
    of Rerror:
      ename*: string
    else:
      discard

  NinePError* = object of CatchableError

const
  Version9P* = "9P2000"
  NoFid* = uint32.high
  NoTag* = uint16.high
  
  # File modes
  DMDIR* = 0x80000000'u32
  DMREAD* = 0x4'u32
  DMWRITE* = 0x2'u32
  DMEXEC* = 0x1'u32

# Encoding/decoding helpers
proc writeUint32(buf: var seq[byte], val: uint32) =
  var v = val
  littleEndian32(addr buf[buf.len], addr v)
  buf.setLen(buf.len + 4)

proc writeUint16(buf: var seq[byte], val: uint16) =
  var v = val
  littleEndian16(addr buf[buf.len], addr v)
  buf.setLen(buf.len + 2)

proc writeUint8(buf: var seq[byte], val: uint8) =
  buf.add(val)

proc writeString(buf: var seq[byte], s: string) =
  writeUint16(buf, uint16(s.len))
  buf.add(cast[seq[byte]](s))

proc readUint32(buf: seq[byte], pos: var int): uint32 =
  if pos + 4 > buf.len:
    raise newException(NinePError, "Buffer underflow")
  littleEndian32(addr result, unsafeAddr buf[pos])
  inc(pos, 4)

proc readUint16(buf: seq[byte], pos: var int): uint16 =
  if pos + 2 > buf.len:
    raise newException(NinePError, "Buffer underflow")
  littleEndian16(addr result, unsafeAddr buf[pos])
  inc(pos, 2)

proc readUint8(buf: seq[byte], pos: var int): uint8 =
  if pos + 1 > buf.len:
    raise newException(NinePError, "Buffer underflow")
  result = buf[pos]
  inc(pos)

proc readString(buf: seq[byte], pos: var int): string =
  let len = readUint16(buf, pos).int
  if pos + len > buf.len:
    raise newException(NinePError, "Buffer underflow")
  result = newString(len)
  if len > 0:
    copyMem(addr result[0], unsafeAddr buf[pos], len)
  inc(pos, len)

# Message encoding
proc encode*(msg: NinePMessage): seq[byte] =
  result = newSeq[byte](4 + 1 + 2)  # size + type + tag
  
  # We'll write size at the end
  writeUint8(result, msg.mtype.uint8)
  writeUint16(result, msg.tag)
  
  case msg.kind
  of Tversion:
    writeUint32(result, msg.msize)
    writeString(result, msg.version)
  of Rversion:
    writeUint32(result, msg.rmsize)
    writeString(result, msg.rversion)
  of Tattach:
    writeUint32(result, msg.fid)
    writeUint32(result, msg.afid)
    writeString(result, msg.uname)
    writeString(result, msg.aname)
  of Rattach:
    writeUint8(result, msg.qid.qtype)
    writeUint32(result, msg.qid.vers)
    writeUint64(result, msg.qid.path)
  of Rerror:
    writeString(result, msg.ename)
  of Tread:
    writeUint32(result, msg.rfid)
    writeUint64(result, msg.offset)
    writeUint32(result, msg.count)
  of Rread:
    writeUint32(result, uint32(msg.data.len))
    result.add(msg.data)
  else:
    discard
  
  # Write total size at the beginning
  var size = uint32(result.len)
  littleEndian32(addr result[0], addr size)

proc writeUint64(buf: var seq[byte], val: uint64) =
  var v = val
  littleEndian64(addr buf[buf.len], addr v)
  buf.setLen(buf.len + 8)

proc readUint64(buf: seq[byte], pos: var int): uint64 =
  if pos + 8 > buf.len:
    raise newException(NinePError, "Buffer underflow")
  littleEndian64(addr result, unsafeAddr buf[pos])
  inc(pos, 8)

# Message decoding
proc decode*(buf: seq[byte]): NinePMessage =
  var pos = 0
  
  result.size = readUint32(buf, pos)
  result.mtype = MessageType(readUint8(buf, pos))
  result.tag = readUint16(buf, pos)
  result.kind = result.mtype
  
  case result.kind
  of Tversion:
    result.msize = readUint32(buf, pos)
    result.version = readString(buf, pos)
  of Tattach:
    result.fid = readUint32(buf, pos)
    result.afid = readUint32(buf, pos)
    result.uname = readString(buf, pos)
    result.aname = readString(buf, pos)
  of Twalk:
    result.wfid = readUint32(buf, pos)
    result.newfid = readUint32(buf, pos)
    result.nwname = readUint16(buf, pos)
    result.wname = newSeq[string](result.nwname)
    for i in 0..<result.nwname:
      result.wname[i] = readString(buf, pos)
  of Topen:
    result.ofid = readUint32(buf, pos)
    result.mode = readUint8(buf, pos)
  of Tread:
    result.rfid = readUint32(buf, pos)
    result.offset = readUint64(buf, pos)
    result.count = readUint32(buf, pos)
  of Tstat:
    result.sfid = readUint32(buf, pos)
  else:
    discard

# Helper to create error response
proc errorResponse*(tag: uint16, msg: string): NinePMessage =
  NinePMessage(
    kind: Rerror,
    mtype: Rerror,
    tag: tag,
    ename: msg
  )