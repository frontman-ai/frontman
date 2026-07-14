let underlyingSource: FileTypes.underlyingSource<string> = Obj.magic()
let strategy: FileTypes.queuingStrategy<string> = Obj.magic()

let _make: ReadableStream.t<string> = ReadableStream.make()

let _fromUnderlyingSource = ReadableStream.fromUnderlyingSource(underlyingSource)

let _fromUnderlyingSourceWithStrategy = ReadableStream.fromUnderlyingSource(
  underlyingSource,
  ~strategy,
)
