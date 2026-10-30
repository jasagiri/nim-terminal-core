## 型つきの、値の変化を知らせる入れ物。ウィジェットの状態とアプリのデータをつなぐ。規則は ADR-TC-0001 の B-1〜B-4。

type
  Observer[T] = proc(value: T) {.closure, raises: [].}

  Observable*[T] = ref object
    current: T
    observers: seq[tuple[id: int, call: Observer[T]]]
    nextId: int

  Subscription* = object
    id: int

proc observable*[T](initial: T): Observable[T] {.raises: [].} =
  Observable[T](current: initial)

proc value*[T](o: Observable[T]): T {.raises: [].} = o.current

proc subscribe*[T](o: Observable[T], call: proc(value: T) {.closure, raises: [].}): Subscription {.raises: [].} =
  ## B-1: 値が変わるたびに、新しい値で call を呼ぶ (足した順)。今の値では呼ばない。
  inc o.nextId
  o.observers.add (id: o.nextId, call: Observer[T](call))
  Subscription(id: o.nextId)

proc unsubscribe*[T](o: Observable[T], s: Subscription) {.raises: [].} =
  ## B-2: 以後は呼ばない (知らせている途中に外したものも、次の知らせからは呼ばない)。
  for i, ob in o.observers:
    if ob.id == s.id:
      o.observers.delete(i)
      return

proc set*[T](o: Observable[T], v: T) {.raises: [].} =
  ## B-1、B-4: 値が変わったときだけ知らせる。同じ値を入れても知らせない (両向きにつないでも回り続けない)。
  if o.current == v: return
  o.current = v
  let snapshot = o.observers   # 知らせの途中で足し外しされても、この回は始めの顔ぶれに知らせる
  for ob in snapshot:
    var still = false
    for now in o.observers:
      if now.id == ob.id: still = true
    if still: ob.call(o.current)

proc `value=`*[T](o: Observable[T], v: T) {.raises: [].} = o.set(v)

proc map*[T, U](o: Observable[T], f: proc(v: T): U {.closure, raises: [].}): Observable[U] {.raises: [].} =
  ## B-3: o から f で作る値。o が変わると変わる。
  let derived = observable(f(o.current))
  discard o.subscribe(proc(v: T) = derived.set(f(v)))   # Why discard: 元と同じだけ生きる。外す口は要らない
  derived
