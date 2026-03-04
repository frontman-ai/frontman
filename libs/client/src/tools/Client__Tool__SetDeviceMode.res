// Client tool that sets the device emulation mode in the web preview
// Allows the agent to simulate mobile/tablet/desktop viewports

S.enableJson()
module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.setDeviceMode
let visibleToAgent = true
let description = `Set the device emulation mode in the web preview for responsive design testing.

Actions:
- **set_preset**: Switch to a named device preset. Pass {"action": "set_preset", "device": "iPhone 15 Pro"}
- **set_custom**: Set custom viewport dimensions. Pass {"action": "set_custom", "width": 400, "height": 800}
- **set_responsive**: Return to responsive (full-width) mode. Pass {"action": "set_responsive"}
- **set_orientation**: Change orientation. Pass {"action": "set_orientation", "orientation": "landscape"}
- **get_current**: Get the current device mode and dimensions. Pass {"action": "get_current"}
- **list_presets**: List all available device presets. Pass {"action": "list_presets"}

Available presets: iPhone SE, iPhone 15 Pro, iPhone 15 Pro Max, Pixel 8, Samsung Galaxy S24, iPad Mini, iPad Air, iPad Pro 11", iPad Pro 12.9", Laptop, Laptop L, 4K`

@schema
type input = {
  @s.describe("Action: 'set_preset', 'set_custom', 'set_responsive', 'set_orientation', 'get_current', or 'list_presets'")
  action: [#set_preset | #set_custom | #set_responsive | #set_orientation | #get_current | #list_presets],
  @s.describe("Device preset name, case-insensitive (required for 'set_preset'). E.g. 'iPhone 15 Pro', 'iPad Mini'")
  device: option<string>,
  @s.describe("Viewport width in CSS pixels (required for 'set_custom')")
  width: option<int>,
  @s.describe("Viewport height in CSS pixels (required for 'set_custom')")
  height: option<int>,
  @s.describe("Orientation: 'portrait' or 'landscape' (required for 'set_orientation')")
  orientation: option<string>,
}

@schema
type output = {
  @s.describe("Whether the action was performed successfully")
  success: bool,
  @s.describe("Current device mode after the action")
  currentMode: option<string>,
  @s.describe("Current viewport dimensions (width x height) after the action")
  currentDimensions: option<string>,
  @s.describe("Current orientation after the action")
  currentOrientation: option<string>,
  @s.describe("Available device presets with dimensions (only for 'list_presets')")
  presets: option<array<string>>,
  @s.describe("Error message if the action failed")
  error: option<string>,
}

// Find a preset by name (case-insensitive exact match)
let findPresetByName = (name: string): option<Client__DeviceMode.devicePreset> => {
  let lowerName = name->String.toLowerCase
  Client__DeviceMode.presets->Array.find(preset =>
    preset.name->String.toLowerCase == lowerName
  )
}

// Build output with current state info
let makeOutput = (
  ~success: bool,
  ~error: option<string>,
  ~presets: option<array<string>>,
): output => {
  let state = StateStore.getState(Client__State__Store.store)
  let deviceMode = Client__State__StateReducer.Selectors.deviceMode(state)
  let orientation = Client__State__StateReducer.Selectors.deviceOrientation(state)
  let effectiveDims = Client__DeviceMode.getEffectiveDimensions(deviceMode, orientation)

  {
    success,
    currentMode: Some(Client__DeviceMode.getDeviceName(deviceMode)),
    currentDimensions: switch effectiveDims {
    | Some((w, h)) => Some(`${Int.toString(w)}x${Int.toString(h)}`)
    | None => Some("responsive (fills available space)")
    },
    currentOrientation: Some(Client__DeviceMode.orientationToString(orientation)),
    presets,
    error,
  }

}

let okOutput = (~success, ~error) => Ok(makeOutput(~success, ~error, ~presets=None))
let okOutputWithPresets = (~success, ~presets) => Ok(makeOutput(~success, ~error=None, ~presets=Some(presets)))

let execute = async (input: input): toolResult<output> => {
  switch input.action {
  | #set_preset =>
    switch input.device {
    | None =>
      okOutput(~success=false, ~error=Some("'device' is required for set_preset action"))
    | Some(deviceName) =>
      switch findPresetByName(deviceName) {
      | None =>
        let available = Client__DeviceMode.presets->Array.map(p => p.name)->Array.join(", ")
        okOutput(
          ~success=false,
          ~error=Some(`Device preset '${deviceName}' not found. Available: ${available}`),
        )
      | Some(preset) =>
        Client__State.Actions.setDeviceMode(~deviceMode=Client__DeviceMode.DevicePreset(preset))
        okOutput(~success=true, ~error=None)
      }
    }

  | #set_custom =>
    switch (input.width, input.height) {
    | (Some(w), Some(h)) =>
      if w <= 0 || h <= 0 {
        okOutput(~success=false, ~error=Some("Width and height must be positive integers"))
      } else {
        Client__State.Actions.setDeviceMode(~deviceMode=Client__DeviceMode.CustomSize({width: w, height: h}))
        okOutput(~success=true, ~error=None)
      }
    | (None, _) | (_, None) =>
      okOutput(~success=false, ~error=Some("Both 'width' and 'height' are required for set_custom action"))
    }

  | #set_responsive =>
    Client__State.Actions.setDeviceMode(~deviceMode=Client__DeviceMode.Responsive)
    okOutput(~success=true, ~error=None)

  | #set_orientation =>
    switch input.orientation {
    | None =>
      okOutput(~success=false, ~error=Some("'orientation' is required for set_orientation action"))
    | Some(oriStr) =>
      switch oriStr->String.toLowerCase {
      | "portrait" =>
        Client__State.Actions.setOrientation(~orientation=Client__DeviceMode.Portrait)
        okOutput(~success=true, ~error=None)
      | "landscape" =>
        Client__State.Actions.setOrientation(~orientation=Client__DeviceMode.Landscape)
        okOutput(~success=true, ~error=None)
      | _ =>
        okOutput(~success=false, ~error=Some("Orientation must be 'portrait' or 'landscape'"))
      }
    }

  | #get_current =>
    okOutput(~success=true, ~error=None)

  | #list_presets =>
    let presetStrings = Client__DeviceMode.presets->Array.map(p =>
      `${p.name} (${Int.toString(p.width)}x${Int.toString(p.height)}, ${p.category})`
    )
    okOutputWithPresets(~success=true, ~presets=presetStrings)
  }
}
