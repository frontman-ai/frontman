@@warning("-30")

open EventAPI

/**
[See MIDIInputMap on MDN](https://developer.mozilla.org/docs/Web/API/MIDIInputMap)
*/
type midiInputMap = {}

/**
[See MIDIOutputMap on MDN](https://developer.mozilla.org/docs/Web/API/MIDIOutputMap)
*/
type midiOutputMap = {}

/**
[See MIDIAccess on MDN](https://developer.mozilla.org/docs/Web/API/MIDIAccess)
*/
type midiAccess = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MIDIAccess/inputs)
    */
  inputs: midiInputMap,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MIDIAccess/outputs)
    */
  outputs: midiOutputMap,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MIDIAccess/sysexEnabled)
    */
  sysexEnabled: bool,
}

type midiOptions = {
  mutable sysex?: bool,
  mutable software?: bool,
}
