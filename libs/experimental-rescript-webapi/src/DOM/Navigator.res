type t = DomTypes.navigator

@get external clipboard: t => ClipboardTypes.clipboard = "clipboard"

@get external credentials: t => CredentialManagementTypes.credentialsContainer = "credentials"

@get external geolocation: t => GeolocationTypes.geolocation = "geolocation"

@get external userActivation: t => DomTypes.userActivation = "userActivation"

@get external mediaCapabilities: t => MediaCapabilitiesTypes.mediaCapabilities = "mediaCapabilities"

@get external mediaDevices: t => MediaCaptureAndStreamsTypes.mediaDevices = "mediaDevices"

@get external mediaSession: t => MediaSessionTypes.mediaSession = "mediaSession"

@get external permissions: t => PermissionsTypes.permissions = "permissions"

@get external maxTouchPoints: t => int = "maxTouchPoints"

@get external wakeLock: t => ScreenWakeLockTypes.wakeLock = "wakeLock"

@get external serviceWorker: t => ServiceWorkerTypes.serviceWorkerContainer = "serviceWorker"

@get external userAgent: t => string = "userAgent"

@get external language: t => string = "language"
@get external languages: t => array<string> = "languages"
@get external onLine: t => bool = "onLine"
@get external cookieEnabled: t => bool = "cookieEnabled"
@get external pdfViewerEnabled: t => bool = "pdfViewerEnabled"
@get external hardwareConcurrency: t => int = "hardwareConcurrency"
@get external storage: t => StorageTypes.storageManager = "storage"
@get external locks: t => WebLocksTypes.lockManager = "locks"
@get external webdriver: t => bool = "webdriver"

@send
external sendBeacon: (t, ~url: string, ~data: FileTypes.readableStream<unit>=?) => bool =
  "sendBeacon"

@send
external sendBeacon2: (t, ~url: string, ~data: FileTypes.blob=?) => bool = "sendBeacon"

@send
external sendBeacon3: (t, ~url: string, ~data: DataView.t=?) => bool = "sendBeacon"

@send
external sendBeacon4: (t, ~url: string, ~data: ArrayBuffer.t=?) => bool = "sendBeacon"

@send
external sendBeacon5: (t, ~url: string, ~data: FetchTypes.formData=?) => bool = "sendBeacon"

@send
external sendBeacon6: (t, ~url: string, ~data: UrlTypes.urlSearchParams=?) => bool = "sendBeacon"

@send
external sendBeacon7: (t, ~url: string, ~data: string=?) => bool = "sendBeacon"

@send
external getGamepads: t => array<GamepadTypes.gamepad> = "getGamepads"

@send
external requestMediaKeySystemAccess: (
  t,
  ~keySystem: string,
  ~supportedConfigurations: array<DomTypes.mediaKeySystemConfiguration>,
) => promise<'mediaKeySystemAccess> = "requestMediaKeySystemAccess"

@send
external requestMIDIAccess: (
  t,
  ~options: WebMidiTypes.midiOptions=?,
) => promise<WebMidiTypes.midiAccess> = "requestMIDIAccess"
