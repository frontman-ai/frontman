@new
external make: (~options: DomTypes.documentTimelineOptions=?) => DomTypes.documentTimeline =
  "DocumentTimeline"

external asAnimationTimeline: DomTypes.documentTimeline => DomTypes.animationTimeline = "%identity"
