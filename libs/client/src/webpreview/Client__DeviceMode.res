type devicePreset = {
  name: string,
  category: string,
  width: int,
  height: int,
  dpr: float,
}

type deviceMode =
  | Responsive
  | CustomSize({width: int, height: int})
  | DevicePreset(devicePreset)

type orientation =
  | Portrait
  | Landscape

let presets: array<devicePreset> = [
  {name: "iPhone SE", category: "Phones", width: 375, height: 667, dpr: 2.0},
  {name: "iPhone 15 Pro", category: "Phones", width: 393, height: 852, dpr: 3.0},
  {name: "iPhone 15 Pro Max", category: "Phones", width: 430, height: 932, dpr: 3.0},
  {name: "Pixel 8", category: "Phones", width: 412, height: 924, dpr: 2.625},
  {name: "Samsung Galaxy S24", category: "Phones", width: 360, height: 780, dpr: 3.0},
  {name: "iPad Mini", category: "Tablets", width: 768, height: 1024, dpr: 2.0},
  {name: "iPad Air", category: "Tablets", width: 820, height: 1180, dpr: 2.0},
  {name: "iPad Pro 11\"", category: "Tablets", width: 834, height: 1194, dpr: 2.0},
  {name: "iPad Pro 12.9\"", category: "Tablets", width: 1024, height: 1366, dpr: 2.0},
  {name: "Laptop", category: "Desktop", width: 1024, height: 768, dpr: 1.0},
  {name: "Laptop L", category: "Desktop", width: 1440, height: 900, dpr: 1.0},
  {name: "4K", category: "Desktop", width: 2560, height: 1440, dpr: 1.0},
]

let getEffectiveDimensions = (deviceMode: deviceMode, orientation: orientation): option<(
  int,
  int,
)> =>
  switch deviceMode {
  | Responsive => None
  | CustomSize({width, height}) =>
    switch orientation {
    | Portrait => Some((width, height))
    | Landscape => Some((height, width))
    }
  | DevicePreset({width, height}) =>
    switch orientation {
    | Portrait => Some((width, height))
    | Landscape => Some((height, width))
    }
  }

let getDeviceName = (deviceMode: deviceMode): string =>
  switch deviceMode {
  | Responsive => "Responsive"
  | CustomSize({width, height}) => `${Int.toString(width)} x ${Int.toString(height)}`
  | DevicePreset({name}) => name
  }

let getDeviceDpr = (deviceMode: deviceMode): option<float> =>
  switch deviceMode {
  | Responsive => None
  | CustomSize(_) => None
  | DevicePreset({dpr}) => Some(dpr)
  }

let computeScaleFactor = (
  ~deviceWidth: int,
  ~deviceHeight: int,
  ~availableWidth: int,
  ~availableHeight: int,
): float => {
  let scaleX = Int.toFloat(availableWidth) /. Int.toFloat(deviceWidth)
  let scaleY = Int.toFloat(availableHeight) /. Int.toFloat(deviceHeight)
  Math.min(Math.min(scaleX, scaleY), 1.0)
}

let presetsByCategory = (): array<(string, array<devicePreset>)> => {
  let groups = Dict.make()
  presets->Array.forEach(preset => {
    let existing = groups->Dict.get(preset.category)->Option.getOr([])
    groups->Dict.set(preset.category, Array.concat(existing, [preset]))
  })
  ["Phones", "Tablets", "Desktop"]->Array.filterMap(category =>
    groups->Dict.get(category)->Option.map(devices => (category, devices))
  )
}

let isActive = (deviceMode: deviceMode): bool =>
  switch deviceMode {
  | Responsive => false
  | CustomSize(_) | DevicePreset(_) => true
  }

let defaultDeviceMode = Responsive
let defaultOrientation = Portrait

let deviceModeToJson = (deviceMode: deviceMode): JSON.t => {
  let obj = Dict.make()
  switch deviceMode {
  | Responsive => obj->Dict.set("type", JSON.Encode.string("responsive"))
  | CustomSize({width, height}) =>
    obj->Dict.set("type", JSON.Encode.string("custom"))
    obj->Dict.set("width", JSON.Encode.int(width))
    obj->Dict.set("height", JSON.Encode.int(height))
  | DevicePreset({name, category, width, height, dpr}) =>
    obj->Dict.set("type", JSON.Encode.string("preset"))
    obj->Dict.set("name", JSON.Encode.string(name))
    obj->Dict.set("category", JSON.Encode.string(category))
    obj->Dict.set("width", JSON.Encode.int(width))
    obj->Dict.set("height", JSON.Encode.int(height))
    obj->Dict.set("dpr", JSON.Encode.float(dpr))
  }
  JSON.Encode.object(obj)
}

let orientationToJson = (orientation: orientation): JSON.t =>
  switch orientation {
  | Portrait => JSON.Encode.string("portrait")
  | Landscape => JSON.Encode.string("landscape")
  }

let orientationToString = (orientation: orientation): string =>
  switch orientation {
  | Portrait => "portrait"
  | Landscape => "landscape"
  }

let storageKeyDeviceMode = "frontman:device-mode"
let storageKeyOrientation = "frontman:device-orientation"

let persist = (deviceMode: deviceMode, orientation: orientation): unit => {
  try {
    let storage = WebAPI.Window.current->WebAPI.Window.localStorage
    storage->WebAPI.Storage.setItem(
      ~key=storageKeyDeviceMode,
      ~value=JSON.stringify(deviceModeToJson(deviceMode)),
    )
    storage->WebAPI.Storage.setItem(
      ~key=storageKeyOrientation,
      ~value=JSON.stringify(orientationToJson(orientation)),
    )
  } catch {
  | _ => ()
  }
}
