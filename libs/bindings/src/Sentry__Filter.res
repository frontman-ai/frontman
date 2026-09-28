let frontmanFramePatterns = ["frontman", "@frontman-ai"]

let isFrontmanFrame = (filename: string): bool =>
  frontmanFramePatterns->Array.some(pattern =>
    filename->String.toLowerCase->String.includes(pattern)
  )

let hasFrontmanFrames = (event: Sentry__Types.sentryEvent): bool =>
  switch event.exception_ {
  | None => true
  | Some({values: None}) | Some({values: Some([])}) => true
  | Some({values: Some(values)}) =>
    values->Array.some(exceptionValue =>
      switch exceptionValue.stacktrace {
      | None => true
      | Some({frames: None}) | Some({frames: Some([])}) => true
      | Some({frames: Some(frames)}) =>
        frames->Array.some(frame =>
          switch frame.filename {
          | None => false
          | Some(filename) => isFrontmanFrame(filename)
          }
        )
      }
    )
  }

let beforeSend = (event: Sentry__Types.sentryEvent, _hint: Sentry__Types.eventHint): Nullable.t<
  Sentry__Types.sentryEvent,
> =>
  if hasFrontmanFrames(event) {
    Nullable.make(event)
  } else {
    Nullable.null
  }
