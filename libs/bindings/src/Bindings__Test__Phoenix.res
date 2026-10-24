type mockChannel = {
  push: (string, JSON.t) => Phoenix.pushResponse,
  on: (string, JSON.t => unit) => unit,
  off: unit => unit,
}

external toChannel: mockChannel => Phoenix.channel = "%identity"

@obj
external makeRecordingChannel: (~on: (string, JSON.t => unit) => int) => Phoenix.channel = ""
