type t = DomTypes.navigator

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/clipboard)
    */
@get external clipboard: t => ClipboardTypes.clipboard = "clipboard"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/credentials)
    */
@get external credentials: t => CredentialManagementTypes.credentialsContainer = "credentials"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/geolocation)
    */
@get external geolocation: t => GeolocationTypes.geolocation = "geolocation"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/userActivation)
    */
@get external userActivation: t => DomTypes.userActivation = "userActivation"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/mediaCapabilities)
    */
@get external mediaCapabilities: t => MediaCapabilitiesTypes.mediaCapabilities = "mediaCapabilities"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/mediaDevices)
    */
@get external mediaDevices: t => MediaCaptureAndStreamsTypes.mediaDevices = "mediaDevices"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/mediaSession)
    */
@get external mediaSession: t => MediaSessionTypes.mediaSession = "mediaSession"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/permissions)
    */
@get external permissions: t => PermissionsTypes.permissions = "permissions"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/maxTouchPoints)
    */
@get external maxTouchPoints: t => int = "maxTouchPoints"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/wakeLock)
    */
@get external wakeLock: t => ScreenWakeLockTypes.wakeLock = "wakeLock"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/serviceWorker)
    */
@get external serviceWorker: t => ServiceWorkerTypes.serviceWorkerContainer = "serviceWorker"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/userAgent)
    */
@get external userAgent: t => string = "userAgent"

/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/language)
    */
@get external language: t => string = "language"
/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/languages)
    */
@get external languages: t => array<string> = "languages"
/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/onLine)
    */
@get external onLine: t => bool = "onLine"
/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/cookieEnabled)
    */
@get external cookieEnabled: t => bool = "cookieEnabled"
/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/pdfViewerEnabled)
    */
@get external pdfViewerEnabled: t => bool = "pdfViewerEnabled"
/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/hardwareConcurrency)
    */
@get external hardwareConcurrency: t => int = "hardwareConcurrency"
/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/storage)
    */
@get external storage: t => StorageTypes.storageManager = "storage"
/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/locks)
    */
@get external locks: t => WebLocksTypes.lockManager = "locks"
/**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/webdriver)
    */
@get external webdriver: t => bool = "webdriver"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon: (t, ~url: string, ~data: FileTypes.readableStream<unit>=?) => bool =
  "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon2: (t, ~url: string, ~data: FileTypes.blob=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon3: (t, ~url: string, ~data: DataView.t=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon4: (t, ~url: string, ~data: ArrayBuffer.t=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon5: (t, ~url: string, ~data: FetchTypes.formData=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon6: (t, ~url: string, ~data: UrlTypes.urlSearchParams=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon7: (t, ~url: string, ~data: string=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/getGamepads)
*/
@send
external getGamepads: t => array<GamepadTypes.gamepad> = "getGamepads"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/requestMediaKeySystemAccess)
*/
@send
external requestMediaKeySystemAccess: (
  t,
  ~keySystem: string,
  ~supportedConfigurations: array<DomTypes.mediaKeySystemConfiguration>,
) => promise<'mediaKeySystemAccess> = "requestMediaKeySystemAccess"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/requestMIDIAccess)
*/
@send
external requestMIDIAccess: (
  t,
  ~options: WebMidiTypes.midiOptions=?,
) => promise<WebMidiTypes.midiAccess> = "requestMIDIAccess"
