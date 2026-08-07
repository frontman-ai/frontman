@@warning("-30")

@editor.completeFrom(MessagePort)
type messagePort = private {
  ...EventTypes.eventTarget,
}

type structuredSerializeOptions = {mutable transfer?: array<Dict.t<string>>}
