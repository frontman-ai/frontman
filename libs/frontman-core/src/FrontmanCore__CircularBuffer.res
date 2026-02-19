// Generic circular buffer for fixed-size FIFO storage
// Used by LogCapture and potentially other modules that need bounded collections

type t<'a> = {
  data: array<option<'a>>,
  writeIndex: int,
  count: int,
  maxSize: int,
}

let make = (~capacity: int): t<'a> => {
  data: Array.make(~length=capacity, None),
  writeIndex: 0,
  count: 0,
  maxSize: capacity,
}

let push = (buffer: t<'a>, entry: 'a): t<'a> => {
  buffer.data[buffer.writeIndex] = Some(entry)

  {
    data: buffer.data,
    writeIndex: mod(buffer.writeIndex + 1, buffer.maxSize),
    count: min(buffer.count + 1, buffer.maxSize),
    maxSize: buffer.maxSize,
  }
}

let toArray = (buffer: t<'a>): array<'a> => {
  switch buffer.count {
  | 0 => []
  | c if c < buffer.maxSize =>
    buffer.data->Array.slice(~start=0, ~end=buffer.count)->Array.filterMap(x => x)
  | _ =>
    let tail =
      buffer.data
      ->Array.slice(~start=buffer.writeIndex, ~end=buffer.maxSize)
      ->Array.filterMap(x => x)
    let head =
      buffer.data->Array.slice(~start=0, ~end=buffer.writeIndex)->Array.filterMap(x => x)
    Array.concat(tail, head)
  }
}

let length = (buffer: t<'a>): int => buffer.count

let clear = (buffer: t<'a>): t<'a> => {
  data: Array.make(~length=buffer.maxSize, None),
  writeIndex: 0,
  count: 0,
  maxSize: buffer.maxSize,
}
