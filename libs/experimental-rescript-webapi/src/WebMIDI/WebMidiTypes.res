@@warning("-30")

type midiInputMap = {}

type midiOutputMap = {}

type midiAccess = {
  ...EventTypes.eventTarget,
  inputs: midiInputMap,
  outputs: midiOutputMap,
  sysexEnabled: bool,
}

type midiOptions = {
  mutable sysex?: bool,
  mutable software?: bool,
}
