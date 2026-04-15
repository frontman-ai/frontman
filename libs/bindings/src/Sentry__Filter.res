// Shared Sentry event filter for all Frontman libraries
// Drops error events that don't originate from Frontman code, preventing
// third-party errors (e.g. Next.js/Turbopack internals) from polluting our Sentry project.

// Patterns that identify Frontman frames in stacktraces
let frontmanFramePatterns = ["frontman", "@frontman-ai"]

// Check if a filename belongs to Frontman code
let isFrontmanFrame = (filename: string): bool =>
  frontmanFramePatterns->Array.some(pattern =>
    filename->String.toLowerCase->String.includes(pattern)
  )

// Check if an event has at least one Frontman frame in any exception stacktrace.
// Events without exception data (e.g. captureMessage) are always kept.
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

// beforeSend filter: drop events that don't originate from Frontman code.
// This prevents third-party errors caught by Sentry's global handlers from
// polluting our project.
let beforeSend = (event: Sentry__Types.sentryEvent, _hint: Sentry__Types.eventHint): Nullable.t<
  Sentry__Types.sentryEvent,
> =>
  if hasFrontmanFrames(event) {
    Nullable.make(event)
  } else {
    Nullable.null
  }
