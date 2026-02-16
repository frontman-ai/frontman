// Device bar - secondary toolbar showing device mode controls
// Only visible when device mode is active (not Responsive)

module RadixUI__Icons = Bindings__RadixUI__Icons
module DropdownMenu = Bindings__UI__DropdownMenu

module DimensionInput = {
  @react.component
  let make = (~value: int, ~onChange: int => unit, ~label: string) => {
    let (localValue, setLocalValue) = React.useState(() => Int.toString(value))

    // Sync from external changes
    React.useEffect(() => {
      setLocalValue(_ => Int.toString(value))
      None
    }, [value])

    let handleBlur = _ => {
      switch Int.fromString(localValue) {
      | Some(v) if v > 0 => onChange(v)
      | _ => setLocalValue(_ => Int.toString(value))
      }
    }

    let handleKeyDown = (e: ReactEvent.Keyboard.t) => {
      if ReactEvent.Keyboard.key(e) == "Enter" {
        switch Int.fromString(localValue) {
        | Some(v) if v > 0 => onChange(v)
        | _ => setLocalValue(_ => Int.toString(value))
        }
      }
    }

    <input
      type_="text"
      value={localValue}
      onChange={e => setLocalValue(_ => ReactEvent.Form.target(e)["value"])}
      onBlur={handleBlur}
      onKeyDown={handleKeyDown}
      className="w-14 h-6 px-1.5 text-xs text-center bg-white border border-gray-200 rounded
                 text-gray-700 focus:outline-none focus:ring-1 focus:ring-blue-500/50 focus:border-blue-500/50
                 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
      title={label}
    />
  }
}

@react.component
let make = (
  ~deviceMode: Client__DeviceMode.deviceMode,
  ~orientation: Client__DeviceMode.orientation,
) => {
  let effectiveDims = Client__DeviceMode.getEffectiveDimensions(deviceMode, orientation)

  switch effectiveDims {
  | None => React.null // Responsive mode - no bar
  | Some((width, height)) =>
    let deviceName = Client__DeviceMode.getDeviceName(deviceMode)
    let categories = Client__DeviceMode.presetsByCategory()

    <div
      className="flex items-center gap-2 px-3 py-1.5 bg-gray-50 border-b border-gray-200 text-xs"
    >
      // Device preset dropdown
      <DropdownMenu.DropdownMenu>
        <DropdownMenu.DropdownMenuTrigger asChild=true>
          <button
            type_="button"
            className="flex items-center gap-1 h-6 px-2 rounded text-xs font-medium
                       text-gray-600 hover:text-gray-800 hover:bg-gray-200 transition-colors"
          >
            {React.string(deviceName)}
            <RadixUI__Icons.ChevronDownIcon className="size-3" />
          </button>
        </DropdownMenu.DropdownMenuTrigger>
        <DropdownMenu.DropdownMenuContent align="start" sideOffset=4 className="min-w-[180px]">
          // Responsive option
          <DropdownMenu.DropdownMenuItem
            onSelect={_ => Client__State.Actions.setDeviceMode(~deviceMode=Client__DeviceMode.Responsive)}
          >
            <div className="flex items-center gap-2">
              <RadixUI__Icons.DesktopIcon className="size-3.5 text-gray-500" />
              {React.string("Responsive")}
            </div>
          </DropdownMenu.DropdownMenuItem>
          <DropdownMenu.DropdownMenuSeparator />
          // Device presets by category
          {categories
          ->Array.mapWithIndex(((category, devices), idx) => {
            <React.Fragment key={category}>
              <DropdownMenu.DropdownMenuLabel>
                {React.string(category)}
              </DropdownMenu.DropdownMenuLabel>
              {devices
              ->Array.map(preset => {
                let isSelected = switch deviceMode {
                | Client__DeviceMode.DevicePreset(p) => p.name == preset.name
                | _ => false
                }
                <DropdownMenu.DropdownMenuItem
                  key={preset.name}
                  onSelect={_ =>
                    Client__State.Actions.setDeviceMode(
                      ~deviceMode=Client__DeviceMode.DevicePreset(preset),
                    )}
                >
                  <div className="flex items-center justify-between w-full">
                    <span>{React.string(preset.name)}</span>
                    <span className="text-gray-400 ml-2">
                      {React.string(`${Int.toString(preset.width)}x${Int.toString(preset.height)}`)}
                    </span>
                    {isSelected
                      ? <RadixUI__Icons.CheckIcon className="size-3.5 ml-1 text-violet-600" />
                      : React.null}
                  </div>
                </DropdownMenu.DropdownMenuItem>
              })
              ->React.array}
              {idx < Array.length(categories) - 1
                ? <DropdownMenu.DropdownMenuSeparator />
                : React.null}
            </React.Fragment>
          })
          ->React.array}
        </DropdownMenu.DropdownMenuContent>
      </DropdownMenu.DropdownMenu>
      // Separator
      <div className="w-px h-4 bg-gray-300" />
      // Width x Height inputs
      <div className="flex items-center gap-1">
        <DimensionInput
          value={width}
          label="Width"
          onChange={w => {
            switch orientation {
            | Portrait =>
              Client__State.Actions.setDeviceMode(
                ~deviceMode=Client__DeviceMode.CustomSize({width: w, height}),
              )
            | Landscape =>
              Client__State.Actions.setDeviceMode(
                ~deviceMode=Client__DeviceMode.CustomSize({width: height, height: w}),
              )
            }
          }}
        />
        <span className="text-gray-400"> {React.string("x")} </span>
        <DimensionInput
          value={height}
          label="Height"
          onChange={h => {
            switch orientation {
            | Portrait =>
              Client__State.Actions.setDeviceMode(
                ~deviceMode=Client__DeviceMode.CustomSize({width, height: h}),
              )
            | Landscape =>
              Client__State.Actions.setDeviceMode(
                ~deviceMode=Client__DeviceMode.CustomSize({width: h, height: width}),
              )
            }
          }}
        />
      </div>
      // Separator
      <div className="w-px h-4 bg-gray-300" />
      // Rotate button
      <button
        type_="button"
        onClick={_ => {
          let newOrientation = switch orientation {
          | Portrait => Client__DeviceMode.Landscape
          | Landscape => Client__DeviceMode.Portrait
          }
          Client__State.Actions.setOrientation(~orientation=newOrientation)
        }}
        className="flex items-center justify-center w-6 h-6 rounded
                   text-gray-500 hover:text-gray-700 hover:bg-gray-200 transition-colors"
        title={switch orientation {
        | Portrait => "Rotate to landscape"
        | Landscape => "Rotate to portrait"
        }}
      >
        <RadixUI__Icons.UpdateIcon className="size-3.5" />
      </button>
      // DPR indicator (if preset with DPR)
      {switch Client__DeviceMode.getDeviceDpr(deviceMode) {
      | Some(dpr) =>
        <span className="text-gray-400 ml-1" title="Device pixel ratio">
          {React.string(`DPR ${Float.toFixed(dpr, ~digits=1)}`)}
        </span>
      | None => React.null
      }}
    </div>
  }
}
