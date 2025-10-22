@@warning("-30")

open Prelude
open EventAPI
open ClipboardAPI
open CredentialManagementAPI
open GeolocationAPI
open MediaCapabilitiesAPI
open MediaCaptureAndStreamsAPI
open MediaSessionAPI
open PermissionsAPI
open ScreenWakeLockAPI
open WebWorkersAPI
open ServiceWorkerAPI
open EncryptedMediaExtensionsAPI
open FileAPI
open HistoryAPI
open VisualViewportAPI
open WebSpeechAPI
open FileAndDirectoryEntriesAPI
open RemotePlaybackAPI
open CanvasAPI
open StorageAPI
open WebLocksAPI
open CSSFontLoadingAPI
open IndexedDBAPI
open WebCryptoAPI
open PerformanceAPI
open WebStorageAPI
open ChannelMessagingAPI

type shadowRootMode =
  | @as("closed") Closed
  | @as("open") Open

type slotAssignmentMode =
  | @as("manual") Manual
  | @as("named") Named

type autoFillBase =
  | @as("off") Off
  | @as("on") On

type documentReadyState =
  | @as("complete") Complete
  | @as("interactive") Interactive
  | @as("loading") Loading

type documentVisibilityState =
  | @as("hidden") Hidden
  | @as("visible") Visible

type orientationType =
  | @as("landscape-primary") LandscapePrimary
  | @as("landscape-secondary") LandscapeSecondary
  | @as("portrait-primary") PortraitPrimary
  | @as("portrait-secondary") PortraitSecondary

type insertPosition =
  | @as("afterbegin") Afterbegin
  | @as("afterend") Afterend
  | @as("beforebegin") Beforebegin
  | @as("beforeend") Beforeend

type scrollBehavior =
  | @as("auto") Auto
  | @as("instant") Instant
  | @as("smooth") Smooth

type fullscreenNavigationUI =
  | @as("auto") Auto
  | @as("hide") Hide
  | @as("show") Show

type remotePlaybackState =
  | @as("connected") Connected
  | @as("connecting") Connecting
  | @as("disconnected") Disconnected

type referrerPolicy =
  | @as("no-referrer") NoReferrer
  | @as("no-referrer-when-downgrade") NoReferrerWhenDowngrade
  | @as("origin") Origin
  | @as("origin-when-cross-origin") OriginWhenCrossOrigin
  | @as("same-origin") SameOrigin
  | @as("strict-origin") StrictOrigin
  | @as("strict-origin-when-cross-origin") StrictOriginWhenCrossOrigin
  | @as("unsafe-url") UnsafeUrl

type canPlayTypeResult =
  | @as("maybe") Maybe
  | @as("probably") Probably

type animationPlayState =
  | @as("finished") Finished
  | @as("idle") Idle
  | @as("paused") Paused
  | @as("running") Running

type animationReplaceState =
  | @as("active") Active
  | @as("persisted") Persisted
  | @as("removed") Removed

type fillMode =
  | @as("auto") Auto
  | @as("backwards") Backwards
  | @as("both") Both
  | @as("forwards") Forwards
  | @as("none") None

type playbackDirection =
  | @as("alternate") Alternate
  | @as("alternate-reverse") AlternateReverse
  | @as("normal") Normal
  | @as("reverse") Reverse

type imageOrientation =
  | @as("flipY") FlipY
  | @as("from-image") FromImage
  | @as("none") None

type premultiplyAlpha =
  | @as("default") Default
  | @as("none") None
  | @as("premultiply") Premultiply

type colorSpaceConversion =
  | @as("default") Default
  | @as("none") None

type resizeQuality =
  | @as("high") High
  | @as("low") Low
  | @as("medium") Medium
  | @as("pixelated") Pixelated

type scrollLogicalPosition =
  | @as("center") Center
  | @as("end") End
  | @as("nearest") Nearest
  | @as("start") Start

type selectionMode =
  | @as("end") End
  | @as("preserve") Preserve
  | @as("select") Select
  | @as("start") Start

type compositeOperation =
  | @as("accumulate") Accumulate
  | @as("add") Add
  | @as("replace") Replace

type iterationCompositeOperation =
  | @as("accumulate") Accumulate
  | @as("replace") Replace

type videoPixelFormat =
  | BGRA
  | BGRX
  | I420
  | I420A
  | I422
  | I444
  | NV12
  | RGBA
  | RGBX

type videoColorPrimaries =
  | @as("bt470bg") Bt470bg
  | @as("bt709") Bt709
  | @as("smpte170m") Smpte170m

type videoTransferCharacteristics =
  | @as("bt709") Bt709
  | @as("iec61966-2-1") Iec6196621
  | @as("smpte170m") Smpte170m

type videoMatrixCoefficients =
  | @as("bt470bg") Bt470bg
  | @as("bt709") Bt709
  | @as("rgb") Rgb
  | @as("smpte170m") Smpte170m

type alphaOption =
  | @as("discard") Discard
  | @as("keep") Keep

type predefinedColorSpace =
  | @as("display-p3") DisplayP3
  | @as("srgb") Srgb

type shareData = {
  mutable files?: array<file>,
  mutable title?: string,
  mutable text?: string,
  mutable url?: string,
}

/**
@editor.completeFrom(Window) The location (URL) of the object it is linked to. Changes done on it are reflected on the object it relates to. Both the Document and Window interface have such a linked Location, accessible via Document.location and Window.location respectively.
[See Location on MDN](https://developer.mozilla.org/docs/Web/API/Location)
*/
@editor.completeFrom(Location)
type location = {
  /**
    Returns the Location object's URL.

Can be set, to navigate to the given URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/href)
    */
  mutable href: string,
  /**
    Returns the Location object's URL's origin.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/origin)
    */
  origin: string,
  /**
    Returns the Location object's URL's scheme.

Can be set, to navigate to the same URL with a changed scheme.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/protocol)
    */
  mutable protocol: string,
  /**
    Returns the Location object's URL's host and port (if different from the default port for the scheme).

Can be set, to navigate to the same URL with a changed host and port.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/host)
    */
  mutable host: string,
  /**
    Returns the Location object's URL's host.

Can be set, to navigate to the same URL with a changed host.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/hostname)
    */
  mutable hostname: string,
  /**
    Returns the Location object's URL's port.

Can be set, to navigate to the same URL with a changed port.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/port)
    */
  mutable port: string,
  /**
    Returns the Location object's URL's path.

Can be set, to navigate to the same URL with a changed path.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/pathname)
    */
  mutable pathname: string,
  /**
    Returns the Location object's URL's query (includes leading "?" if non-empty).

Can be set, to navigate to the same URL with a changed query (ignores leading "?").
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/search)
    */
  mutable search: string,
  /**
    Returns the Location object's URL's fragment (includes leading "#" if non-empty).

Can be set, to navigate to the same URL with a changed fragment (ignores leading "#").
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/hash)
    */
  mutable hash: string,
  /**
    Returns a DOMStringList object listing the origins of the ancestor browsing contexts, from the parent browsing context to the top-level browsing context.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/ancestorOrigins)
    */
  ancestorOrigins: domStringList,
}

/**
[See UserActivation on MDN](https://developer.mozilla.org/docs/Web/API/UserActivation)
*/
type userActivation = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/UserActivation/hasBeenActive)
    */
  hasBeenActive: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/UserActivation/isActive)
    */
  isActive: bool,
}

/**
The state and the identity of the user agent. It allows scripts to query it and to register themselves to carry on some activities.
[See Navigator on MDN](https://developer.mozilla.org/docs/Web/API/Navigator)
*/
@editor.completeFrom(Navigator)
type navigator = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/clipboard)
    */
  clipboard: clipboard,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/credentials)
    */
  credentials: credentialsContainer,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/geolocation)
    */
  geolocation: geolocation,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/userActivation)
    */
  userActivation: userActivation,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/mediaCapabilities)
    */
  mediaCapabilities: mediaCapabilities,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/mediaDevices)
    */
  mediaDevices: mediaDevices,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/mediaSession)
    */
  mediaSession: mediaSession,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/permissions)
    */
  permissions: permissions,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/maxTouchPoints)
    */
  maxTouchPoints: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/wakeLock)
    */
  wakeLock: wakeLock,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/serviceWorker)
    */
  serviceWorker: serviceWorkerContainer,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/userAgent)
    */
  userAgent: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/language)
    */
  language: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/languages)
    */
  languages: array<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/onLine)
    */
  onLine: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/cookieEnabled)
    */
  cookieEnabled: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/pdfViewerEnabled)
    */
  pdfViewerEnabled: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/hardwareConcurrency)
    */
  hardwareConcurrency: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/storage)
    */
  storage: storageManager,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/locks)
    */
  locks: lockManager,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/webdriver)
    */
  webdriver: bool,
}

/**
A set of space-separated tokens. Such a set is returned by Element.classList, HTMLLinkElement.relList, HTMLAnchorElement.relList, HTMLAreaElement.relList, HTMLIframeElement.sandbox, or HTMLOutputElement.htmlFor. It is indexed beginning with 0 as with JavaScript Array objects. DOMTokenList is always case-sensitive.
[See DOMTokenList on MDN](https://developer.mozilla.org/docs/Web/API/DOMTokenList)
*/
@editor.completeFrom(DOMTokenList)
type domTokenList = {
  /**
    Returns the number of tokens.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMTokenList/length)
    */
  length: int,
  /**
    Returns the associated set as string.

Can be set, to change the associated attribute.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMTokenList/value)
    */
  mutable value: string,
}

/**
A collection of Attr objects. Objects inside a NamedNodeMap are not in any particular order, unlike NodeList, although they may be accessed by an index as in an array.
[See NamedNodeMap on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap)
*/
@editor.completeFrom(NamedNodeMap)
type namedNodeMap = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/length)
    */
  length: int,
}

/**
[See FragmentDirective on MDN](https://developer.mozilla.org/docs/Web/API/FragmentDirective)
*/
type fragmentDirective = {}

/**
[See CustomElementRegistry on MDN](https://developer.mozilla.org/docs/Web/API/CustomElementRegistry)
*/
@editor.completeFrom(CustomElementRegistry)
type customElementRegistry = {}

/**
[See BarProp on MDN](https://developer.mozilla.org/docs/Web/API/BarProp)
*/
type barProp = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BarProp/visible)
    */
  visible: bool,
}

/**
[See ScreenOrientation on MDN](https://developer.mozilla.org/docs/Web/API/ScreenOrientation)
*/
@editor.completeFrom(ScreenOrientation)
type screenOrientation = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ScreenOrientation/type)
    */
  @as("type")
  type_: orientationType,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ScreenOrientation/angle)
    */
  angle: int,
}

/**
A screen, usually the one on which the current window is being rendered, and is obtained using window.screen.
[See Screen on MDN](https://developer.mozilla.org/docs/Web/API/Screen)
*/
type screen = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Screen/availWidth)
    */
  availWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Screen/availHeight)
    */
  availHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Screen/width)
    */
  width: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Screen/height)
    */
  height: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Screen/colorDepth)
    */
  colorDepth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Screen/pixelDepth)
    */
  pixelDepth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Screen/orientation)
    */
  orientation: screenOrientation,
}

@unboxed
type vibratePattern =
  | Int(int)
  | IntArray(array<int>)

type renderingContext = any

type offscreenRenderingContext = any

/**
[See AnimationTimeline on MDN](https://developer.mozilla.org/docs/Web/API/AnimationTimeline)
*/
@editor.completeFrom(Animation)
type rec animationTimeline = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnimationTimeline/currentTime)
    */
  currentTime: Null.t<float>,
}

/**
[See DocumentTimeline on MDN](https://developer.mozilla.org/docs/Web/API/DocumentTimeline)
*/
@editor.completeFrom(DocumentTimeline) and documentTimeline = {
  // Base properties from AnimationTimeline
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnimationTimeline/currentTime)
    */
  currentTime: Null.t<float>,
  // End base properties from AnimationTimeline
}

/**
[See MediaList on MDN](https://developer.mozilla.org/docs/Web/API/MediaList)
*/
@editor.completeFrom(MediaList)
type mediaList = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaList/mediaText)
    */
  mutable mediaText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaList/length)
    */
  length: int,
}

/**
[See StylePropertyMapReadOnly on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly)
*/
@editor.completeFrom(StylePropertyMapReadOnly)
type stylePropertyMapReadOnly = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly/size)
    */
  size: int,
}

/**
[See StylePropertyMap on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap)
*/
@editor.completeFrom(StylePropertyMap)
type stylePropertyMap = {
  ...stylePropertyMapReadOnly,
}

/**
Used by the dataset HTML attribute to represent data for custom attributes added to elements.
[See DOMStringMap on MDN](https://developer.mozilla.org/docs/Web/API/DOMStringMap)
*/
type domStringMap = {}

/**
A list of StyleSheet.
[See StyleSheetList on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheetList)
*/
@editor.completeFrom(StyleSheetList)
type rec styleSheetList = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheetList/length)
    */
  length: int,
}

/**
A single style sheet. CSS style sheets will further implement the more specialized CSSStyleSheet interface.
[See StyleSheet on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet)
*/
and styleSheet = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/type)
    */
  @as("type")
  type_: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/href)
    */
  href: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/ownerNode)
    */
  ownerNode: Null.t<unknown>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/parentStyleSheet)
    */
  parentStyleSheet: Null.t<cssStyleSheet>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/title)
    */
  title: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/media)
    */
  media: mediaList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/disabled)
    */
  mutable disabled: bool,
}

/**
A single CSS style sheet. It inherits properties and methods from its parent, StyleSheet.
[See CSSStyleSheet on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleSheet)
*/
@editor.completeFrom(CSSStyleSheet) and cssStyleSheet = {
  // Base properties from StyleSheet
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/type)
    */
  @as("type")
  type_: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/href)
    */
  href: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/ownerNode)
    */
  ownerNode: Null.t<unknown>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/parentStyleSheet)
    */
  parentStyleSheet: Null.t<cssStyleSheet>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/title)
    */
  title: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/media)
    */
  media: mediaList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StyleSheet/disabled)
    */
  mutable disabled: bool,
  // End base properties from StyleSheet

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleSheet/ownerRule)
    */
  ownerRule: Null.t<cssRule>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleSheet/cssRules)
    */
  cssRules: cssRuleList,
}

/**
A single CSS rule. There are several types of rules, listed in the Type constants section below.
[See CSSRule on MDN](https://developer.mozilla.org/docs/Web/API/CSSRule)
*/
and cssRule = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSRule/cssText)
    */
  mutable cssText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSRule/parentRule)
    */
  parentRule: Null.t<cssRule>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSRule/parentStyleSheet)
    */
  parentStyleSheet: Null.t<cssStyleSheet>,
}

/**
A CSSRuleList is an (indirect-modify only) array-like object containing an ordered collection of CSSRule objects.
[See CSSRuleList on MDN](https://developer.mozilla.org/docs/Web/API/CSSRuleList)
*/
@editor.completeFrom(CSSRuleList) and cssRuleList = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSRuleList/length)
    */
  length: int,
}

/**
An object that is a CSS declaration block, and exposes style information and various style-related methods and properties.
[See CSSStyleDeclaration on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleDeclaration)
*/
@editor.completeFrom(CSSStyleDeclaration) and cssStyleDeclaration = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleDeclaration/cssText)
    */
  mutable cssText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleDeclaration/length)
    */
  length: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleDeclaration/parentRule)
    */
  parentRule: Null.t<cssRule>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/cx)
    */
  mutable cx: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/cy)
    */
  mutable cy: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/r)
    */
  mutable r: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/rx)
    */
  mutable rx: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/ry)
    */
  mutable ry: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/x)
    */
  mutable x: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/y)
    */
  mutable y: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/vector-effect)
    */
  mutable vectorEffect: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/d)
    */
  mutable d: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-anchor)
    */
  mutable textAnchor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/fill)
    */
  mutable fill: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/stroke)
    */
  mutable stroke: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/marker-start)
    */
  mutable markerStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/marker-mid)
    */
  mutable markerMid: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/marker-end)
    */
  mutable markerEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/marker)
    */
  mutable marker: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/paint-order)
    */
  mutable paintOrder: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/color-interpolation)
    */
  mutable colorInterpolation: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/shape-rendering)
    */
  mutable shapeRendering: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-rendering)
    */
  mutable textRendering: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/pointer-events)
    */
  mutable pointerEvents: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/stop-color)
    */
  mutable stopColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/stop-opacity)
    */
  mutable stopOpacity: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/-webkit-text-fill-color)
    */
  mutable webkitTextFillColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/-webkit-text-stroke-color)
    */
  mutable webkitTextStrokeColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/-webkit-text-stroke-width)
    */
  mutable webkitTextStrokeWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/-webkit-text-stroke)
    */
  mutable webkitTextStroke: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/touch-action)
    */
  mutable touchAction: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/position-area)
    */
  mutable positionArea: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/top)
    */
  mutable top: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/left)
    */
  mutable left: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/right)
    */
  mutable right: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/bottom)
    */
  mutable bottom: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/justify-self)
    */
  mutable justifySelf: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/align-self)
    */
  mutable alignSelf: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/justify-items)
    */
  mutable justifyItems: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/align-items)
    */
  mutable alignItems: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/width)
    */
  mutable width: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/height)
    */
  mutable height: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/min-width)
    */
  mutable minWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/min-height)
    */
  mutable minHeight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/max-width)
    */
  mutable maxWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/max-height)
    */
  mutable maxHeight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin-top)
    */
  mutable marginTop: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin-left)
    */
  mutable marginLeft: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin-right)
    */
  mutable marginRight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin-bottom)
    */
  mutable marginBottom: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/animation-duration)
    */
  mutable animationDuration: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/animation-composition)
    */
  mutable animationComposition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/animation-name)
    */
  mutable animationName: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/animation-timing-function)
    */
  mutable animationTimingFunction: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/animation-iteration-count)
    */
  mutable animationIterationCount: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/animation-direction)
    */
  mutable animationDirection: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/animation-play-state)
    */
  mutable animationPlayState: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/animation-delay)
    */
  mutable animationDelay: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/animation-fill-mode)
    */
  mutable animationFillMode: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/animation)
    */
  mutable animation: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/all)
    */
  mutable all: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/container-type)
    */
  mutable containerType: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/container-name)
    */
  mutable containerName: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/container)
    */
  mutable container: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/contain)
    */
  mutable contain: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/content-visibility)
    */
  mutable contentVisibility: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-family)
    */
  mutable fontFamily: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-weight)
    */
  mutable fontWeight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-style)
    */
  mutable fontStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-size)
    */
  mutable fontSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-size-adjust)
    */
  mutable fontSizeAdjust: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font)
    */
  mutable font: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-synthesis-weight)
    */
  mutable fontSynthesisWeight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-synthesis-style)
    */
  mutable fontSynthesisStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-synthesis-small-caps)
    */
  mutable fontSynthesisSmallCaps: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-synthesis)
    */
  mutable fontSynthesis: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-kerning)
    */
  mutable fontKerning: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-variant-ligatures)
    */
  mutable fontVariantLigatures: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-variant-position)
    */
  mutable fontVariantPosition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-variant-caps)
    */
  mutable fontVariantCaps: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-variant-numeric)
    */
  mutable fontVariantNumeric: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-variant-alternates)
    */
  mutable fontVariantAlternates: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-variant-east-asian)
    */
  mutable fontVariantEastAsian: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-variant)
    */
  mutable fontVariant: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-feature-settings)
    */
  mutable fontFeatureSettings: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-optical-sizing)
    */
  mutable fontOpticalSizing: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-variation-settings)
    */
  mutable fontVariationSettings: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-palette)
    */
  mutable fontPalette: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/font-stretch)
    */
  mutable fontStretch: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/object-fit)
    */
  mutable objectFit: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/clip-path)
    */
  mutable clipPath: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/clip-rule)
    */
  mutable clipRule: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mask-image)
    */
  mutable maskImage: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mask-mode)
    */
  mutable maskMode: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mask-repeat)
    */
  mutable maskRepeat: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mask-position)
    */
  mutable maskPosition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mask-clip)
    */
  mutable maskClip: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mask-origin)
    */
  mutable maskOrigin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mask-size)
    */
  mutable maskSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mask-composite)
    */
  mutable maskComposite: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mask)
    */
  mutable mask: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mask-type)
    */
  mutable maskType: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/transition-behavior)
    */
  mutable transitionBehavior: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/transition-property)
    */
  mutable transitionProperty: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/transition-duration)
    */
  mutable transitionDuration: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/transition-timing-function)
    */
  mutable transitionTimingFunction: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/transition-delay)
    */
  mutable transitionDelay: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/transition)
    */
  mutable transition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/view-transition-name)
    */
  mutable viewTransitionName: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/zoom)
    */
  mutable zoom: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/filter)
    */
  mutable filter: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/color-interpolation-filters)
    */
  mutable colorInterpolationFilters: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/display)
    */
  mutable display: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-transform)
    */
  mutable textTransform: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/math-style)
    */
  mutable mathStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/math-depth)
    */
  mutable mathDepth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/z-index)
    */
  mutable zIndex: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/page-break-before)
    */
  mutable pageBreakBefore: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/page-break-after)
    */
  mutable pageBreakAfter: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/page-break-inside)
    */
  mutable pageBreakInside: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/mix-blend-mode)
    */
  mutable mixBlendMode: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/isolation)
    */
  mutable isolation: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-blend-mode)
    */
  mutable backgroundBlendMode: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/align-content)
    */
  mutable alignContent: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/justify-content)
    */
  mutable justifyContent: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/place-content)
    */
  mutable placeContent: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/place-self)
    */
  mutable placeSelf: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/place-items)
    */
  mutable placeItems: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/row-gap)
    */
  mutable rowGap: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/column-gap)
    */
  mutable columnGap: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/gap)
    */
  mutable gap: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-repeat)
    */
  mutable backgroundRepeat: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-position)
    */
  mutable backgroundPosition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-position-x)
    */
  mutable backgroundPositionX: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-position-y)
    */
  mutable backgroundPositionY: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-clip)
    */
  mutable backgroundClip: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-color)
    */
  mutable backgroundColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-image)
    */
  mutable backgroundImage: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-attachment)
    */
  mutable backgroundAttachment: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-origin)
    */
  mutable backgroundOrigin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background-size)
    */
  mutable backgroundSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/background)
    */
  mutable background: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-style)
    */
  mutable borderStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-width)
    */
  mutable borderWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border)
    */
  mutable border: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-image-source)
    */
  mutable borderImageSource: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-image-slice)
    */
  mutable borderImageSlice: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-image-width)
    */
  mutable borderImageWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-image-outset)
    */
  mutable borderImageOutset: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-image-repeat)
    */
  mutable borderImageRepeat: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-image)
    */
  mutable borderImage: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-top-color)
    */
  mutable borderTopColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-right-color)
    */
  mutable borderRightColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-bottom-color)
    */
  mutable borderBottomColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-left-color)
    */
  mutable borderLeftColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-start-color)
    */
  mutable borderBlockStartColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-end-color)
    */
  mutable borderBlockEndColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-start-color)
    */
  mutable borderInlineStartColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-end-color)
    */
  mutable borderInlineEndColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-color)
    */
  mutable borderColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-color)
    */
  mutable borderBlockColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-color)
    */
  mutable borderInlineColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-top-style)
    */
  mutable borderTopStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-right-style)
    */
  mutable borderRightStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-bottom-style)
    */
  mutable borderBottomStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-left-style)
    */
  mutable borderLeftStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-start-style)
    */
  mutable borderBlockStartStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-end-style)
    */
  mutable borderBlockEndStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-start-style)
    */
  mutable borderInlineStartStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-end-style)
    */
  mutable borderInlineEndStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-style)
    */
  mutable borderBlockStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-style)
    */
  mutable borderInlineStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-top-width)
    */
  mutable borderTopWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-right-width)
    */
  mutable borderRightWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-bottom-width)
    */
  mutable borderBottomWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-left-width)
    */
  mutable borderLeftWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-start-width)
    */
  mutable borderBlockStartWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-end-width)
    */
  mutable borderBlockEndWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-start-width)
    */
  mutable borderInlineStartWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-end-width)
    */
  mutable borderInlineEndWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-width)
    */
  mutable borderBlockWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-width)
    */
  mutable borderInlineWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-top)
    */
  mutable borderTop: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-right)
    */
  mutable borderRight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-bottom)
    */
  mutable borderBottom: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-left)
    */
  mutable borderLeft: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-start)
    */
  mutable borderBlockStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block-end)
    */
  mutable borderBlockEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-start)
    */
  mutable borderInlineStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline-end)
    */
  mutable borderInlineEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-block)
    */
  mutable borderBlock: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-inline)
    */
  mutable borderInline: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-top-left-radius)
    */
  mutable borderTopLeftRadius: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-top-right-radius)
    */
  mutable borderTopRightRadius: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-bottom-right-radius)
    */
  mutable borderBottomRightRadius: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-bottom-left-radius)
    */
  mutable borderBottomLeftRadius: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-start-start-radius)
    */
  mutable borderStartStartRadius: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-start-end-radius)
    */
  mutable borderStartEndRadius: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-end-start-radius)
    */
  mutable borderEndStartRadius: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-end-end-radius)
    */
  mutable borderEndEndRadius: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-radius)
    */
  mutable borderRadius: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/box-shadow)
    */
  mutable boxShadow: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin)
    */
  mutable margin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding-top)
    */
  mutable paddingTop: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding-right)
    */
  mutable paddingRight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding-bottom)
    */
  mutable paddingBottom: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding-left)
    */
  mutable paddingLeft: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding)
    */
  mutable padding: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/break-before)
    */
  mutable breakBefore: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/break-after)
    */
  mutable breakAfter: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/break-inside)
    */
  mutable breakInside: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/orphans)
    */
  mutable orphans: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/widows)
    */
  mutable widows: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/box-decoration-break)
    */
  mutable boxDecorationBreak: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/color-scheme)
    */
  mutable colorScheme: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/forced-color-adjust)
    */
  mutable forcedColorAdjust: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/print-color-adjust)
    */
  mutable printColorAdjust: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/color)
    */
  mutable color: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/opacity)
    */
  mutable opacity: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/content)
    */
  mutable content: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/quotes)
    */
  mutable quotes: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/order)
    */
  mutable order: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/visibility)
    */
  mutable visibility: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/flex-direction)
    */
  mutable flexDirection: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/flex-wrap)
    */
  mutable flexWrap: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/flex-flow)
    */
  mutable flexFlow: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/flex)
    */
  mutable flex: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/flex-grow)
    */
  mutable flexGrow: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/flex-shrink)
    */
  mutable flexShrink: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/flex-basis)
    */
  mutable flexBasis: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/position)
    */
  mutable position: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/float)
    */
  mutable float: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-template-columns)
    */
  mutable gridTemplateColumns: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-template-rows)
    */
  mutable gridTemplateRows: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-auto-flow)
    */
  mutable gridAutoFlow: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-template-areas)
    */
  mutable gridTemplateAreas: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-template)
    */
  mutable gridTemplate: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-auto-columns)
    */
  mutable gridAutoColumns: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-auto-rows)
    */
  mutable gridAutoRows: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid)
    */
  mutable grid: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-row-start)
    */
  mutable gridRowStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-column-start)
    */
  mutable gridColumnStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-row-end)
    */
  mutable gridRowEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-column-end)
    */
  mutable gridColumnEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-row)
    */
  mutable gridRow: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-column)
    */
  mutable gridColumn: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/grid-area)
    */
  mutable gridArea: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/object-position)
    */
  mutable objectPosition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/image-rendering)
    */
  mutable imageRendering: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/dominant-baseline)
    */
  mutable dominantBaseline: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/vertical-align)
    */
  mutable verticalAlign: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/line-height)
    */
  mutable lineHeight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/list-style-image)
    */
  mutable listStyleImage: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/list-style-type)
    */
  mutable listStyleType: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/list-style-position)
    */
  mutable listStylePosition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/list-style)
    */
  mutable listStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/counter-reset)
    */
  mutable counterReset: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/counter-increment)
    */
  mutable counterIncrement: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/counter-set)
    */
  mutable counterSet: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/block-size)
    */
  mutable blockSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/inline-size)
    */
  mutable inlineSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/min-block-size)
    */
  mutable minBlockSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/min-inline-size)
    */
  mutable minInlineSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/max-block-size)
    */
  mutable maxBlockSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/max-inline-size)
    */
  mutable maxInlineSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin-block-start)
    */
  mutable marginBlockStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin-block-end)
    */
  mutable marginBlockEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin-inline-start)
    */
  mutable marginInlineStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin-inline-end)
    */
  mutable marginInlineEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin-block)
    */
  mutable marginBlock: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/margin-inline)
    */
  mutable marginInline: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding-block-start)
    */
  mutable paddingBlockStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding-block-end)
    */
  mutable paddingBlockEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding-inline-start)
    */
  mutable paddingInlineStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding-inline-end)
    */
  mutable paddingInlineEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding-block)
    */
  mutable paddingBlock: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/padding-inline)
    */
  mutable paddingInline: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/column-span)
    */
  mutable columnSpan: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/column-width)
    */
  mutable columnWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/column-count)
    */
  mutable columnCount: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/columns)
    */
  mutable columns: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/column-rule-color)
    */
  mutable columnRuleColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/column-rule-style)
    */
  mutable columnRuleStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/column-rule-width)
    */
  mutable columnRuleWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/column-rule)
    */
  mutable columnRule: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/column-fill)
    */
  mutable columnFill: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overflow-clip-margin)
    */
  mutable overflowClipMargin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-overflow)
    */
  mutable textOverflow: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overflow-x)
    */
  mutable overflowX: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overflow-y)
    */
  mutable overflowY: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overflow)
    */
  mutable overflow: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-behavior)
    */
  mutable scrollBehavior: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scrollbar-gutter)
    */
  mutable scrollbarGutter: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overscroll-behavior)
    */
  mutable overscrollBehavior: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overscroll-behavior-x)
    */
  mutable overscrollBehaviorX: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overscroll-behavior-y)
    */
  mutable overscrollBehaviorY: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overscroll-behavior-inline)
    */
  mutable overscrollBehaviorInline: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overscroll-behavior-block)
    */
  mutable overscrollBehaviorBlock: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/clear)
    */
  mutable clear: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/page)
    */
  mutable page: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/inset-block-start)
    */
  mutable insetBlockStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/inset-inline-start)
    */
  mutable insetInlineStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/inset-block-end)
    */
  mutable insetBlockEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/inset-inline-end)
    */
  mutable insetInlineEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/inset-block)
    */
  mutable insetBlock: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/inset-inline)
    */
  mutable insetInline: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/inset)
    */
  mutable inset: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/ruby-position)
    */
  mutable rubyPosition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/ruby-align)
    */
  mutable rubyAlign: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overflow-anchor)
    */
  mutable overflowAnchor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-snap-type)
    */
  mutable scrollSnapType: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding)
    */
  mutable scrollPadding: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin)
    */
  mutable scrollMargin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-snap-align)
    */
  mutable scrollSnapAlign: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-snap-stop)
    */
  mutable scrollSnapStop: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding-top)
    */
  mutable scrollPaddingTop: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding-right)
    */
  mutable scrollPaddingRight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding-bottom)
    */
  mutable scrollPaddingBottom: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding-left)
    */
  mutable scrollPaddingLeft: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding-inline-start)
    */
  mutable scrollPaddingInlineStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding-block-start)
    */
  mutable scrollPaddingBlockStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding-inline-end)
    */
  mutable scrollPaddingInlineEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding-block-end)
    */
  mutable scrollPaddingBlockEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding-block)
    */
  mutable scrollPaddingBlock: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-padding-inline)
    */
  mutable scrollPaddingInline: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin-top)
    */
  mutable scrollMarginTop: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin-right)
    */
  mutable scrollMarginRight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin-bottom)
    */
  mutable scrollMarginBottom: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin-left)
    */
  mutable scrollMarginLeft: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin-block-start)
    */
  mutable scrollMarginBlockStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin-inline-start)
    */
  mutable scrollMarginInlineStart: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin-block-end)
    */
  mutable scrollMarginBlockEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin-inline-end)
    */
  mutable scrollMarginInlineEnd: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin-block)
    */
  mutable scrollMarginBlock: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scroll-margin-inline)
    */
  mutable scrollMarginInline: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scrollbar-color)
    */
  mutable scrollbarColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scrollbar-width)
    */
  mutable scrollbarWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/shape-outside)
    */
  mutable shapeOutside: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/shape-image-threshold)
    */
  mutable shapeImageThreshold: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/shape-margin)
    */
  mutable shapeMargin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/aspect-ratio)
    */
  mutable aspectRatio: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/contain-intrinsic-width)
    */
  mutable containIntrinsicWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/contain-intrinsic-height)
    */
  mutable containIntrinsicHeight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/contain-intrinsic-block-size)
    */
  mutable containIntrinsicBlockSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/contain-intrinsic-inline-size)
    */
  mutable containIntrinsicInlineSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/contain-intrinsic-size)
    */
  mutable containIntrinsicSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/box-sizing)
    */
  mutable boxSizing: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/table-layout)
    */
  mutable tableLayout: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-collapse)
    */
  mutable borderCollapse: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/border-spacing)
    */
  mutable borderSpacing: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/caption-side)
    */
  mutable captionSide: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/empty-cells)
    */
  mutable emptyCells: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/white-space)
    */
  mutable whiteSpace: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/white-space-collapse)
    */
  mutable whiteSpaceCollapse: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/tab-size)
    */
  mutable tabSize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-wrap-mode)
    */
  mutable textWrapMode: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-wrap-style)
    */
  mutable textWrapStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-wrap)
    */
  mutable textWrap: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/word-break)
    */
  mutable wordBreak: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/line-break)
    */
  mutable lineBreak: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/hyphens)
    */
  mutable hyphens: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/hyphenate-character)
    */
  mutable hyphenateCharacter: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/overflow-wrap)
    */
  mutable overflowWrap: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-align)
    */
  mutable textAlign: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-align-last)
    */
  mutable textAlignLast: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/word-spacing)
    */
  mutable wordSpacing: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/letter-spacing)
    */
  mutable letterSpacing: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-indent)
    */
  mutable textIndent: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-decoration-line)
    */
  mutable textDecorationLine: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-decoration-style)
    */
  mutable textDecorationStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-decoration-color)
    */
  mutable textDecorationColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-decoration-thickness)
    */
  mutable textDecorationThickness: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-decoration)
    */
  mutable textDecoration: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-underline-position)
    */
  mutable textUnderlinePosition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-underline-offset)
    */
  mutable textUnderlineOffset: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-decoration-skip-ink)
    */
  mutable textDecorationSkipInk: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-emphasis-style)
    */
  mutable textEmphasisStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-emphasis-color)
    */
  mutable textEmphasisColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-emphasis)
    */
  mutable textEmphasis: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-emphasis-position)
    */
  mutable textEmphasisPosition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-shadow)
    */
  mutable textShadow: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/translate)
    */
  mutable translate: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/rotate)
    */
  mutable rotate: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/scale)
    */
  mutable scale: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/transform-style)
    */
  mutable transformStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/perspective)
    */
  mutable perspective: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/perspective-origin)
    */
  mutable perspectiveOrigin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/backface-visibility)
    */
  mutable backfaceVisibility: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/transform)
    */
  mutable transform: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/transform-origin)
    */
  mutable transformOrigin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/transform-box)
    */
  mutable transformBox: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/outline)
    */
  mutable outline: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/outline-width)
    */
  mutable outlineWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/outline-style)
    */
  mutable outlineStyle: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/outline-color)
    */
  mutable outlineColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/outline-offset)
    */
  mutable outlineOffset: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/resize)
    */
  mutable resize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/cursor)
    */
  mutable cursor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/caret-color)
    */
  mutable caretColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/user-select)
    */
  mutable userSelect: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/accent-color)
    */
  mutable accentColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/appearance)
    */
  mutable appearance: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/will-change)
    */
  mutable willChange: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/direction)
    */
  mutable direction: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/unicode-bidi)
    */
  mutable unicodeBidi: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/writing-mode)
    */
  mutable writingMode: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-orientation)
    */
  mutable textOrientation: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/text-combine-upright)
    */
  mutable textCombineUpright: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/fill-rule)
    */
  mutable fillRule: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/fill-opacity)
    */
  mutable fillOpacity: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/stroke-width)
    */
  mutable strokeWidth: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/stroke-linecap)
    */
  mutable strokeLinecap: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/stroke-linejoin)
    */
  mutable strokeLinejoin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/stroke-miterlimit)
    */
  mutable strokeMiterlimit: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/stroke-dasharray)
    */
  mutable strokeDasharray: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/stroke-dashoffset)
    */
  mutable strokeDashoffset: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/stroke-opacity)
    */
  mutable strokeOpacity: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/backdrop-filter)
    */
  mutable backdropFilter: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/offset-path)
    */
  mutable offsetPath: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/offset-distance)
    */
  mutable offsetDistance: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/offset-position)
    */
  mutable offsetPosition: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/offset-anchor)
    */
  mutable offsetAnchor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/offset-rotate)
    */
  mutable offsetRotate: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/CSS/offset)
    */
  mutable offset: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleDeclaration/cssFloat)
    */
  mutable cssFloat: string,
}

/**
Node is an interface from which a number of DOM API object types inherit. It allows those types to be treated similarly; for example, inheriting the same set of methods, or being tested in the same way.
[See Node on MDN](https://developer.mozilla.org/docs/Web/API/Node)
*/
@editor.completeFrom(Node)
type rec node = {
  ...eventTarget,
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
}

/**
NodeList objects are collections of nodes, usually returned by properties such as Node.childNodes and methods such as document.querySelectorAll().
[See NodeList on MDN](https://developer.mozilla.org/docs/Web/API/NodeList)
*/
@editor.completeFrom(NodeList) and nodeList = {
  /**
    Returns the number of nodes in the collection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeList/length)
    */
  length: int,
}

and nodeListOf<'tNode> = {
  // Base properties from NodeList
  /**
    Returns the number of nodes in the collection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeList/length)
    */
  length: int,
  // End base properties from NodeList
}

/**
Element is the most general base class from which all objects in a Document inherit. It only has methods and properties common to all kinds of elements. More specific classes inherit from Element.
[See Element on MDN](https://developer.mozilla.org/docs/Web/API/Element)
*/
@editor.completeFrom(Element) and element = {
  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    Returns the namespace.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    Returns the namespace prefix.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/prefix)
    */
  prefix: Null.t<string>,
  /**
    Returns the local name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/localName)
    */
  localName: string,
  /**
    Returns the HTML-uppercased qualified name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/tagName)
    */
  tagName: string,
  /**
    Returns the value of element's id content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
    */
  mutable id: string,
  /**
    Returns the value of element's class content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/className)
    */
  mutable className: string,
  /**
    Allows for manipulation of element's class content attribute as a set of whitespace-separated tokens through a DOMTokenList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/classList)
    */
  classList: domTokenList,
  /**
    Returns the value of element's slot content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/slot)
    */
  mutable slot: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attributes)
    */
  attributes: namedNodeMap,
  /**
    Returns element's shadow root, if any, and if shadow root's mode is "open", and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/part)
    */
  part: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTop)
    */
  mutable scrollTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollLeft)
    */
  mutable scrollLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollWidth)
    */
  scrollWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollHeight)
    */
  scrollHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientTop)
    */
  clientTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientLeft)
    */
  clientLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientWidth)
    */
  clientWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientHeight)
    */
  clientHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/currentCSSZoom)
    */
  currentCSSZoom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/innerHTML)
    */
  mutable innerHTML: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/outerHTML)
    */
  mutable outerHTML: string,
  /**
    Returns the child elements.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/children)
    */
  children: htmlCollection,
  /**
    Returns the first child that is an element, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/firstElementChild)
    */
  firstElementChild: Null.t<element>,
  /**
    Returns the last child that is an element, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/lastElementChild)
    */
  lastElementChild: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/childElementCount)
    */
  childElementCount: int,
  /**
    Returns the first preceding sibling that is an element, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/previousElementSibling)
    */
  previousElementSibling: Null.t<element>,
  /**
    Returns the first following sibling that is an element, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/nextElementSibling)
    */
  nextElementSibling: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/assignedSlot)
    */
  assignedSlot: Null.t<htmlSlotElement>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaAtomic)
    */
  mutable ariaAtomic: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaAutoComplete)
    */
  mutable ariaAutoComplete: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaBrailleLabel)
    */
  mutable ariaBrailleLabel: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaBrailleRoleDescription)
    */
  mutable ariaBrailleRoleDescription: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaBusy)
    */
  mutable ariaBusy: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaChecked)
    */
  mutable ariaChecked: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaColCount)
    */
  mutable ariaColCount: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaColIndex)
    */
  mutable ariaColIndex: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaColIndexText)
    */
  mutable ariaColIndexText: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaColSpan)
    */
  mutable ariaColSpan: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaCurrent)
    */
  mutable ariaCurrent: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaDescription)
    */
  mutable ariaDescription: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaDisabled)
    */
  mutable ariaDisabled: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaExpanded)
    */
  mutable ariaExpanded: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaHasPopup)
    */
  mutable ariaHasPopup: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaHidden)
    */
  mutable ariaHidden: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaKeyShortcuts)
    */
  mutable ariaKeyShortcuts: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaLabel)
    */
  mutable ariaLabel: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaLevel)
    */
  mutable ariaLevel: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaLive)
    */
  mutable ariaLive: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaModal)
    */
  mutable ariaModal: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaMultiLine)
    */
  mutable ariaMultiLine: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaMultiSelectable)
    */
  mutable ariaMultiSelectable: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaOrientation)
    */
  mutable ariaOrientation: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaPlaceholder)
    */
  mutable ariaPlaceholder: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaPosInSet)
    */
  mutable ariaPosInSet: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaPressed)
    */
  mutable ariaPressed: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaReadOnly)
    */
  mutable ariaReadOnly: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRequired)
    */
  mutable ariaRequired: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRoleDescription)
    */
  mutable ariaRoleDescription: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRowCount)
    */
  mutable ariaRowCount: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRowIndex)
    */
  mutable ariaRowIndex: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRowIndexText)
    */
  mutable ariaRowIndexText: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRowSpan)
    */
  mutable ariaRowSpan: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaSelected)
    */
  mutable ariaSelected: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaSetSize)
    */
  mutable ariaSetSize: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaSort)
    */
  mutable ariaSort: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaValueMax)
    */
  mutable ariaValueMax: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaValueMin)
    */
  mutable ariaValueMin: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaValueNow)
    */
  mutable ariaValueNow: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaValueText)
    */
  mutable ariaValueText: Null.t<string>,
}

/**
[See ShadowRoot on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot)
*/
@editor.completeFrom(ShadowRoot) and shadowRoot = {
  // Base properties from DocumentFragment
  // End base properties from DocumentFragment

  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/mode)
    */
  mode: shadowRootMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/delegatesFocus)
    */
  delegatesFocus: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/slotAssignment)
    */
  slotAssignment: slotAssignmentMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/clonable)
    */
  clonable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/serializable)
    */
  serializable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/host)
    */
  host: element,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/innerHTML)
    */
  mutable innerHTML: string,
  /**
    Retrieves a collection of styleSheet objects representing the style sheets that correspond to each instance of a link or style object in the document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/styleSheets)
    */
  styleSheets: styleSheetList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/adoptedStyleSheets)
    */
  mutable adoptedStyleSheets: array<cssStyleSheet>,
  /**
    Returns document's fullscreen element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/fullscreenElement)
    */
  fullscreenElement: Null.t<element>,
  /**
    Returns the deepest element in the document through which or to which key events are being routed. This is, roughly speaking, the focused element in the document.

For the purposes of this API, when a child browsing context is focused, its container is focused in the parent browsing context. For example, if the user moves the focus to a text control in an iframe, the iframe is the element returned by the activeElement API in the iframe's node document.

Similarly, when the focused element is in a different node tree than documentOrShadowRoot, the element returned will be the host that's located in the same node tree as documentOrShadowRoot if documentOrShadowRoot is a shadow-including inclusive ancestor of the focused element, and null if not.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/activeElement)
    */
  activeElement: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/pictureInPictureElement)
    */
  pictureInPictureElement: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/pointerLockElement)
    */
  pointerLockElement: Null.t<element>,
}

/**
A generic collection (array-like object similar to arguments) of elements (in document order) and offers methods and properties for selecting from the list.
[See HTMLCollection on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection)
*/
@editor.completeFrom(HTMLCollection) and htmlCollection = {
  /**
    Sets or retrieves the number of objects in a collection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/length)
    */
  length: int,
}

and htmlCollectionOf<'t> = {
  // Base properties from HTMLCollection
  /**
    Sets or retrieves the number of objects in a collection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/length)
    */
  length: int,
  // End base properties from HTMLCollection
}

/**
A collection of HTML form control elements. 
[See HTMLFormControlsCollection on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormControlsCollection)
*/
@editor.completeFrom(HTMLFormControlsCollection) and htmlFormControlsCollection = {
  // Base properties from HTMLCollection
  /**
    Sets or retrieves the number of objects in a collection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/length)
    */
  length: int,
  // End base properties from HTMLCollection
}

/**
Any HTML element. Some elements directly implement this interface, while others implement it via an interface that inherits it.
[See HTMLElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement)
*/
@editor.completeFrom(HTMLElement) and htmlElement = {
  // Base properties from Element
  /**
    Returns the namespace.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    Returns the namespace prefix.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/prefix)
    */
  prefix: Null.t<string>,
  /**
    Returns the local name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/localName)
    */
  localName: string,
  /**
    Returns the HTML-uppercased qualified name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/tagName)
    */
  tagName: string,
  /**
    Returns the value of element's id content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
    */
  mutable id: string,
  /**
    Returns the value of element's class content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/className)
    */
  mutable className: string,
  /**
    Allows for manipulation of element's class content attribute as a set of whitespace-separated tokens through a DOMTokenList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/classList)
    */
  classList: domTokenList,
  /**
    Returns the value of element's slot content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/slot)
    */
  mutable slot: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attributes)
    */
  attributes: namedNodeMap,
  /**
    Returns element's shadow root, if any, and if shadow root's mode is "open", and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/part)
    */
  part: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTop)
    */
  mutable scrollTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollLeft)
    */
  mutable scrollLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollWidth)
    */
  scrollWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollHeight)
    */
  scrollHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientTop)
    */
  clientTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientLeft)
    */
  clientLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientWidth)
    */
  clientWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientHeight)
    */
  clientHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/currentCSSZoom)
    */
  currentCSSZoom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/innerHTML)
    */
  mutable innerHTML: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/outerHTML)
    */
  mutable outerHTML: string,
  // End base properties from Element

  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/title)
    */
  mutable title: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/lang)
    */
  mutable lang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/translate)
    */
  mutable translate: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dir)
    */
  mutable dir: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/hidden)
    */
  mutable hidden: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/inert)
    */
  mutable inert: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKey)
    */
  mutable accessKey: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKeyLabel)
    */
  accessKeyLabel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/draggable)
    */
  mutable draggable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/spellcheck)
    */
  mutable spellcheck: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autocapitalize)
    */
  mutable autocapitalize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/innerText)
    */
  mutable innerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/outerText)
    */
  mutable outerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/popover)
    */
  mutable popover: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetParent)
    */
  offsetParent: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetTop)
    */
  offsetTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetLeft)
    */
  offsetLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetWidth)
    */
  offsetWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetHeight)
    */
  offsetHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/style)
    */
  style: cssStyleDeclaration,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/attributeStyleMap)
    */
  attributeStyleMap: stylePropertyMap,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/contentEditable)
    */
  mutable contentEditable: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/enterKeyHint)
    */
  mutable enterKeyHint: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/isContentEditable)
    */
  isContentEditable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/inputMode)
    */
  mutable inputMode: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dataset)
    */
  dataset: domStringMap,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/nonce)
    */
  mutable nonce?: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autofocus)
    */
  mutable autofocus: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/tabIndex)
    */
  mutable tabIndex: int,
}

/**
Contains the descriptive information, or metadata, for a document. This object inherits all of the properties and methods described in the HTMLElement interface.
[See HTMLHeadElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLHeadElement)
*/
@editor.completeFrom(HTMLHeadElement) and htmlHeadElement = {
  // Base properties from HTMLElement
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/title)
    */
  mutable title: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/lang)
    */
  mutable lang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/translate)
    */
  mutable translate: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dir)
    */
  mutable dir: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/hidden)
    */
  mutable hidden: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/inert)
    */
  mutable inert: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKey)
    */
  mutable accessKey: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKeyLabel)
    */
  accessKeyLabel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/draggable)
    */
  mutable draggable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/spellcheck)
    */
  mutable spellcheck: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autocapitalize)
    */
  mutable autocapitalize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/innerText)
    */
  mutable innerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/outerText)
    */
  mutable outerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/popover)
    */
  mutable popover: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetParent)
    */
  offsetParent: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetTop)
    */
  offsetTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetLeft)
    */
  offsetLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetWidth)
    */
  offsetWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetHeight)
    */
  offsetHeight: int,
  // End base properties from HTMLElement

  // Base properties from Element
  /**
    Returns the namespace.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    Returns the namespace prefix.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/prefix)
    */
  prefix: Null.t<string>,
  /**
    Returns the local name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/localName)
    */
  localName: string,
  /**
    Returns the HTML-uppercased qualified name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/tagName)
    */
  tagName: string,
  /**
    Returns the value of element's id content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
    */
  mutable id: string,
  /**
    Returns the value of element's class content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/className)
    */
  mutable className: string,
  /**
    Allows for manipulation of element's class content attribute as a set of whitespace-separated tokens through a DOMTokenList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/classList)
    */
  classList: domTokenList,
  /**
    Returns the value of element's slot content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/slot)
    */
  mutable slot: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attributes)
    */
  attributes: namedNodeMap,
  /**
    Returns element's shadow root, if any, and if shadow root's mode is "open", and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/part)
    */
  part: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTop)
    */
  mutable scrollTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollLeft)
    */
  mutable scrollLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollWidth)
    */
  scrollWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollHeight)
    */
  scrollHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientTop)
    */
  clientTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientLeft)
    */
  clientLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientWidth)
    */
  clientWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientHeight)
    */
  clientHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/currentCSSZoom)
    */
  currentCSSZoom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/innerHTML)
    */
  mutable innerHTML: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/outerHTML)
    */
  mutable outerHTML: string,
  // End base properties from Element

  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node
}

/**
A <form> element in the DOM; it allows access to and in some cases modification of aspects of the form, as well as access to its component elements.
[See HTMLFormElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement)
*/
@editor.completeFrom(HTMLFormElement) and htmlFormElement = {
  // Base properties from HTMLElement
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/title)
    */
  mutable title: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/lang)
    */
  mutable lang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/translate)
    */
  mutable translate: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dir)
    */
  mutable dir: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/hidden)
    */
  mutable hidden: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/inert)
    */
  mutable inert: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKey)
    */
  mutable accessKey: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKeyLabel)
    */
  accessKeyLabel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/draggable)
    */
  mutable draggable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/spellcheck)
    */
  mutable spellcheck: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autocapitalize)
    */
  mutable autocapitalize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/innerText)
    */
  mutable innerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/outerText)
    */
  mutable outerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/popover)
    */
  mutable popover: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetParent)
    */
  offsetParent: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetTop)
    */
  offsetTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetLeft)
    */
  offsetLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetWidth)
    */
  offsetWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetHeight)
    */
  offsetHeight: int,
  // End base properties from HTMLElement

  // Base properties from Element
  /**
    Returns the namespace.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    Returns the namespace prefix.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/prefix)
    */
  prefix: Null.t<string>,
  /**
    Returns the local name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/localName)
    */
  localName: string,
  /**
    Returns the HTML-uppercased qualified name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/tagName)
    */
  tagName: string,
  /**
    Returns the value of element's id content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
    */
  mutable id: string,
  /**
    Returns the value of element's class content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/className)
    */
  mutable className: string,
  /**
    Allows for manipulation of element's class content attribute as a set of whitespace-separated tokens through a DOMTokenList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/classList)
    */
  classList: domTokenList,
  /**
    Returns the value of element's slot content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/slot)
    */
  mutable slot: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attributes)
    */
  attributes: namedNodeMap,
  /**
    Returns element's shadow root, if any, and if shadow root's mode is "open", and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/part)
    */
  part: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTop)
    */
  mutable scrollTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollLeft)
    */
  mutable scrollLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollWidth)
    */
  scrollWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollHeight)
    */
  scrollHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientTop)
    */
  clientTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientLeft)
    */
  clientLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientWidth)
    */
  clientWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientHeight)
    */
  clientHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/currentCSSZoom)
    */
  currentCSSZoom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/innerHTML)
    */
  mutable innerHTML: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/outerHTML)
    */
  mutable outerHTML: string,
  // End base properties from Element

  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    Sets or retrieves a list of character encodings for input data that must be accepted by the server processing the form.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/acceptCharset)
    */
  mutable acceptCharset: string,
  /**
    Sets or retrieves the URL to which the form content is sent for processing.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/action)
    */
  mutable action: string,
  /**
    Specifies whether autocomplete is applied to an editable text field.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/autocomplete)
    */
  mutable autocomplete: autoFillBase,
  /**
    Sets or retrieves the encoding type for the form.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/enctype)
    */
  mutable enctype: string,
  /**
    Sets or retrieves the MIME encoding for the form.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/encoding)
    */
  mutable encoding: string,
  /**
    Sets or retrieves how to send the form data to the server.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/method)
    */
  mutable method: string,
  /**
    Sets or retrieves the name of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/name)
    */
  mutable name: string,
  /**
    Sets or retrieves the window or frame at which to target content.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/target)
    */
  mutable target: string,
  /**
    Retrieves a collection, in source order, of all controls in a given form.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/elements)
    */
  elements: htmlFormControlsCollection,
  /**
    Sets or retrieves the number of objects in a collection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFormElement/length)
    */
  length: int,
}

/**
Provides special properties and methods for manipulating <img> elements.
[See HTMLImageElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement)
*/
@editor.completeFrom(HTMLImageElement) and htmlImageElement = {
  // Base properties from HTMLElement
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/title)
    */
  mutable title: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/lang)
    */
  mutable lang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/translate)
    */
  mutable translate: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dir)
    */
  mutable dir: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/hidden)
    */
  mutable hidden: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/inert)
    */
  mutable inert: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKey)
    */
  mutable accessKey: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKeyLabel)
    */
  accessKeyLabel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/draggable)
    */
  mutable draggable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/spellcheck)
    */
  mutable spellcheck: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autocapitalize)
    */
  mutable autocapitalize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/innerText)
    */
  mutable innerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/outerText)
    */
  mutable outerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/popover)
    */
  mutable popover: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetParent)
    */
  offsetParent: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetTop)
    */
  offsetTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetLeft)
    */
  offsetLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetWidth)
    */
  offsetWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetHeight)
    */
  offsetHeight: int,
  // End base properties from HTMLElement

  // Base properties from Element
  /**
    Returns the namespace.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    Returns the namespace prefix.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/prefix)
    */
  prefix: Null.t<string>,
  /**
    Returns the local name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/localName)
    */
  localName: string,
  /**
    Returns the HTML-uppercased qualified name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/tagName)
    */
  tagName: string,
  /**
    Returns the value of element's id content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
    */
  mutable id: string,
  /**
    Returns the value of element's class content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/className)
    */
  mutable className: string,
  /**
    Allows for manipulation of element's class content attribute as a set of whitespace-separated tokens through a DOMTokenList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/classList)
    */
  classList: domTokenList,
  /**
    Returns the value of element's slot content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/slot)
    */
  mutable slot: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attributes)
    */
  attributes: namedNodeMap,
  /**
    Returns element's shadow root, if any, and if shadow root's mode is "open", and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/part)
    */
  part: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTop)
    */
  mutable scrollTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollLeft)
    */
  mutable scrollLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollWidth)
    */
  scrollWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollHeight)
    */
  scrollHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientTop)
    */
  clientTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientLeft)
    */
  clientLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientWidth)
    */
  clientWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientHeight)
    */
  clientHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/currentCSSZoom)
    */
  currentCSSZoom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/innerHTML)
    */
  mutable innerHTML: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/outerHTML)
    */
  mutable outerHTML: string,
  // End base properties from Element

  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    Sets or retrieves a text alternative to the graphic.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/alt)
    */
  mutable alt: string,
  /**
    The address or URL of the a media resource that is to be considered.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/src)
    */
  mutable src: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/srcset)
    */
  mutable srcset: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/sizes)
    */
  mutable sizes: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/crossOrigin)
    */
  mutable crossOrigin: Null.t<string>,
  /**
    Sets or retrieves the URL, often with a bookmark extension (#name), to use as a client-side image map.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/useMap)
    */
  mutable useMap: string,
  /**
    Sets or retrieves whether the image is a server-side image map.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/isMap)
    */
  mutable isMap: bool,
  /**
    Sets or retrieves the width of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/width)
    */
  mutable width: int,
  /**
    Sets or retrieves the height of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/height)
    */
  mutable height: int,
  /**
    The original width of the image resource before sizing.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/naturalWidth)
    */
  naturalWidth: int,
  /**
    The original height of the image resource before sizing.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/naturalHeight)
    */
  naturalHeight: int,
  /**
    Retrieves whether the object is fully loaded.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/complete)
    */
  complete: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/currentSrc)
    */
  currentSrc: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/referrerPolicy)
    */
  mutable referrerPolicy: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/decoding)
    */
  mutable decoding: string,
  /**
    Sets or retrieves the policy for loading image elements that are outside the viewport.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/loading)
    */
  mutable loading: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/fetchPriority)
    */
  mutable fetchPriority: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/x)
    */
  x: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLImageElement/y)
    */
  y: int,
}

/**
Provides special properties (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating <embed> elements.
[See HTMLEmbedElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLEmbedElement)
*/
@editor.completeFrom(HTMLEmbedElement) and htmlEmbedElement = {
  // Base properties from HTMLElement
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/title)
    */
  mutable title: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/lang)
    */
  mutable lang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/translate)
    */
  mutable translate: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dir)
    */
  mutable dir: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/hidden)
    */
  mutable hidden: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/inert)
    */
  mutable inert: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKey)
    */
  mutable accessKey: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKeyLabel)
    */
  accessKeyLabel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/draggable)
    */
  mutable draggable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/spellcheck)
    */
  mutable spellcheck: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autocapitalize)
    */
  mutable autocapitalize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/innerText)
    */
  mutable innerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/outerText)
    */
  mutable outerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/popover)
    */
  mutable popover: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetParent)
    */
  offsetParent: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetTop)
    */
  offsetTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetLeft)
    */
  offsetLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetWidth)
    */
  offsetWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetHeight)
    */
  offsetHeight: int,
  // End base properties from HTMLElement

  // Base properties from Element
  /**
    Returns the namespace.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    Returns the namespace prefix.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/prefix)
    */
  prefix: Null.t<string>,
  /**
    Returns the local name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/localName)
    */
  localName: string,
  /**
    Returns the HTML-uppercased qualified name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/tagName)
    */
  tagName: string,
  /**
    Returns the value of element's id content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
    */
  mutable id: string,
  /**
    Returns the value of element's class content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/className)
    */
  mutable className: string,
  /**
    Allows for manipulation of element's class content attribute as a set of whitespace-separated tokens through a DOMTokenList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/classList)
    */
  classList: domTokenList,
  /**
    Returns the value of element's slot content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/slot)
    */
  mutable slot: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attributes)
    */
  attributes: namedNodeMap,
  /**
    Returns element's shadow root, if any, and if shadow root's mode is "open", and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/part)
    */
  part: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTop)
    */
  mutable scrollTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollLeft)
    */
  mutable scrollLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollWidth)
    */
  scrollWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollHeight)
    */
  scrollHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientTop)
    */
  clientTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientLeft)
    */
  clientLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientWidth)
    */
  clientWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientHeight)
    */
  clientHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/currentCSSZoom)
    */
  currentCSSZoom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/innerHTML)
    */
  mutable innerHTML: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/outerHTML)
    */
  mutable outerHTML: string,
  // End base properties from Element

  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    Sets or retrieves a URL to be loaded by the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLEmbedElement/src)
    */
  mutable src: string,
  /**
    Sets or retrieves the width of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLEmbedElement/width)
    */
  mutable width: string,
  /**
    Sets or retrieves the height of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLEmbedElement/height)
    */
  mutable height: string,
}

/**
Hyperlink elements and provides special properties and methods (beyond those of the regular HTMLElement object interface that they inherit from) for manipulating the layout and presentation of such elements.
[See HTMLAnchorElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement)
*/
@editor.completeFrom(HTMLAnchorElement) and htmlAnchorElement = {
  // Base properties from HTMLElement
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/title)
    */
  mutable title: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/lang)
    */
  mutable lang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/translate)
    */
  mutable translate: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dir)
    */
  mutable dir: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/hidden)
    */
  mutable hidden: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/inert)
    */
  mutable inert: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKey)
    */
  mutable accessKey: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKeyLabel)
    */
  accessKeyLabel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/draggable)
    */
  mutable draggable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/spellcheck)
    */
  mutable spellcheck: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autocapitalize)
    */
  mutable autocapitalize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/innerText)
    */
  mutable innerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/outerText)
    */
  mutable outerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/popover)
    */
  mutable popover: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetParent)
    */
  offsetParent: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetTop)
    */
  offsetTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetLeft)
    */
  offsetLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetWidth)
    */
  offsetWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetHeight)
    */
  offsetHeight: int,
  // End base properties from HTMLElement

  // Base properties from Element
  /**
    Returns the namespace.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    Returns the namespace prefix.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/prefix)
    */
  prefix: Null.t<string>,
  /**
    Returns the local name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/localName)
    */
  localName: string,
  /**
    Returns the HTML-uppercased qualified name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/tagName)
    */
  tagName: string,
  /**
    Returns the value of element's id content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
    */
  mutable id: string,
  /**
    Returns the value of element's class content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/className)
    */
  mutable className: string,
  /**
    Allows for manipulation of element's class content attribute as a set of whitespace-separated tokens through a DOMTokenList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/classList)
    */
  classList: domTokenList,
  /**
    Returns the value of element's slot content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/slot)
    */
  mutable slot: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attributes)
    */
  attributes: namedNodeMap,
  /**
    Returns element's shadow root, if any, and if shadow root's mode is "open", and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/part)
    */
  part: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTop)
    */
  mutable scrollTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollLeft)
    */
  mutable scrollLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollWidth)
    */
  scrollWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollHeight)
    */
  scrollHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientTop)
    */
  clientTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientLeft)
    */
  clientLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientWidth)
    */
  clientWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientHeight)
    */
  clientHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/currentCSSZoom)
    */
  currentCSSZoom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/innerHTML)
    */
  mutable innerHTML: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/outerHTML)
    */
  mutable outerHTML: string,
  // End base properties from Element

  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    Sets or retrieves the window or frame at which to target content.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/target)
    */
  mutable target: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/download)
    */
  mutable download: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/ping)
    */
  mutable ping: string,
  /**
    Sets or retrieves the relationship between the object and the destination of the link.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/rel)
    */
  mutable rel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/relList)
    */
  relList: domTokenList,
  /**
    Sets or retrieves the language code of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/hreflang)
    */
  mutable hreflang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/type)
    */
  @as("type")
  mutable type_: string,
  /**
    Retrieves or sets the text of the object as a string.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/text)
    */
  mutable text: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/referrerPolicy)
    */
  mutable referrerPolicy: string,
  /**
    Returns the hyperlink's URL.

Can be set, to change the URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/href)
    */
  mutable href: string,
  /**
    Returns the hyperlink's URL's origin.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/origin)
    */
  origin: string,
  /**
    Returns the hyperlink's URL's scheme.

Can be set, to change the URL's scheme.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/protocol)
    */
  mutable protocol: string,
  /**
    Returns the hyperlink's URL's username.

Can be set, to change the URL's username.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/username)
    */
  mutable username: string,
  /**
    Returns the hyperlink's URL's password.

Can be set, to change the URL's password.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/password)
    */
  mutable password: string,
  /**
    Returns the hyperlink's URL's host and port (if different from the default port for the scheme).

Can be set, to change the URL's host and port.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/host)
    */
  mutable host: string,
  /**
    Returns the hyperlink's URL's host.

Can be set, to change the URL's host.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/hostname)
    */
  mutable hostname: string,
  /**
    Returns the hyperlink's URL's port.

Can be set, to change the URL's port.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/port)
    */
  mutable port: string,
  /**
    Returns the hyperlink's URL's path.

Can be set, to change the URL's path.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/pathname)
    */
  mutable pathname: string,
  /**
    Returns the hyperlink's URL's query (includes leading "?" if non-empty).

Can be set, to change the URL's query (ignores leading "?").
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/search)
    */
  mutable search: string,
  /**
    Returns the hyperlink's URL's fragment (includes leading "#" if non-empty).

Can be set, to change the URL's fragment (ignores leading "#").
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/hash)
    */
  mutable hash: string,
}

/**
Provides special properties and methods (beyond those of the regular object HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of <area> elements.
[See HTMLAreaElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAreaElement)
*/
@editor.completeFrom(HTMLAreaElement) and htmlAreaElement = {
  // Base properties from HTMLElement
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/title)
    */
  mutable title: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/lang)
    */
  mutable lang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/translate)
    */
  mutable translate: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dir)
    */
  mutable dir: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/hidden)
    */
  mutable hidden: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/inert)
    */
  mutable inert: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKey)
    */
  mutable accessKey: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKeyLabel)
    */
  accessKeyLabel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/draggable)
    */
  mutable draggable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/spellcheck)
    */
  mutable spellcheck: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autocapitalize)
    */
  mutable autocapitalize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/innerText)
    */
  mutable innerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/outerText)
    */
  mutable outerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/popover)
    */
  mutable popover: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetParent)
    */
  offsetParent: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetTop)
    */
  offsetTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetLeft)
    */
  offsetLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetWidth)
    */
  offsetWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetHeight)
    */
  offsetHeight: int,
  // End base properties from HTMLElement

  // Base properties from Element
  /**
    Returns the namespace.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    Returns the namespace prefix.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/prefix)
    */
  prefix: Null.t<string>,
  /**
    Returns the local name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/localName)
    */
  localName: string,
  /**
    Returns the HTML-uppercased qualified name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/tagName)
    */
  tagName: string,
  /**
    Returns the value of element's id content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
    */
  mutable id: string,
  /**
    Returns the value of element's class content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/className)
    */
  mutable className: string,
  /**
    Allows for manipulation of element's class content attribute as a set of whitespace-separated tokens through a DOMTokenList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/classList)
    */
  classList: domTokenList,
  /**
    Returns the value of element's slot content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/slot)
    */
  mutable slot: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attributes)
    */
  attributes: namedNodeMap,
  /**
    Returns element's shadow root, if any, and if shadow root's mode is "open", and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/part)
    */
  part: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTop)
    */
  mutable scrollTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollLeft)
    */
  mutable scrollLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollWidth)
    */
  scrollWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollHeight)
    */
  scrollHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientTop)
    */
  clientTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientLeft)
    */
  clientLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientWidth)
    */
  clientWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientHeight)
    */
  clientHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/currentCSSZoom)
    */
  currentCSSZoom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/innerHTML)
    */
  mutable innerHTML: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/outerHTML)
    */
  mutable outerHTML: string,
  // End base properties from Element

  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    Sets or retrieves the window or frame at which to target content.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAreaElement/target)
    */
  mutable target: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAreaElement/ping)
    */
  mutable ping: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAreaElement/rel)
    */
  mutable rel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAreaElement/relList)
    */
  relList: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAreaElement/referrerPolicy)
    */
  mutable referrerPolicy: string,
  /**
    Returns the hyperlink's URL.

Can be set, to change the URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/href)
    */
  mutable href: string,
  /**
    Returns the hyperlink's URL's origin.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/origin)
    */
  origin: string,
  /**
    Returns the hyperlink's URL's scheme.

Can be set, to change the URL's scheme.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/protocol)
    */
  mutable protocol: string,
  /**
    Returns the hyperlink's URL's username.

Can be set, to change the URL's username.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/username)
    */
  mutable username: string,
  /**
    Returns the hyperlink's URL's password.

Can be set, to change the URL's password.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/password)
    */
  mutable password: string,
  /**
    Returns the hyperlink's URL's host and port (if different from the default port for the scheme).

Can be set, to change the URL's host and port.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/host)
    */
  mutable host: string,
  /**
    Returns the hyperlink's URL's host.

Can be set, to change the URL's host.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/hostname)
    */
  mutable hostname: string,
  /**
    Returns the hyperlink's URL's port.

Can be set, to change the URL's port.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/port)
    */
  mutable port: string,
  /**
    Returns the hyperlink's URL's path.

Can be set, to change the URL's path.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/pathname)
    */
  mutable pathname: string,
  /**
    Returns the hyperlink's URL's query (includes leading "?" if non-empty).

Can be set, to change the URL's query (ignores leading "?").
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/search)
    */
  mutable search: string,
  /**
    Returns the hyperlink's URL's fragment (includes leading "#" if non-empty).

Can be set, to change the URL's fragment (ignores leading "#").
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAnchorElement/hash)
    */
  mutable hash: string,
}

/**
HTML <script> elements expose the HTMLScriptElement interface, which provides special properties and methods for manipulating the behavior and execution of <script> elements (beyond the inherited HTMLElement interface).
[See HTMLScriptElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement)
*/
@editor.completeFrom(HTMLScriptElement) and htmlScriptElement = {
  // Base properties from HTMLElement
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/title)
    */
  mutable title: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/lang)
    */
  mutable lang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/translate)
    */
  mutable translate: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dir)
    */
  mutable dir: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/hidden)
    */
  mutable hidden: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/inert)
    */
  mutable inert: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKey)
    */
  mutable accessKey: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKeyLabel)
    */
  accessKeyLabel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/draggable)
    */
  mutable draggable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/spellcheck)
    */
  mutable spellcheck: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autocapitalize)
    */
  mutable autocapitalize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/innerText)
    */
  mutable innerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/outerText)
    */
  mutable outerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/popover)
    */
  mutable popover: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetParent)
    */
  offsetParent: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetTop)
    */
  offsetTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetLeft)
    */
  offsetLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetWidth)
    */
  offsetWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetHeight)
    */
  offsetHeight: int,
  // End base properties from HTMLElement

  // Base properties from Element
  /**
    Returns the namespace.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    Returns the namespace prefix.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/prefix)
    */
  prefix: Null.t<string>,
  /**
    Returns the local name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/localName)
    */
  localName: string,
  /**
    Returns the HTML-uppercased qualified name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/tagName)
    */
  tagName: string,
  /**
    Returns the value of element's id content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
    */
  mutable id: string,
  /**
    Returns the value of element's class content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/className)
    */
  mutable className: string,
  /**
    Allows for manipulation of element's class content attribute as a set of whitespace-separated tokens through a DOMTokenList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/classList)
    */
  classList: domTokenList,
  /**
    Returns the value of element's slot content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/slot)
    */
  mutable slot: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attributes)
    */
  attributes: namedNodeMap,
  /**
    Returns element's shadow root, if any, and if shadow root's mode is "open", and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/part)
    */
  part: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTop)
    */
  mutable scrollTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollLeft)
    */
  mutable scrollLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollWidth)
    */
  scrollWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollHeight)
    */
  scrollHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientTop)
    */
  clientTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientLeft)
    */
  clientLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientWidth)
    */
  clientWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientHeight)
    */
  clientHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/currentCSSZoom)
    */
  currentCSSZoom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/innerHTML)
    */
  mutable innerHTML: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/outerHTML)
    */
  mutable outerHTML: string,
  // End base properties from Element

  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    Retrieves the URL to an external file that contains the source code or data.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/src)
    */
  mutable src: string,
  /**
    Sets or retrieves the MIME type for the associated scripting engine.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/type)
    */
  @as("type")
  mutable type_: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/noModule)
    */
  mutable noModule: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/async)
    */
  mutable async: bool,
  /**
    Sets or retrieves the status of the script.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/defer)
    */
  mutable defer: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/crossOrigin)
    */
  mutable crossOrigin: Null.t<string>,
  /**
    Retrieves or sets the text of the object as a string.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/text)
    */
  mutable text: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/integrity)
    */
  mutable integrity: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/referrerPolicy)
    */
  mutable referrerPolicy: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLScriptElement/fetchPriority)
    */
  mutable fetchPriority: string,
}

/**
An object providing methods which are not dependent on any particular document. Such an object is returned by the Document.implementation property.
[See DOMImplementation on MDN](https://developer.mozilla.org/docs/Web/API/DOMImplementation)
*/
@editor.completeFrom(DOMImplementation) and domImplementation = {}

/**
A Node containing a doctype.
[See DocumentType on MDN](https://developer.mozilla.org/docs/Web/API/DocumentType)
*/
and documentType = {
  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentType/name)
    */
  name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentType/publicId)
    */
  publicId: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentType/systemId)
    */
  systemId: string,
}

/**
Any web page loaded in the browser and serves as an entry point into the web page's content, which is the DOM tree.
[See Document on MDN](https://developer.mozilla.org/docs/Web/API/Document)
*/
@editor.completeFrom(Document) and document = {
  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    Gets the implementation object of the current document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/implementation)
    */
  implementation: domImplementation,
  /**
    Sets or gets the URL for the current document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/URL)
    */
  @as("URL")
  uRL: string,
  /**
    Returns document's URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/documentURI)
    */
  documentURI: string,
  /**
    Gets a value that indicates whether standards-compliant mode is switched on for the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/compatMode)
    */
  compatMode: string,
  /**
    Returns document's encoding.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/characterSet)
    */
  characterSet: string,
  /**
    Returns document's content type.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/contentType)
    */
  contentType: string,
  /**
    Gets an object representing the document type declaration associated with the current document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/doctype)
    */
  doctype: Null.t<documentType>,
  /**
    Gets a reference to the root node of the document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/documentElement)
    */
  documentElement: htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/scrollingElement)
    */
  scrollingElement: Null.t<element>,
  /**
    Returns true if document has the ability to display elements fullscreen and fullscreen is supported, or false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/fullscreenEnabled)
    */
  fullscreenEnabled: bool,
  /**
    Contains information about the current URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/location)
    */
  mutable location: location,
  /**
    Gets the URL of the location that referred the user to the current page.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/referrer)
    */
  referrer: string,
  /**
    Returns the HTTP cookies that apply to the Document. If there are no cookies or cookies can't be applied to this resource, the empty string will be returned.

Can be set, to add a new cookie to the element's set of HTTP cookies.

If the contents are sandboxed into a unique origin (e.g. in an iframe with the sandbox attribute), a "SecurityError" DOMException will be thrown on getting and setting.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/cookie)
    */
  mutable cookie: string,
  /**
    Gets the date that the page was last modified, if the page supplies one.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/lastModified)
    */
  lastModified: string,
  /**
    Retrieves a value that indicates the current state of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/readyState)
    */
  readyState: documentReadyState,
  /**
    Contains the title of the document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/title)
    */
  mutable title: string,
  /**
    Sets or retrieves a value that indicates the reading order of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/dir)
    */
  mutable dir: string,
  /**
    Specifies the beginning and end of the document body.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/body)
    */
  mutable body: htmlElement,
  /**
    Returns the head element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/head)
    */
  head: htmlHeadElement,
  /**
    Retrieves a collection, in source order, of img objects in the document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/images)
    */
  images: htmlCollectionOf<htmlImageElement>,
  /**
    Retrieves a collection of all embed objects in the document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/embeds)
    */
  embeds: htmlCollectionOf<htmlEmbedElement>,
  /**
    Return an HTMLCollection of the embed elements in the Document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/plugins)
    */
  plugins: htmlCollectionOf<htmlEmbedElement>,
  /**
    Retrieves a collection of all a objects that specify the href property and all area objects in the document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/links)
    */
  links: htmlCollectionOf<any>,
  /**
    Retrieves a collection, in source order, of all form objects in the document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/forms)
    */
  forms: htmlCollectionOf<htmlFormElement>,
  /**
    Retrieves a collection of all script objects in the document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/scripts)
    */
  scripts: htmlCollectionOf<htmlScriptElement>,
  /**
    Returns the script element, or the SVG script element, that is currently executing, as long as the element represents a classic script. In the case of reentrant script execution, returns the one that most recently started executing amongst those that have not yet finished executing.

Returns null if the Document is not currently executing a script or SVG script element (e.g., because the running script is an event handler, or a timeout), or if the currently executing script or SVG script element represents a module script.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/currentScript)
    */
  currentScript: Null.t<htmlElement>,
  /**
    Returns the Window object of the active document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/defaultView)
    */
  defaultView: Null.t<window>,
  /**
    Sets or gets a value that indicates whether the document can be edited.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/designMode)
    */
  mutable designMode: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/hidden)
    */
  hidden: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/visibilityState)
    */
  visibilityState: documentVisibilityState,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/pictureInPictureEnabled)
    */
  pictureInPictureEnabled: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/fragmentDirective)
    */
  fragmentDirective: fragmentDirective,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/timeline)
    */
  timeline: documentTimeline,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/fonts)
    */
  fonts: fontFaceSet,
  /**
    Retrieves a collection of styleSheet objects representing the style sheets that correspond to each instance of a link or style object in the document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/styleSheets)
    */
  styleSheets: styleSheetList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/adoptedStyleSheets)
    */
  mutable adoptedStyleSheets: array<cssStyleSheet>,
  /**
    Returns document's fullscreen element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/fullscreenElement)
    */
  fullscreenElement: Null.t<element>,
  /**
    Returns the deepest element in the document through which or to which key events are being routed. This is, roughly speaking, the focused element in the document.

For the purposes of this API, when a child browsing context is focused, its container is focused in the parent browsing context. For example, if the user moves the focus to a text control in an iframe, the iframe is the element returned by the activeElement API in the iframe's node document.

Similarly, when the focused element is in a different node tree than documentOrShadowRoot, the element returned will be the host that's located in the same node tree as documentOrShadowRoot if documentOrShadowRoot is a shadow-including inclusive ancestor of the focused element, and null if not.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/activeElement)
    */
  activeElement: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/pictureInPictureElement)
    */
  pictureInPictureElement: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/pointerLockElement)
    */
  pointerLockElement: Null.t<element>,
  /**
    Returns the child elements.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/children)
    */
  children: htmlCollection,
  /**
    Returns the first child that is an element, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/firstElementChild)
    */
  firstElementChild: Null.t<element>,
  /**
    Returns the last child that is an element, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/lastElementChild)
    */
  lastElementChild: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/childElementCount)
    */
  childElementCount: int,
}

/**
A window containing a DOM document; the document property points to the DOM document loaded in that window.
[See Window on MDN](https://developer.mozilla.org/docs/Web/API/Window)
*/
@editor.completeFrom(Window) and window = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/window)
    */
  window: window,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/self)
    */
  self: window,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/document)
    */
  document: document,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/name)
    */
  mutable name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/location)
    */
  mutable location: location,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/history)
    */
  history: history,
  /**
    Defines a new custom element, mapping the given name to the given constructor as an autonomous custom element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/customElements)
    */
  customElements: customElementRegistry,
  /**
    Returns true if the location bar is visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/locationbar)
    */
  locationbar: barProp,
  /**
    Returns true if the menu bar is visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/menubar)
    */
  menubar: barProp,
  /**
    Returns true if the personal bar is visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/personalbar)
    */
  personalbar: barProp,
  /**
    Returns true if the scrollbars are visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollbars)
    */
  scrollbars: barProp,
  /**
    Returns true if the status bar is visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/statusbar)
    */
  statusbar: barProp,
  /**
    Returns true if the toolbar is visible; otherwise, returns false.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/toolbar)
    */
  toolbar: barProp,
  /**
    Returns true if the window has been closed, false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/closed)
    */
  closed: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/frames)
    */
  frames: window,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/length)
    */
  length: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/top)
    */
  top: Null.t<window>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/opener)
    */
  mutable opener: JSON.t,
  /**
    Refers to either the parent WindowProxy, or itself.

It can rarely be null e.g. for contentWindow of an iframe that is already removed from the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/parent)
    */
  parent: window,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/frameElement)
    */
  frameElement: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/navigator)
    */
  navigator: navigator,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screen)
    */
  screen: screen,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/visualViewport)
    */
  visualViewport: Null.t<visualViewport>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/innerWidth)
    */
  innerWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/innerHeight)
    */
  innerHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollX)
    */
  scrollX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/scrollY)
    */
  scrollY: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenX)
    */
  screenX: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenLeft)
    */
  screenLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenY)
    */
  screenY: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/screenTop)
    */
  screenTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/outerWidth)
    */
  outerWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/outerHeight)
    */
  outerHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/devicePixelRatio)
    */
  devicePixelRatio: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/speechSynthesis)
    */
  speechSynthesis: speechSynthesis,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/origin)
    */
  origin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/isSecureContext)
    */
  isSecureContext: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/crossOriginIsolated)
    */
  crossOriginIsolated: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/indexedDB)
    */
  indexedDB: idbFactory,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/crypto)
    */
  crypto: crypto,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/performance)
    */
  performance: performance,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/caches)
    */
  caches: cacheStorage,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/sessionStorage)
    */
  sessionStorage: storage,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Window/localStorage)
    */
  localStorage: storage,
}

/**
A MutationRecord represents an individual DOM mutation. It is the object that is passed to MutationObserver's callback.
[See MutationRecord on MDN](https://developer.mozilla.org/docs/Web/API/MutationRecord)
*/
and mutationRecord = {
  /**
    Returns "attributes" if it was an attribute mutation. "characterData" if it was a mutation to a CharacterData node. And "childList" if it was a mutation to the tree of nodes.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationRecord/type)
    */
  @as("type")
  type_: string,
  /**
    Returns the node the mutation affected, depending on the type. For "attributes", it is the element whose attribute changed. For "characterData", it is the CharacterData node. For "childList", it is the node whose children changed.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationRecord/target)
    */
  target: node,
  /**
    Return the nodes added and removed respectively.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationRecord/addedNodes)
    */
  addedNodes: nodeList,
  /**
    Return the nodes added and removed respectively.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationRecord/removedNodes)
    */
  removedNodes: nodeList,
  /**
    Return the previous and next sibling respectively of the added or removed nodes, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationRecord/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Return the previous and next sibling respectively of the added or removed nodes, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationRecord/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    Returns the local name of the changed attribute, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationRecord/attributeName)
    */
  attributeName: Null.t<string>,
  /**
    Returns the namespace of the changed attribute, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationRecord/attributeNamespace)
    */
  attributeNamespace: Null.t<string>,
  /**
    The return value depends on type. For "attributes", it is the value of the changed attribute before the change. For "characterData", it is the data of the changed node before the change. For "childList", it is null.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationRecord/oldValue)
    */
  oldValue: Null.t<string>,
}

/**
A DOM element's attribute as an object. In most DOM methods, you will probably directly retrieve the attribute as a string (e.g., Element.getAttribute(), but certain functions (e.g., Element.getAttributeNode()) or means of iterating give Attr types.
[See Attr on MDN](https://developer.mozilla.org/docs/Web/API/Attr)
*/
and attr = {
  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Attr/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Attr/prefix)
    */
  prefix: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Attr/localName)
    */
  localName: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Attr/name)
    */
  name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Attr/value)
    */
  mutable value: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Attr/ownerElement)
    */
  ownerElement: Null.t<element>,
}

/**
The CharacterData abstract interface represents a Node object that contains characters. This is an abstract interface, meaning there aren't any object of type CharacterData: it is implemented by other interfaces, like Text, Comment, or ProcessingInstruction which aren't abstract.
[See CharacterData on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData)
*/
@editor.completeFrom(CharacterData) and characterData = {
  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/data)
    */
  mutable data: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/length)
    */
  length: int,
  /**
    Returns the first preceding sibling that is an element, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/previousElementSibling)
    */
  previousElementSibling: Null.t<element>,
  /**
    Returns the first following sibling that is an element, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/nextElementSibling)
    */
  nextElementSibling: Null.t<element>,
}

/**
A minimal document object that has no parent. It is used as a lightweight version of Document that stores a segment of a document structure comprised of nodes just like a standard document. The key difference is that because the document fragment isn't part of the active document tree structure, changes made to the fragment don't affect the document, cause reflow, or incur any performance impact that can occur when changes are made.
[See DocumentFragment on MDN](https://developer.mozilla.org/docs/Web/API/DocumentFragment)
*/
@editor.completeFrom(DocumentFragment) and documentFragment = {
  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    Returns the child elements.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/children)
    */
  children: htmlCollection,
  /**
    Returns the first child that is an element, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/firstElementChild)
    */
  firstElementChild: Null.t<element>,
  /**
    Returns the last child that is an element, and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/lastElementChild)
    */
  lastElementChild: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/childElementCount)
    */
  childElementCount: int,
}

/**
[See HTMLSlotElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSlotElement)
*/
@editor.completeFrom(HTMLSlotElement) and htmlSlotElement = {
  // Base properties from HTMLElement
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/title)
    */
  mutable title: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/lang)
    */
  mutable lang: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/translate)
    */
  mutable translate: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dir)
    */
  mutable dir: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/hidden)
    */
  mutable hidden: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/inert)
    */
  mutable inert: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKey)
    */
  mutable accessKey: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/accessKeyLabel)
    */
  accessKeyLabel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/draggable)
    */
  mutable draggable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/spellcheck)
    */
  mutable spellcheck: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autocapitalize)
    */
  mutable autocapitalize: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/innerText)
    */
  mutable innerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/outerText)
    */
  mutable outerText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/popover)
    */
  mutable popover: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetParent)
    */
  offsetParent: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetTop)
    */
  offsetTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetLeft)
    */
  offsetLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetWidth)
    */
  offsetWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/offsetHeight)
    */
  offsetHeight: int,
  // End base properties from HTMLElement

  // Base properties from Element
  /**
    Returns the namespace.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/namespaceURI)
    */
  namespaceURI: Null.t<string>,
  /**
    Returns the namespace prefix.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/prefix)
    */
  prefix: Null.t<string>,
  /**
    Returns the local name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/localName)
    */
  localName: string,
  /**
    Returns the HTML-uppercased qualified name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/tagName)
    */
  tagName: string,
  /**
    Returns the value of element's id content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
    */
  mutable id: string,
  /**
    Returns the value of element's class content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/className)
    */
  mutable className: string,
  /**
    Allows for manipulation of element's class content attribute as a set of whitespace-separated tokens through a DOMTokenList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/classList)
    */
  classList: domTokenList,
  /**
    Returns the value of element's slot content attribute. Can be set to change it.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/slot)
    */
  mutable slot: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attributes)
    */
  attributes: namedNodeMap,
  /**
    Returns element's shadow root, if any, and if shadow root's mode is "open", and null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/part)
    */
  part: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTop)
    */
  mutable scrollTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollLeft)
    */
  mutable scrollLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollWidth)
    */
  scrollWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollHeight)
    */
  scrollHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientTop)
    */
  clientTop: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientLeft)
    */
  clientLeft: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientWidth)
    */
  clientWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/clientHeight)
    */
  clientHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/currentCSSZoom)
    */
  currentCSSZoom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/innerHTML)
    */
  mutable innerHTML: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/outerHTML)
    */
  mutable outerHTML: string,
  // End base properties from Element

  // Base properties from Node
  /**
    Returns the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
    */
  nodeType: int,
  /**
    Returns a string appropriate for the type of node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
    */
  nodeName: string,
  /**
    Returns node's node document's document base URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/baseURI)
    */
  baseURI: string,
  /**
    Returns true if node is connected and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/isConnected)
    */
  isConnected: bool,
  /**
    Returns the node document. Returns null for documents.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
    */
  ownerDocument: Null.t<document>,
  /**
    Returns the parent.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
    */
  parentNode: Null.t<node>,
  /**
    Returns the parent element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
    */
  parentElement: Null.t<htmlElement>,
  /**
    Returns the children.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
    */
  childNodes: nodeListOf<node>,
  /**
    Returns the first child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
    */
  firstChild: Null.t<node>,
  /**
    Returns the last child.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
    */
  lastChild: Null.t<node>,
  /**
    Returns the previous sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
    */
  previousSibling: Null.t<node>,
  /**
    Returns the next sibling.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
    */
  nextSibling: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/nodeValue)
    */
  mutable nodeValue: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Node/textContent)
    */
  mutable textContent: Null.t<string>,
  // End base properties from Node

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSlotElement/name)
    */
  mutable name: string,
}

/**
[See DOMRectReadOnly on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly)
*/
@editor.completeFrom(DOMRectReadOnly)
type domRectReadOnly = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/x)
    */
  x: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/y)
    */
  y: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/width)
    */
  width: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/height)
    */
  height: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/top)
    */
  top: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/right)
    */
  right: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/bottom)
    */
  bottom: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/left)
    */
  left: float,
}

/**
[See DOMRect on MDN](https://developer.mozilla.org/docs/Web/API/DOMRect)
*/
@editor.completeFrom(DOMRect)
type domRect = {
  ...domRectReadOnly,
}

@editor.completeFrom(DOMRectList) type domRectList = {}

/**
The validity states that an element can be in, with respect to constraint validation. Together, they help explain why an element's value fails to validate, if it's not valid.
[See ValidityState on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState)
*/
type validityState = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/valueMissing)
    */
  valueMissing: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/typeMismatch)
    */
  typeMismatch: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/patternMismatch)
    */
  patternMismatch: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/tooLong)
    */
  tooLong: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/tooShort)
    */
  tooShort: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/rangeUnderflow)
    */
  rangeUnderflow: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/rangeOverflow)
    */
  rangeOverflow: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/stepMismatch)
    */
  stepMismatch: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/badInput)
    */
  badInput: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/customError)
    */
  customError: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ValidityState/valid)
    */
  valid: bool,
}

/**
[See CustomStateSet on MDN](https://developer.mozilla.org/docs/Web/API/CustomStateSet)
*/
type customStateSet = {}

/**
[See ElementInternals on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals)
*/
@editor.completeFrom(ElementInternals)
type elementInternals = {
  /**
    Returns the ShadowRoot for internals's target element, if the target element is a shadow host, or null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/shadowRoot)
    */
  shadowRoot: Null.t<shadowRoot>,
  /**
    Returns the form owner of internals's target element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/form)
    */
  form: Null.t<htmlFormElement>,
  /**
    Returns true if internals's target element will be validated when the form is submitted; false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/willValidate)
    */
  willValidate: bool,
  /**
    Returns the ValidityState object for internals's target element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/validity)
    */
  validity: validityState,
  /**
    Returns the error message that would be shown to the user if internals's target element was to be checked for validity.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/validationMessage)
    */
  validationMessage: string,
  /**
    Returns a NodeList of all the label elements that internals's target element is associated with.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/labels)
    */
  labels: nodeList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/states)
    */
  states: customStateSet,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaAtomic)
    */
  mutable ariaAtomic: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaAutoComplete)
    */
  mutable ariaAutoComplete: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaBrailleLabel)
    */
  mutable ariaBrailleLabel: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaBrailleRoleDescription)
    */
  mutable ariaBrailleRoleDescription: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaBusy)
    */
  mutable ariaBusy: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaChecked)
    */
  mutable ariaChecked: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaColCount)
    */
  mutable ariaColCount: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaColIndex)
    */
  mutable ariaColIndex: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaColIndexText)
    */
  mutable ariaColIndexText: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaColSpan)
    */
  mutable ariaColSpan: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaCurrent)
    */
  mutable ariaCurrent: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaDescription)
    */
  mutable ariaDescription: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaDisabled)
    */
  mutable ariaDisabled: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaExpanded)
    */
  mutable ariaExpanded: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaHasPopup)
    */
  mutable ariaHasPopup: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaHidden)
    */
  mutable ariaHidden: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaKeyShortcuts)
    */
  mutable ariaKeyShortcuts: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaLabel)
    */
  mutable ariaLabel: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaLevel)
    */
  mutable ariaLevel: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaLive)
    */
  mutable ariaLive: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaModal)
    */
  mutable ariaModal: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaMultiLine)
    */
  mutable ariaMultiLine: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaMultiSelectable)
    */
  mutable ariaMultiSelectable: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaOrientation)
    */
  mutable ariaOrientation: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaPlaceholder)
    */
  mutable ariaPlaceholder: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaPosInSet)
    */
  mutable ariaPosInSet: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaPressed)
    */
  mutable ariaPressed: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaReadOnly)
    */
  mutable ariaReadOnly: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRequired)
    */
  mutable ariaRequired: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRoleDescription)
    */
  mutable ariaRoleDescription: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRowCount)
    */
  mutable ariaRowCount: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRowIndex)
    */
  mutable ariaRowIndex: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRowIndexText)
    */
  mutable ariaRowIndexText: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaRowSpan)
    */
  mutable ariaRowSpan: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaSelected)
    */
  mutable ariaSelected: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaSetSize)
    */
  mutable ariaSetSize: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaSort)
    */
  mutable ariaSort: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaValueMax)
    */
  mutable ariaValueMax: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaValueMin)
    */
  mutable ariaValueMin: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaValueNow)
    */
  mutable ariaValueNow: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/ariaValueText)
    */
  mutable ariaValueText: Null.t<string>,
}

/**
An XML document. It inherits from the generic Document and does not add any specific methods or properties to it: nevertheless, several algorithms behave differently with the two types of documents.
[See XMLDocument on MDN](https://developer.mozilla.org/docs/Web/API/XMLDocument)
*/
type xmlDocument = {
  ...document,
}

/**
@editor.completeFrom(Text) The textual content of Element or Attr. If an element has no markup within its content, it has a single child implementing Text that contains the element's text. However, if the element contains markup, it is parsed into information items and Text nodes that form its children.
[See Text on MDN](https://developer.mozilla.org/docs/Web/API/Text)
*/
@editor.completeFrom(Text)
type text = {
  ...characterData,
  /**
    Returns the combined data of all direct Text node siblings.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Text/wholeText)
    */
  wholeText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/assignedSlot)
    */
  assignedSlot: Null.t<htmlSlotElement>,
}

/**
A CDATA section that can be used within XML to include extended portions of unescaped text. The symbols < and & don’t need escaping as they normally do when inside a CDATA section.
[See CDATASection on MDN](https://developer.mozilla.org/docs/Web/API/CDATASection)
*/
type cdataSection = {
  ...text,
}

/**
Textual notations within markup; although it is generally not visually shown, such comments are available to be read in the source view.
[See Comment on MDN](https://developer.mozilla.org/docs/Web/API/Comment)
*/
@editor.completeFrom(Comment)
type comment = {
  ...characterData,
}

/**
A processing instruction embeds application-specific instructions in XML which can be ignored by other applications that don't recognize them.
[See ProcessingInstruction on MDN](https://developer.mozilla.org/docs/Web/API/ProcessingInstruction)
*/
type processingInstruction = {
  ...characterData,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ProcessingInstruction/target)
    */
  target: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/sheet)
    */
  sheet: Null.t<cssStyleSheet>,
}

/**
[See AbstractRange on MDN](https://developer.mozilla.org/docs/Web/API/AbstractRange)
*/
type abstractRange = {
  /**
    Returns range's start node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbstractRange/startContainer)
    */
  startContainer: node,
  /**
    Returns range's start offset.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbstractRange/startOffset)
    */
  startOffset: int,
  /**
    Returns range's end node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbstractRange/endContainer)
    */
  endContainer: node,
  /**
    Returns range's end offset.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbstractRange/endOffset)
    */
  endOffset: int,
  /**
    Returns true if range is collapsed, and false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbstractRange/collapsed)
    */
  collapsed: bool,
}

/**
A fragment of a document that can contain nodes and parts of text nodes.
[See Range on MDN](https://developer.mozilla.org/docs/Web/API/Range)
*/
@editor.completeFrom(Range)
type range = {
  ...abstractRange,
  /**
    Returns the node, furthest away from the document, that is an ancestor of both range's start node and end node.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Range/commonAncestorContainer)
    */
  commonAncestorContainer: node,
}

/**
[See StaticRange on MDN](https://developer.mozilla.org/docs/Web/API/StaticRange)
*/
type staticRange = {
  ...abstractRange,
}

@editor.completeFrom(NodeFilter) type nodeFilter = {}

/**
An iterator over the members of a list of the nodes in a subtree of the DOM. The nodes will be returned in document order.
[See NodeIterator on MDN](https://developer.mozilla.org/docs/Web/API/NodeIterator)
*/
@editor.completeFrom(NodeIterator)
type nodeIterator = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeIterator/root)
    */
  root: node,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeIterator/referenceNode)
    */
  referenceNode: node,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeIterator/pointerBeforeReferenceNode)
    */
  pointerBeforeReferenceNode: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeIterator/whatToShow)
    */
  whatToShow: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeIterator/filter)
    */
  filter: Null.t<nodeFilter>,
}

/**
The nodes of a document subtree and a position within them.
[See TreeWalker on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker)
*/
@editor.completeFrom(TreeWalker)
type treeWalker = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/root)
    */
  root: node,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/whatToShow)
    */
  whatToShow: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/filter)
    */
  filter: Null.t<nodeFilter>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/currentNode)
    */
  mutable currentNode: node,
}

/**
[See CaretPosition on MDN](https://developer.mozilla.org/docs/Web/API/CaretPosition)
*/
@editor.completeFrom(CaretPosition)
type caretPosition = {}

/**
A Selection object represents the range of text selected by the user or the current position of the caret. To obtain a Selection object for examination or modification, call Window.getSelection().
[See Selection on MDN](https://developer.mozilla.org/docs/Web/API/Selection)
*/
@editor.completeFrom(Selection)
type selection = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/anchorNode)
    */
  anchorNode: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/anchorOffset)
    */
  anchorOffset: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/focusNode)
    */
  focusNode: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/focusOffset)
    */
  focusOffset: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/isCollapsed)
    */
  isCollapsed: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/rangeCount)
    */
  rangeCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/type)
    */
  @as("type")
  type_: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Selection/direction)
    */
  direction: string,
}

/**
Stores information on a media query applied to a document, and handles sending notifications to listeners when the media query state change (i.e. when the media query test starts or stops evaluating to true).
[See MediaQueryList on MDN](https://developer.mozilla.org/docs/Web/API/MediaQueryList)
*/
@editor.completeFrom(MediaQueryList)
type mediaQueryList = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaQueryList/media)
    */
  media: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaQueryList/matches)
    */
  matches: bool,
}

/**
[See IdleDeadline on MDN](https://developer.mozilla.org/docs/Web/API/IdleDeadline)
*/
@editor.completeFrom(IdleDeadline)
type idleDeadline = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IdleDeadline/didTimeout)
    */
  didTimeout: bool,
}

/**
[See CSSStyleValue on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleValue)
*/
@editor.completeFrom(CSSStyleValue)
type cssStyleValue = {}

/**
An object of this type is returned by the files property of the HTML <input> element; this lets you access the list of files selected with the <input type="file"> element. It's also used for a list of files dropped into web content when using the drag and drop API; see the DataTransfer object for details on this usage.
[See FileList on MDN](https://developer.mozilla.org/docs/Web/API/FileList)
*/
@editor.completeFrom(FileList)
type fileList = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileList/length)
    */
  length: int,
}

/**
An error which occurred while handling media in an HTML media element based on HTMLMediaElement, such as <audio> or <video>.
[See MediaError on MDN](https://developer.mozilla.org/docs/Web/API/MediaError)
*/
type mediaError = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaError/code)
    */
  code: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaError/message)
    */
  message: string,
}

/**
Used to represent a set of time ranges, primarily for the purpose of tracking which portions of media have been buffered when loading it for use by the <audio> and <video> elements.
[See TimeRanges on MDN](https://developer.mozilla.org/docs/Web/API/TimeRanges)
*/
@editor.completeFrom(TimeRanges)
type timeRanges = {
  /**
    Returns the number of ranges in the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TimeRanges/length)
    */
  length: int,
}

/**
[See TextTrackList on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackList)
*/
@editor.completeFrom(TextTrackList)
type textTrackList = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackList/length)
    */
  length: int,
}

/**
Returned by the HTMLVideoElement.getVideoPlaybackQuality() method and contains metrics that can be used to determine the playback quality of a video.
[See VideoPlaybackQuality on MDN](https://developer.mozilla.org/docs/Web/API/VideoPlaybackQuality)
*/
type videoPlaybackQuality = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoPlaybackQuality/creationTime)
    */
  creationTime: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoPlaybackQuality/droppedVideoFrames)
    */
  droppedVideoFrames: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoPlaybackQuality/totalVideoFrames)
    */
  totalVideoFrames: int,
}

/**
Provides special properties and methods (beyond the regular HTMLElement object interface it also has available to it by inheritance) for manipulating the layout and presentation of tables in an HTML document.
[See HTMLTableElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement)
*/
@editor.completeFrom(HTMLTableElement)
type rec htmlTableElement = {
  ...htmlElement,
  /**
    Retrieves the caption object of a table.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/caption)
    */
  mutable caption: Null.t<htmlTableCaptionElement>,
  /**
    Retrieves the tHead object of the table.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/tHead)
    */
  mutable tHead: Null.t<htmlTableSectionElement>,
  /**
    Retrieves the tFoot object of the table.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/tFoot)
    */
  mutable tFoot: Null.t<htmlTableSectionElement>,
  /**
    Retrieves a collection of all tBody objects in the table. Objects in this collection are in source order.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/tBodies)
    */
  tBodies: htmlCollectionOf<htmlTableSectionElement>,
  /**
    Sets or retrieves the number of horizontal rows contained in the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableElement/rows)
    */
  rows: htmlCollectionOf<htmlTableRowElement>,
}

/**
Special properties (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating table caption elements.
[See HTMLTableCaptionElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableCaptionElement)
*/
@editor.completeFrom(HTMLTableCaptionElement) and htmlTableCaptionElement = {
  ...htmlElement,
}

/**
Provides special properties and methods (beyond the HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of sections, that is headers, footers and bodies, in an HTML table.
[See HTMLTableSectionElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableSectionElement)
*/
@editor.completeFrom(HTMLTableSectionElement) and htmlTableSectionElement = {
  ...htmlElement,
  /**
    Sets or retrieves the number of horizontal rows contained in the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableSectionElement/rows)
    */
  rows: htmlCollectionOf<htmlTableRowElement>,
}

/**
Provides special properties and methods (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of table cells, either header or data cells, in an HTML document.
[See HTMLTableCellElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableCellElement)
*/
@editor.completeFrom(HTMLTableCellElement) and htmlTableCellElement = {
  ...htmlElement,
  /**
    Sets or retrieves the number columns in the table that the object should span.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableCellElement/colSpan)
    */
  mutable colSpan: int,
  /**
    Sets or retrieves how many rows in a table the cell should span.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableCellElement/rowSpan)
    */
  mutable rowSpan: int,
  /**
    Sets or retrieves a list of header cells that provide information for the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableCellElement/headers)
    */
  mutable headers: string,
  /**
    Retrieves the position of the object in the cells collection of a row.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableCellElement/cellIndex)
    */
  cellIndex: int,
  /**
    Sets or retrieves the group of cells in a table to which the object's information applies.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableCellElement/scope)
    */
  mutable scope: string,
  /**
    Sets or retrieves abbreviated text for the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableCellElement/abbr)
    */
  mutable abbr: string,
}

/**
Provides special properties and methods (beyond the HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of rows in an HTML table.
[See HTMLTableRowElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableRowElement)
*/
@editor.completeFrom(HTMLTableRowElement) and htmlTableRowElement = {
  ...htmlElement,
  /**
    Retrieves the position of the object in the rows collection for the table.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableRowElement/rowIndex)
    */
  rowIndex: int,
  /**
    Retrieves the position of the object in the collection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableRowElement/sectionRowIndex)
    */
  sectionRowIndex: int,
  /**
    Retrieves a collection of all cells in the table row.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTableRowElement/cells)
    */
  cells: htmlCollectionOf<htmlTableCellElement>,
}

/**
Provides properties and methods (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating <button> elements.
[See HTMLButtonElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement)
*/
@editor.completeFrom(HTMLButtonElement)
type rec htmlButtonElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/disabled)
    */
  mutable disabled: bool,
  /**
    Retrieves a reference to the form that the object is embedded in.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/form)
    */
  form: Null.t<htmlFormElement>,
  /**
    Overrides the action attribute (where the data on a form is sent) on the parent form element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/formAction)
    */
  mutable formAction: string,
  /**
    Used to override the encoding (formEnctype attribute) specified on the form element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/formEnctype)
    */
  mutable formEnctype: string,
  /**
    Overrides the submit method attribute previously specified on a form element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/formMethod)
    */
  mutable formMethod: string,
  /**
    Sets or retrieves the name of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/name)
    */
  mutable name: string,
  /**
    Gets the classification and default behavior of the button.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/type)
    */
  @as("type")
  mutable type_: string,
  /**
    Sets or retrieves the default or selected value of the control.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/value)
    */
  mutable value: string,
  /**
    Returns whether an element will successfully validate based on forms validation rules and constraints.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/willValidate)
    */
  willValidate: bool,
  /**
    Returns a  ValidityState object that represents the validity states of an element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/validity)
    */
  validity: validityState,
  /**
    Returns the error message that would be displayed if the user submits the form, or an empty string if no error message. It also triggers the standard error message, such as "this is a required field". The result is that the user sees validation messages without actually submitting.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/validationMessage)
    */
  validationMessage: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/labels)
    */
  labels: nodeListOf<htmlLabelElement>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/popoverTargetElement)
    */
  mutable popoverTargetElement: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/popoverTargetAction)
    */
  mutable popoverTargetAction: string,
}

/**
Gives access to properties specific to <label> elements. It inherits methods and properties from the base HTMLElement interface.
[See HTMLLabelElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLabelElement)
*/
@editor.completeFrom(HTMLLabelElement) and htmlLabelElement = {
  ...htmlElement,
  /**
    Retrieves a reference to the form that the object is embedded in.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLabelElement/form)
    */
  form: Null.t<htmlFormElement>,
  /**
    Sets or retrieves the object to which the given label object is assigned.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLabelElement/htmlFor)
    */
  mutable htmlFor: string,
  /**
    Returns the form control that is associated with this element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLabelElement/control)
    */
  control: Null.t<htmlElement>,
}

/**
Provides special properties and methods for manipulating the layout and presentation of <textarea> elements.
[See HTMLTextAreaElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement)
*/
@editor.completeFrom(HTMLTextAreaElement) and htmlTextAreaElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/autocomplete)
    */
  mutable autocomplete: string,
  /**
    Sets or retrieves the width of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/cols)
    */
  mutable cols: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/disabled)
    */
  mutable disabled: bool,
  /**
    Retrieves a reference to the form that the object is embedded in.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/form)
    */
  form: Null.t<htmlFormElement>,
  /**
    Sets or retrieves the maximum number of characters that the user can enter in a text control.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/maxLength)
    */
  mutable maxLength: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/minLength)
    */
  mutable minLength: int,
  /**
    Sets or retrieves the name of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/name)
    */
  mutable name: string,
  /**
    Gets or sets a text string that is displayed in an input field as a hint or prompt to users as the format or type of information they need to enter.The text appears in an input field until the user puts focus on the field.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/placeholder)
    */
  mutable placeholder: string,
  /**
    Sets or retrieves the value indicated whether the content of the object is read-only.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/readOnly)
    */
  mutable readOnly: bool,
  /**
    When present, marks an element that can't be submitted without a value.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/required)
    */
  mutable required: bool,
  /**
    Sets or retrieves the number of horizontal rows contained in the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/rows)
    */
  mutable rows: int,
  /**
    Sets or retrieves how to handle wordwrapping in the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/wrap)
    */
  mutable wrap: string,
  /**
    Retrieves the type of control.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/type)
    */
  @as("type")
  type_: string,
  /**
    Sets or retrieves the initial contents of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/defaultValue)
    */
  mutable defaultValue: string,
  /**
    Retrieves or sets the text in the entry field of the textArea element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/value)
    */
  mutable value: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/textLength)
    */
  textLength: int,
  /**
    Returns whether an element will successfully validate based on forms validation rules and constraints.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/willValidate)
    */
  willValidate: bool,
  /**
    Returns a  ValidityState object that represents the validity states of an element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/validity)
    */
  validity: validityState,
  /**
    Returns the error message that would be displayed if the user submits the form, or an empty string if no error message. It also triggers the standard error message, such as "this is a required field". The result is that the user sees validation messages without actually submitting.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/validationMessage)
    */
  validationMessage: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/labels)
    */
  labels: nodeListOf<htmlLabelElement>,
  /**
    Gets or sets the starting position or offset of a text selection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/selectionStart)
    */
  mutable selectionStart: int,
  /**
    Gets or sets the end position or offset of a text selection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/selectionEnd)
    */
  mutable selectionEnd: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTextAreaElement/selectionDirection)
    */
  mutable selectionDirection: string,
}

/**
Provides properties and methods (beyond those inherited from HTMLElement) for manipulating the layout and presentation of <output> elements.
[See HTMLOutputElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement)
*/
@editor.completeFrom(HTMLOutputElement) and htmlOutputElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/htmlFor)
    */
  htmlFor: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/form)
    */
  form: Null.t<htmlFormElement>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/name)
    */
  mutable name: string,
  /**
    Returns the string "output".
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/type)
    */
  @as("type")
  type_: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/defaultValue)
    */
  mutable defaultValue: string,
  /**
    Returns the element's current value.

Can be set, to change the value.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/value)
    */
  mutable value: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/willValidate)
    */
  willValidate: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/validity)
    */
  validity: validityState,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/validationMessage)
    */
  validationMessage: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOutputElement/labels)
    */
  labels: nodeListOf<htmlLabelElement>,
}

/**
Provides special properties and methods for manipulating the options, layout, and presentation of <input> elements.
[See HTMLInputElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement)
*/
@editor.completeFrom(HTMLInputElement) and htmlInputElement = {
  ...htmlElement,
  /**
    Sets or retrieves a comma-separated list of content types.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/accept)
    */
  mutable accept: string,
  /**
    Sets or retrieves a text alternative to the graphic.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/alt)
    */
  mutable alt: string,
  /**
    Specifies whether autocomplete is applied to an editable text field.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/autocomplete)
    */
  mutable autocomplete: string,
  /**
    Sets or retrieves the state of the check box or radio button.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/defaultChecked)
    */
  mutable defaultChecked: bool,
  /**
    Sets or retrieves the state of the check box or radio button.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/checked)
    */
  mutable checked: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/disabled)
    */
  mutable disabled: bool,
  /**
    Retrieves a reference to the form that the object is embedded in.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/form)
    */
  form: Null.t<htmlFormElement>,
  /**
    Returns a FileList object on a file type input object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/files)
    */
  mutable files: Null.t<fileList>,
  /**
    Overrides the action attribute (where the data on a form is sent) on the parent form element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/formAction)
    */
  mutable formAction: string,
  /**
    Used to override the encoding (formEnctype attribute) specified on the form element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/formEnctype)
    */
  mutable formEnctype: string,
  /**
    Overrides the submit method attribute previously specified on a form element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/formMethod)
    */
  mutable formMethod: string,
  /**
    Sets or retrieves the height of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/height)
    */
  mutable height: int,
  /**
    When set, overrides the rendering of checkbox controls so that the current value is not visible.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/indeterminate)
    */
  mutable indeterminate: bool,
  /**
    Specifies the ID of a pre-defined datalist of options for an input element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/list)
    */
  list: Null.t<htmlDataListElement>,
  /**
    Defines the maximum acceptable value for an input element with type="number".When used with the min and step attributes, lets you control the range and increment (such as only even numbers) that the user can enter into an input field.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/max)
    */
  mutable max: string,
  /**
    Sets or retrieves the maximum number of characters that the user can enter in a text control.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/maxLength)
    */
  mutable maxLength: int,
  /**
    Defines the minimum acceptable value for an input element with type="number". When used with the max and step attributes, lets you control the range and increment (such as even numbers only) that the user can enter into an input field.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/min)
    */
  mutable min: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/minLength)
    */
  mutable minLength: int,
  /**
    Sets or retrieves the Boolean value indicating whether multiple items can be selected from a list.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/multiple)
    */
  mutable multiple: bool,
  /**
    Sets or retrieves the name of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/name)
    */
  mutable name: string,
  /**
    Gets or sets a string containing a regular expression that the user's input must match.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/pattern)
    */
  mutable pattern: string,
  /**
    Gets or sets a text string that is displayed in an input field as a hint or prompt to users as the format or type of information they need to enter.The text appears in an input field until the user puts focus on the field.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/placeholder)
    */
  mutable placeholder: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/readOnly)
    */
  mutable readOnly: bool,
  /**
    When present, marks an element that can't be submitted without a value.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/required)
    */
  mutable required: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/size)
    */
  mutable size: int,
  /**
    The address or URL of the a media resource that is to be considered.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/src)
    */
  mutable src: string,
  /**
    Defines an increment or jump between values that you want to allow the user to enter. When used with the max and min attributes, lets you control the range and increment (for example, allow only even numbers) that the user can enter into an input field.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/step)
    */
  mutable step: string,
  /**
    Returns the content type of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/type)
    */
  @as("type")
  mutable type_: string,
  /**
    Sets or retrieves the initial contents of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/defaultValue)
    */
  mutable defaultValue: string,
  /**
    Returns the value of the data at the cursor's current position.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/value)
    */
  mutable value: string,
  /**
    Returns a Date object representing the form control's value, if applicable; otherwise, returns null. Can be set, to change the value. Throws an "InvalidStateError" DOMException if the control isn't date- or time-based.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/valueAsDate)
    */
  mutable valueAsDate: Null.t<Date.t>,
  /**
    Returns the input field value as a number.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/valueAsNumber)
    */
  mutable valueAsNumber: float,
  /**
    Sets or retrieves the width of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/width)
    */
  mutable width: int,
  /**
    Returns whether an element will successfully validate based on forms validation rules and constraints.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/willValidate)
    */
  willValidate: bool,
  /**
    Returns a  ValidityState object that represents the validity states of an element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/validity)
    */
  validity: validityState,
  /**
    Returns the error message that would be displayed if the user submits the form, or an empty string if no error message. It also triggers the standard error message, such as "this is a required field". The result is that the user sees validation messages without actually submitting.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/validationMessage)
    */
  validationMessage: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/labels)
    */
  labels: Null.t<nodeListOf<htmlLabelElement>>,
  /**
    Gets or sets the starting position or offset of a text selection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/selectionStart)
    */
  mutable selectionStart: Null.t<int>,
  /**
    Gets or sets the end position or offset of a text selection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/selectionEnd)
    */
  mutable selectionEnd: Null.t<int>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/selectionDirection)
    */
  mutable selectionDirection: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/webkitdirectory)
    */
  mutable webkitdirectory: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/webkitEntries)
    */
  webkitEntries: array<fileSystemEntry>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLInputElement/capture)
    */
  mutable capture: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/popoverTargetElement)
    */
  mutable popoverTargetElement: Null.t<element>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLButtonElement/popoverTargetAction)
    */
  mutable popoverTargetAction: string,
}

/**
Provides special properties (beyond the HTMLElement object interface it also has available to it by inheritance) to manipulate <datalist> elements and their content.
[See HTMLDataListElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDataListElement)
*/
@editor.completeFrom(HTMLDataListElement) and htmlDataListElement = {
  ...htmlElement,
  /**
    Returns an HTMLCollection of the option elements of the datalist element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDataListElement/options)
    */
  options: htmlCollectionOf<htmlOptionElement>,
}

/**
A <select> HTML Element. These elements also share all of the properties and methods of other HTML elements via the HTMLElement interface.
[See HTMLSelectElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement)
*/
@editor.completeFrom(HTMLSelectElement) and htmlSelectElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/disabled)
    */
  mutable disabled: bool,
  /**
    Retrieves a reference to the form that the object is embedded in.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/form)
    */
  form: Null.t<htmlFormElement>,
  /**
    Sets or retrieves the Boolean value indicating whether multiple items can be selected from a list.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/multiple)
    */
  mutable multiple: bool,
  /**
    Sets or retrieves the name of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/name)
    */
  mutable name: string,
  /**
    When present, marks an element that can't be submitted without a value.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/required)
    */
  mutable required: bool,
  /**
    Sets or retrieves the number of rows in the list box.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/size)
    */
  mutable size: int,
  /**
    Retrieves the type of select control based on the value of the MULTIPLE attribute.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/type)
    */
  @as("type")
  type_: string,
  /**
    Returns an HTMLOptionsCollection of the list of options.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/options)
    */
  options: htmlOptionsCollection,
  /**
    Sets or retrieves the number of objects in a collection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/length)
    */
  mutable length: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/selectedOptions)
    */
  selectedOptions: htmlCollectionOf<htmlOptionElement>,
  /**
    Sets or retrieves the index of the selected option in a select object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/selectedIndex)
    */
  mutable selectedIndex: int,
  /**
    Sets or retrieves the value which is returned to the server when the form control is submitted.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/value)
    */
  mutable value: string,
  /**
    Returns whether an element will successfully validate based on forms validation rules and constraints.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/willValidate)
    */
  willValidate: bool,
  /**
    Returns a  ValidityState object that represents the validity states of an element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/validity)
    */
  validity: validityState,
  /**
    Returns the error message that would be displayed if the user submits the form, or an empty string if no error message. It also triggers the standard error message, such as "this is a required field". The result is that the user sees validation messages without actually submitting.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/validationMessage)
    */
  validationMessage: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/labels)
    */
  labels: nodeListOf<htmlLabelElement>,
}

/**
<option> elements and inherits all classes and methods of the HTMLElement interface.
[See HTMLOptionElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionElement)
*/
@editor.completeFrom(HTMLOptionElement) and htmlOptionElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionElement/disabled)
    */
  mutable disabled: bool,
  /**
    Retrieves a reference to the form that the object is embedded in.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionElement/form)
    */
  form: Null.t<htmlFormElement>,
  /**
    Sets or retrieves a value that you can use to implement your own label functionality for the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionElement/label)
    */
  mutable label: string,
  /**
    Sets or retrieves the status of an option.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionElement/defaultSelected)
    */
  mutable defaultSelected: bool,
  /**
    Sets or retrieves whether the option in the list box is the default item.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionElement/selected)
    */
  mutable selected: bool,
  /**
    Sets or retrieves the value which is returned to the server when the form control is submitted.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionElement/value)
    */
  mutable value: string,
  /**
    Sets or retrieves the text string specified by the option tag.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionElement/text)
    */
  mutable text: string,
  /**
    Sets or retrieves the ordinal position of an option in a list box.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionElement/index)
    */
  index: int,
}

/**
HTMLOptionsCollection is an interface representing a collection of HTML option elements (in document order) and offers methods and properties for traversing the list as well as optionally altering its items. This type is returned solely by the "options" property of select.
[See HTMLOptionsCollection on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionsCollection)
*/
@editor.completeFrom(HTMLOptionsCollection) and htmlOptionsCollection = {
  ...htmlCollectionOf<htmlOptionElement>,
  /**
    Returns the index of the first selected item, if any, or −1 if there is no selected item.

Can be set, to change the selection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionsCollection/selectedIndex)
    */
  mutable selectedIndex: int,
}

type mediaProvider = any

/**
Adds to HTMLElement the properties and methods needed to support basic media-related capabilities that are common to audio and video.
[See HTMLMediaElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement)
*/
@editor.completeFrom(HTMLMediaElement)
type htmlMediaElement = {
  ...htmlElement,
  /**
    Returns an object representing the current error state of the audio or video element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/error)
    */
  error: Null.t<mediaError>,
  /**
    The address or URL of the a media resource that is to be considered.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/src)
    */
  mutable src: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/srcObject)
    */
  mutable srcObject: Null.t<mediaProvider>,
  /**
    Gets the address or URL of the current media resource that is selected by IHTMLMediaElement.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/currentSrc)
    */
  currentSrc: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/crossOrigin)
    */
  mutable crossOrigin: Null.t<string>,
  /**
    Gets the current network activity for the element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/networkState)
    */
  networkState: int,
  /**
    Gets or sets a value indicating what data should be preloaded, if any.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/preload)
    */
  mutable preload: string,
  /**
    Gets a collection of buffered time ranges.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/buffered)
    */
  buffered: timeRanges,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/readyState)
    */
  readyState: int,
  /**
    Gets or sets the current playback position, in seconds.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/currentTime)
    */
  mutable currentTime: float,
  /**
    Returns the duration in seconds of the current media resource. A NaN value is returned if duration is not available, or Infinity if the media resource is streaming.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/duration)
    */
  duration: float,
  /**
    Gets a flag that specifies whether playback is paused.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/paused)
    */
  paused: bool,
  /**
    Gets or sets the default playback rate when the user is not using fast forward or reverse for a video or audio resource.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/defaultPlaybackRate)
    */
  mutable defaultPlaybackRate: float,
  /**
    Gets or sets the current rate of speed for the media resource to play. This speed is expressed as a multiple of the normal speed of the media resource.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/playbackRate)
    */
  mutable playbackRate: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/preservesPitch)
    */
  mutable preservesPitch: bool,
  /**
    Returns a TimeRanges object that represents the ranges of the current media resource that can be seeked.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/seekable)
    */
  seekable: timeRanges,
  /**
    Gets information about whether the playback has ended or not.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/ended)
    */
  ended: bool,
  /**
    Gets or sets a value that indicates whether to start playing the media automatically.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/autoplay)
    */
  mutable autoplay: bool,
  /**
    Gets or sets a flag to specify whether playback should restart after it completes.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/loop)
    */
  mutable loop: bool,
  /**
    Gets or sets a flag that indicates whether the client provides a set of controls for the media (in case the developer does not include controls for the player).
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/controls)
    */
  mutable controls: bool,
  /**
    Gets or sets the volume level for audio portions of the media element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/volume)
    */
  mutable volume: float,
  /**
    Gets or sets a flag that indicates whether the audio (either audio or the audio track on video media) is muted.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/muted)
    */
  mutable muted: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/defaultMuted)
    */
  mutable defaultMuted: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/textTracks)
    */
  textTracks: textTrackList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/sinkId)
    */
  sinkId: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/mediaKeys)
    */
  mediaKeys: Null.t<mediaKeys>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/remote)
    */
  remote: remotePlayback,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/disableRemotePlayback)
    */
  mutable disableRemotePlayback: bool,
}

/**
Provides access to the properties of <audio> elements, as well as methods to manipulate them. It derives from the HTMLMediaElement interface.
[See HTMLAudioElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLAudioElement)
*/
@editor.completeFrom(HTMLAudioElement)
type htmlAudioElement = {
  ...htmlMediaElement,
}

/**
Contains the base URI for a document. This object inherits all of the properties and methods as described in the HTMLElement interface.
[See HTMLBaseElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLBaseElement)
*/
@editor.completeFrom(HTMLBaseElement)
type htmlBaseElement = {
  ...htmlElement,
  /**
    Gets or sets the baseline URL on which relative links are based.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLBaseElement/href)
    */
  mutable href: string,
  /**
    Sets or retrieves the window or frame at which to target content.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLBaseElement/target)
    */
  mutable target: string,
}

/**
Provides special properties (beyond those inherited from the regular HTMLElement interface) for manipulating <body> elements.
[See HTMLBodyElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLBodyElement)
*/
@editor.completeFrom(HTMLBodyElement)
type htmlBodyElement = {
  ...htmlElement,
}

/**
A HTML line break element (<br>). It inherits from HTMLElement.
[See HTMLBRElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLBRElement)
*/
@editor.completeFrom(HTMLBRElement)
type htmlbrElement = {
  ...htmlElement,
}

/**
Provides properties and methods for manipulating the layout and presentation of <canvas> elements. The HTMLCanvasElement interface also inherits the properties and methods of the HTMLElement interface.
[See HTMLCanvasElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement)
*/
@editor.completeFrom(HTMLCanvasElement)
type htmlCanvasElement = {
  ...htmlElement,
  /**
    Gets or sets the width of a canvas element on a document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement/width)
    */
  mutable width: int,
  /**
    Gets or sets the height of a canvas element on a document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement/height)
    */
  mutable height: int,
}

/**
Provides special properties (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating <data> elements.
[See HTMLDataElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDataElement)
*/
@editor.completeFrom(HTMLDataElement)
type htmlDataElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDataElement/value)
    */
  mutable value: string,
}

/**
[See HTMLDialogElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDialogElement)
*/
@editor.completeFrom(HTMLDialogElement)
type htmlDialogElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDialogElement/open)
    */
  @as("open")
  mutable open_: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDialogElement/returnValue)
    */
  mutable returnValue: string,
}

/**
Provides special properties (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating <div> elements.
[See HTMLDivElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDivElement)
*/
@editor.completeFrom(HTMLDivElement)
type htmlDivElement = {
  ...htmlElement,
}

/**
Provides special properties (beyond those of the regular HTMLElement interface it also has available to it by inheritance) for manipulating definition list (<dl>) elements.
[See HTMLDListElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDListElement)
*/
@editor.completeFrom(HTMLDListElement)
type htmldListElement = {
  ...htmlElement,
}

/**
Provides special properties and methods (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of <fieldset> elements.
[See HTMLFieldSetElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement)
*/
@editor.completeFrom(HTMLFieldSetElement)
type htmlFieldSetElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/disabled)
    */
  mutable disabled: bool,
  /**
    Retrieves a reference to the form that the object is embedded in.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/form)
    */
  form: Null.t<htmlFormElement>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/name)
    */
  mutable name: string,
  /**
    Returns the string "fieldset".
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/type)
    */
  @as("type")
  type_: string,
  /**
    Returns an HTMLCollection of the form controls in the element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/elements)
    */
  elements: htmlCollection,
  /**
    Returns whether an element will successfully validate based on forms validation rules and constraints.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/willValidate)
    */
  willValidate: bool,
  /**
    Returns a  ValidityState object that represents the validity states of an element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/validity)
    */
  validity: validityState,
  /**
    Returns the error message that would be displayed if the user submits the form, or an empty string if no error message. It also triggers the standard error message, such as "this is a required field". The result is that the user sees validation messages without actually submitting.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement/validationMessage)
    */
  validationMessage: string,
}

/**
Provides special properties (beyond those of the regular HTMLElement interface they also inherit) for manipulating <frameset> elements.
[See HTMLFrameSetElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFrameSetElement)
*/
@editor.completeFrom(HTMLFrameSetElement)
type htmlFrameSetElement = {
  ...htmlElement,
}

/**
The different heading elements. It inherits methods and properties from the HTMLElement interface.
[See HTMLHeadingElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLHeadingElement)
*/
@editor.completeFrom(HTMLHeadingElement)
type htmlHeadingElement = {
  ...htmlElement,
}

/**
Provides special properties (beyond those of the HTMLElement interface it also has available to it by inheritance) for manipulating <hr> elements.
[See HTMLHRElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLHRElement)
*/
@editor.completeFrom(HTMLHRElement)
type htmlhrElement = {
  ...htmlElement,
}

/**
Serves as the root node for a given HTML document. This object inherits the properties and methods described in the HTMLElement interface.
[See HTMLHtmlElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLHtmlElement)
*/
@editor.completeFrom(HTMLHtmlElement)
type htmlHtmlElement = {
  ...htmlElement,
}

/**
Provides special properties and methods (beyond those of the HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of inline frame elements.
[See HTMLIFrameElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement)
*/
@editor.completeFrom(HTMLIFrameElement)
type htmliFrameElement = {
  ...htmlElement,
  /**
    Sets or retrieves a URL to be loaded by the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/src)
    */
  mutable src: string,
  /**
    Sets or retrives the content of the page that is to contain.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/srcdoc)
    */
  mutable srcdoc: string,
  /**
    Sets or retrieves the frame name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/name)
    */
  mutable name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/sandbox)
    */
  sandbox: domTokenList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/allow)
    */
  mutable allow: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/allowFullscreen)
    */
  mutable allowFullscreen: bool,
  /**
    Sets or retrieves the width of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/width)
    */
  mutable width: string,
  /**
    Sets or retrieves the height of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/height)
    */
  mutable height: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/referrerPolicy)
    */
  mutable referrerPolicy: referrerPolicy,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/loading)
    */
  mutable loading: string,
  /**
    Retrieves the document object of the page or frame.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/contentDocument)
    */
  contentDocument: Null.t<document>,
  /**
    Retrieves the object of the specified.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement/contentWindow)
    */
  contentWindow: Null.t<window>,
}

/**
The HTMLLegendElement is an interface allowing to access properties of the <legend> elements. It inherits properties and methods from the HTMLElement interface.
[See HTMLLegendElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLegendElement)
*/
@editor.completeFrom(HTMLLegendElement)
type htmlLegendElement = {
  ...htmlElement,
  /**
    Retrieves a reference to the form that the object is embedded in.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLegendElement/form)
    */
  form: Null.t<htmlFormElement>,
}

/**
Exposes specific properties and methods (beyond those defined by regular HTMLElement interface it also has available to it by inheritance) for manipulating list elements.
[See HTMLLIElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLIElement)
*/
@editor.completeFrom(HTMLLIElement)
type htmlliElement = {
  ...htmlElement,
}

/**
Reference information for external resources and the relationship of those resources to a document and vice-versa. This object inherits all of the properties and methods of the HTMLElement interface.
[See HTMLLinkElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement)
*/
@editor.completeFrom(HTMLLinkElement)
type htmlLinkElement = {
  ...htmlElement,
  /**
    Sets or retrieves a destination URL or an anchor point.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/href)
    */
  mutable href: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/crossOrigin)
    */
  mutable crossOrigin: Null.t<string>,
  /**
    Sets or retrieves the relationship between the object and the destination of the link.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/rel)
    */
  mutable rel: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/as)
    */
  @as("as")
  mutable as_: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/relList)
    */
  relList: domTokenList,
  /**
    Sets or retrieves the media type.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/media)
    */
  mutable media: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/integrity)
    */
  mutable integrity: string,
  /**
    Sets or retrieves the language code of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/hreflang)
    */
  mutable hreflang: string,
  /**
    Sets or retrieves the MIME type of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/type)
    */
  @as("type")
  mutable type_: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/referrerPolicy)
    */
  mutable referrerPolicy: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/disabled)
    */
  mutable disabled: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/fetchPriority)
    */
  mutable fetchPriority: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/sheet)
    */
  sheet: Null.t<cssStyleSheet>,
}

/**
Provides special properties and methods (beyond those of the regular object HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of map elements.
[See HTMLMapElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMapElement)
*/
@editor.completeFrom(HTMLMapElement)
type htmlMapElement = {
  ...htmlElement,
  /**
    Sets or retrieves the name of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMapElement/name)
    */
  mutable name: string,
  /**
    Retrieves a collection of the area objects defined for the given map object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMapElement/areas)
    */
  areas: htmlCollection,
}

/**
[See HTMLMenuElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMenuElement)
*/
@editor.completeFrom(HTMLMenuElement)
type htmlMenuElement = {
  ...htmlElement,
}

/**
Contains descriptive metadata about a document. It inherits all of the properties and methods described in the HTMLElement interface.
[See HTMLMetaElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMetaElement)
*/
@editor.completeFrom(HTMLMetaElement)
type htmlMetaElement = {
  ...htmlElement,
  /**
    Sets or retrieves the value specified in the content attribute of the meta object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMetaElement/name)
    */
  mutable name: string,
  /**
    Gets or sets information used to bind the value of a content attribute of a meta element to an HTTP response header.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMetaElement/httpEquiv)
    */
  mutable httpEquiv: string,
  /**
    Gets or sets meta-information to associate with httpEquiv or name.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMetaElement/content)
    */
  mutable content: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMetaElement/media)
    */
  mutable media: string,
}

/**
The HTML <meter> elements expose the HTMLMeterElement interface, which provides special properties and methods (beyond the HTMLElement object interface they also have available to them by inheritance) for manipulating the layout and presentation of <meter> elements.
[See HTMLMeterElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMeterElement)
*/
@editor.completeFrom(HTMLMeterElement)
type htmlMeterElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMeterElement/value)
    */
  mutable value: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMeterElement/min)
    */
  mutable min: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMeterElement/max)
    */
  mutable max: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMeterElement/low)
    */
  mutable low: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMeterElement/high)
    */
  mutable high: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMeterElement/optimum)
    */
  mutable optimum: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMeterElement/labels)
    */
  labels: nodeListOf<htmlLabelElement>,
}

/**
Provides special properties (beyond the regular methods and properties available through the HTMLElement interface they also have available to them by inheritance) for manipulating modification elements, that is <del> and <ins>.
[See HTMLModElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLModElement)
*/
@editor.completeFrom(HTMLModElement)
type htmlModElement = {
  ...htmlElement,
}

/**
Provides special properties and methods (beyond those on the HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of <object> element, representing external resources.
[See HTMLObjectElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement)
*/
@editor.completeFrom(HTMLObjectElement)
type htmlObjectElement = {
  ...htmlElement,
  /**
    Sets or retrieves the URL that references the data of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/data)
    */
  mutable data: string,
  /**
    Sets or retrieves the MIME type of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/type)
    */
  @as("type")
  mutable type_: string,
  /**
    Sets or retrieves the name of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/name)
    */
  mutable name: string,
  /**
    Retrieves a reference to the form that the object is embedded in.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/form)
    */
  form: Null.t<htmlFormElement>,
  /**
    Sets or retrieves the width of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/width)
    */
  mutable width: string,
  /**
    Sets or retrieves the height of the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/height)
    */
  mutable height: string,
  /**
    Retrieves the document object of the page or frame.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/contentDocument)
    */
  contentDocument: Null.t<document>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/contentWindow)
    */
  contentWindow: Null.t<window>,
  /**
    Returns whether an element will successfully validate based on forms validation rules and constraints.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/willValidate)
    */
  willValidate: bool,
  /**
    Returns a  ValidityState object that represents the validity states of an element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/validity)
    */
  validity: validityState,
  /**
    Returns the error message that would be displayed if the user submits the form, or an empty string if no error message. It also triggers the standard error message, such as "this is a required field". The result is that the user sees validation messages without actually submitting.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement/validationMessage)
    */
  validationMessage: string,
}

/**
Provides special properties (beyond those defined on the regular HTMLElement interface it also has available to it by inheritance) for manipulating ordered list elements.
[See HTMLOListElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOListElement)
*/
@editor.completeFrom(HTMLOListElement)
type htmloListElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOListElement/reversed)
    */
  mutable reversed: bool,
  /**
    The starting number.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOListElement/start)
    */
  mutable start: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOListElement/type)
    */
  @as("type")
  mutable type_: string,
}

/**
Provides special properties and methods (beyond the regular HTMLElement object interface they also have available to them by inheritance) for manipulating the layout and presentation of <optgroup> elements.
[See HTMLOptGroupElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptGroupElement)
*/
@editor.completeFrom(HTMLOptGroupElement)
type htmlOptGroupElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptGroupElement/disabled)
    */
  mutable disabled: bool,
  /**
    Sets or retrieves a value that you can use to implement your own label functionality for the object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptGroupElement/label)
    */
  mutable label: string,
}

/**
Provides special properties (beyond those of the regular HTMLElement object interface it inherits) for manipulating <p> elements.
[See HTMLParagraphElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLParagraphElement)
*/
@editor.completeFrom(HTMLParagraphElement)
type htmlParagraphElement = {
  ...htmlElement,
}

/**
A <picture> HTML element. It doesn't implement specific properties or methods.
[See HTMLPictureElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLPictureElement)
*/
@editor.completeFrom(HTMLPictureElement)
type htmlPictureElement = {
  ...htmlElement,
}

/**
Exposes specific properties and methods (beyond those of the HTMLElement interface it also has available to it by inheritance) for manipulating a block of preformatted text (<pre>).
[See HTMLPreElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLPreElement)
*/
@editor.completeFrom(HTMLPreElement)
type htmlPreElement = {
  ...htmlElement,
}

/**
Provides special properties and methods (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of <progress> elements.
[See HTMLProgressElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLProgressElement)
*/
@editor.completeFrom(HTMLProgressElement)
type htmlProgressElement = {
  ...htmlElement,
  /**
    Sets or gets the current value of a progress element. The value must be a non-negative number between 0 and the max value.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLProgressElement/value)
    */
  mutable value: float,
  /**
    Defines the maximum, or "done" value for a progress element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLProgressElement/max)
    */
  mutable max: float,
  /**
    Returns the quotient of value/max when the value attribute is set (determinate progress bar), or -1 when the value attribute is missing (indeterminate progress bar).
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLProgressElement/position)
    */
  position: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLProgressElement/labels)
    */
  labels: nodeListOf<htmlLabelElement>,
}

/**
Provides special properties and methods (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating quoting elements, like <blockquote> and <q>, but not the <cite> element.
[See HTMLQuoteElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLQuoteElement)
*/
@editor.completeFrom(HTMLQuoteElement)
type htmlQuoteElement = {
  ...htmlElement,
}

/**
Provides special properties (beyond the regular HTMLElement object interface it also has available to it by inheritance) for manipulating <source> elements.
[See HTMLSourceElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSourceElement)
*/
@editor.completeFrom(HTMLSourceElement)
type htmlSourceElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSourceElement/width)
    */
  mutable width: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSourceElement/height)
    */
  mutable height: int,
}

/**
A <span> element and derives from the HTMLElement interface, but without implementing any additional properties or methods.
[See HTMLSpanElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSpanElement)
*/
@editor.completeFrom(HTMLSpanElement)
type htmlSpanElement = {
  ...htmlElement,
}

/**
A <style> element. It inherits properties and methods from its parent, HTMLElement, and from LinkStyle.
[See HTMLStyleElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLStyleElement)
*/
@editor.completeFrom(HTMLStyleElement)
type htmlStyleElement = {
  ...htmlElement,
  /**
    Enables or disables the style sheet.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLStyleElement/disabled)
    */
  mutable disabled: bool,
  /**
    Sets or retrieves the media type.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLStyleElement/media)
    */
  mutable media: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement/sheet)
    */
  sheet: Null.t<cssStyleSheet>,
}

/**
Enables access to the contents of an HTML <template> element.
[See HTMLTemplateElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTemplateElement)
*/
@editor.completeFrom(HTMLTemplateElement)
type htmlTemplateElement = {
  ...htmlElement,
  /**
    Returns the template contents (a DocumentFragment).
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTemplateElement/content)
    */
  content: documentFragment,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTemplateElement/shadowRootMode)
    */
  mutable shadowRootMode: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTemplateElement/shadowRootDelegatesFocus)
    */
  mutable shadowRootDelegatesFocus: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTemplateElement/shadowRootClonable)
    */
  mutable shadowRootClonable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTemplateElement/shadowRootSerializable)
    */
  mutable shadowRootSerializable: bool,
}

/**
Provides special properties (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating <time> elements.
[See HTMLTimeElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTimeElement)
*/
@editor.completeFrom(HTMLTimeElement)
type htmlTimeElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTimeElement/dateTime)
    */
  mutable dateTime: string,
}

/**
Contains the title for a document. This element inherits all of the properties and methods of the HTMLElement interface.
[See HTMLTitleElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTitleElement)
*/
@editor.completeFrom(HTMLTitleElement)
type htmlTitleElement = {
  ...htmlElement,
  /**
    Retrieves or sets the text of the object as a string.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTitleElement/text)
    */
  mutable text: string,
}

/**
The HTMLTrackElement
[See HTMLTrackElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTrackElement)
*/
@editor.completeFrom(HTMLTrackElement)
type htmlTrackElement = {
  ...htmlElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLTrackElement/src)
    */
  mutable src: string,
}

/**
Provides special properties (beyond those defined on the regular HTMLElement interface it also has available to it by inheritance) for manipulating unordered list elements.
[See HTMLUListElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLUListElement)
*/
@editor.completeFrom(HTMLUListElement)
type htmluListElement = {
  ...htmlElement,
}

/**
An invalid HTML element and derives from the HTMLElement interface, but without implementing any additional properties or methods.
[See HTMLUnknownElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLUnknownElement)
*/
type htmlUnknownElement = {
  ...htmlElement,
}

/**
Provides special properties and methods for manipulating video objects. It also inherits properties and methods of HTMLMediaElement and HTMLElement.
[See HTMLVideoElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement)
*/
@editor.completeFrom(HTMLVideoElement)
type htmlVideoElement = {
  ...htmlMediaElement,
  /**
    Gets or sets the width of the video element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement/width)
    */
  mutable width: int,
  /**
    Gets or sets the height of the video element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement/height)
    */
  mutable height: int,
  /**
    Gets the intrinsic width of a video in CSS pixels, or zero if the dimensions are not known.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement/videoWidth)
    */
  videoWidth: int,
  /**
    Gets the intrinsic height of a video in CSS pixels, or zero if the dimensions are not known.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement/videoHeight)
    */
  videoHeight: int,
  /**
    Gets or sets a URL of an image to display, for example, like a movie poster. This can be a still frame from the video, or another image if no video data is available.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement/poster)
    */
  mutable poster: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement/disablePictureInPicture)
    */
  mutable disablePictureInPicture: bool,
}

/**
[See AnimationEffect on MDN](https://developer.mozilla.org/docs/Web/API/AnimationEffect)
*/
@editor.completeFrom(AnimationEffect)
type animationEffect = {}

/**
This interface is a compiled XPath expression that can be evaluated on a document or specific node to return information its DOM tree.
[See XPathExpression on MDN](https://developer.mozilla.org/docs/Web/API/XPathExpression)
*/
@editor.completeFrom(XPathExpression)
type xPathExpression = {}

/**
The results generated by evaluating an XPath expression within the context of a given node.
[See XPathResult on MDN](https://developer.mozilla.org/docs/Web/API/XPathResult)
*/
@editor.completeFrom(XPathResult)
type xPathResult = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/XPathResult/resultType)
    */
  resultType: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/XPathResult/numberValue)
    */
  numberValue: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/XPathResult/stringValue)
    */
  stringValue: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/XPathResult/booleanValue)
    */
  booleanValue: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/XPathResult/singleNodeValue)
    */
  singleNodeValue: Null.t<node>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/XPathResult/invalidIteratorState)
    */
  invalidIteratorState: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/XPathResult/snapshotLength)
    */
  snapshotLength: int,
}

/**
Used for attributes of type SVGPreserveAspectRatio which can be animated.
[See SVGAnimatedPreserveAspectRatio on MDN](https://developer.mozilla.org/docs/Web/API/SVGAnimatedPreserveAspectRatio)
*/
type svgAnimatedPreserveAspectRatio = {}

/**
Correspond to the <length> basic data type.
[See SVGLength on MDN](https://developer.mozilla.org/docs/Web/API/SVGLength)
*/
@editor.completeFrom(SVGLength)
type svgLength = {}

/**
Used for attributes of basic type <length> which can be animated.
[See SVGAnimatedLength on MDN](https://developer.mozilla.org/docs/Web/API/SVGAnimatedLength)
*/
type svgAnimatedLength = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/SVGAnimatedLength/baseVal)
    */
  baseVal: svgLength,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/SVGAnimatedLength/animVal)
    */
  animVal: svgLength,
}

/**
All of the SVG DOM interfaces that correspond directly to elements in the SVG language derive from the SVGElement interface.
[See SVGElement on MDN](https://developer.mozilla.org/docs/Web/API/SVGElement)
*/
type svgElement = {
  ...element,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/dataset)
    */
  dataset: domStringMap,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/nonce)
    */
  mutable nonce?: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/autofocus)
    */
  mutable autofocus: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/tabIndex)
    */
  mutable tabIndex: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/style)
    */
  style: cssStyleDeclaration,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/attributeStyleMap)
    */
  attributeStyleMap: stylePropertyMap,
}

/**
SVG elements whose primary purpose is to directly render graphics into a group.
[See SVGGraphicsElement on MDN](https://developer.mozilla.org/docs/Web/API/SVGGraphicsElement)
*/
@editor.completeFrom(SVGGraphicsElement)
type svgGraphicsElement = {
  ...svgElement,
}

/**
Corresponds to the <image> element.
[See SVGImageElement on MDN](https://developer.mozilla.org/docs/Web/API/SVGImageElement)
*/
type svgImageElement = {
  ...svgGraphicsElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/SVGImageElement/x)
    */
  x: svgAnimatedLength,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/SVGImageElement/y)
    */
  y: svgAnimatedLength,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/SVGImageElement/width)
    */
  width: svgAnimatedLength,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/SVGImageElement/height)
    */
  height: svgAnimatedLength,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/SVGImageElement/preserveAspectRatio)
    */
  preserveAspectRatio: svgAnimatedPreserveAspectRatio,
}

/**
[See DOMMatrixReadOnly on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly)
*/
@editor.completeFrom(DOMMatrixReadOnly)
type domMatrixReadOnly = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  a: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  b: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  c: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  d: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  e: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  f: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m11: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m12: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m13: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m14: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m21: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m22: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m23: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m24: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m31: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m32: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m33: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m34: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m41: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m42: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m43: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly#instance_properties)
    */
  m44: float,
}

/**
[See DOMMatrix on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrix)
*/
@editor.completeFrom(DOMMatrix)
type domMatrix = {
  ...domMatrixReadOnly,
}

/**
[See VideoColorSpace on MDN](https://developer.mozilla.org/docs/Web/API/VideoColorSpace)
*/
@editor.completeFrom(VideoColorSpace)
type videoColorSpace = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoColorSpace/primaries)
    */
  primaries: Null.t<videoColorPrimaries>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoColorSpace/transfer)
    */
  transfer: Null.t<videoTransferCharacteristics>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoColorSpace/matrix)
    */
  matrix: Null.t<videoMatrixCoefficients>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoColorSpace/fullRange)
    */
  fullRange: Null.t<bool>,
}

/**
[See VideoFrame on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@editor.completeFrom(VideoFrame)
type videoFrame = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/format)
    */
  format: Null.t<videoPixelFormat>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/codedWidth)
    */
  codedWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/codedHeight)
    */
  codedHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/codedRect)
    */
  codedRect: Null.t<domRectReadOnly>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/visibleRect)
    */
  visibleRect: Null.t<domRectReadOnly>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/displayWidth)
    */
  displayWidth: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/displayHeight)
    */
  displayHeight: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/duration)
    */
  duration: Null.t<int>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/timestamp)
    */
  timestamp: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/colorSpace)
    */
  colorSpace: videoColorSpace,
}

/**
The underlying pixel data of an area of a <canvas> element. It is created using the ImageData() constructor or creator methods on the CanvasRenderingContext2D object associated with a canvas: createImageData() and getImageData(). It can also be used to set a part of the canvas by using putImageData().
[See ImageData on MDN](https://developer.mozilla.org/docs/Web/API/ImageData)
*/
@editor.completeFrom(ImageData)
type imageData = {
  /**
    Returns the actual dimensions of the data in the ImageData object, in pixels.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageData/width)
    */
  width: int,
  /**
    Returns the actual dimensions of the data in the ImageData object, in pixels.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageData/height)
    */
  height: int,
  /**
    Returns the one-dimensional array containing the data in RGBA order, as integers in the range 0 to 255.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageData/data)
    */
  data: array<int>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageData/colorSpace)
    */
  colorSpace: predefinedColorSpace,
}

/**
[See DOMPointReadOnly on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly)
*/
@editor.completeFrom(DOMPointReadOnly)
type domPointReadOnly = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/x)
    */
  x: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/y)
    */
  y: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/z)
    */
  z: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/w)
    */
  w: float,
}

/**
[See DOMPoint on MDN](https://developer.mozilla.org/docs/Web/API/DOMPoint)
*/
@editor.completeFrom(DOMPoint)
type domPoint = {
  ...domPointReadOnly,
}

/**
 [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/getContext#contextattributes)
 */
type canvasContext2DAttributes = {
  alpha: bool,
  colorspace?: predefinedColorSpace,
  desynchronized: bool,
  willReadFrequently: bool,
}

/**
The CanvasRenderingContext2D interface, part of the Canvas API, provides the 2D rendering context for the drawing surface of a <canvas> element. It is used for drawing shapes, text, images, and other objects.
[See CanvasRenderingContext2D on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D)
*/
@editor.completeFrom(CanvasRenderingContext2D)
type canvasRenderingContext2D = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/canvas)
    */
  canvas: htmlCanvasElement,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/globalAlpha)
    */
  mutable globalAlpha: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/globalCompositeOperation)
    */
  mutable globalCompositeOperation: globalCompositeOperation,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/imageSmoothingEnabled)
    */
  mutable imageSmoothingEnabled: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/imageSmoothingQuality)
    */
  mutable imageSmoothingQuality: imageSmoothingQuality,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/strokeStyle)
    */
  mutable strokeStyle: fillStyle,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fillStyle)
    */
  mutable fillStyle: fillStyle,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/shadowOffsetX)
    */
  mutable shadowOffsetX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/shadowOffsetY)
    */
  mutable shadowOffsetY: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/shadowBlur)
    */
  mutable shadowBlur: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/shadowColor)
    */
  mutable shadowColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/filter)
    */
  mutable filter: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineWidth)
    */
  mutable lineWidth: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineCap)
    */
  mutable lineCap: canvasLineCap,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineJoin)
    */
  mutable lineJoin: canvasLineJoin,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/miterLimit)
    */
  mutable miterLimit: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineDashOffset)
    */
  mutable lineDashOffset: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/font)
    */
  mutable font: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/textAlign)
    */
  mutable textAlign: canvasTextAlign,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/textBaseline)
    */
  mutable textBaseline: canvasTextBaseline,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/direction)
    */
  mutable direction: canvasDirection,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/letterSpacing)
    */
  mutable letterSpacing: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fontKerning)
    */
  mutable fontKerning: canvasFontKerning,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fontStretch)
    */
  mutable fontStretch: canvasFontStretch,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fontVariantCaps)
    */
  mutable fontVariantCaps: canvasFontVariantCaps,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/textRendering)
    */
  mutable textRendering: canvasTextRendering,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/wordSpacing)
    */
  mutable wordSpacing: string,
}

/**
[See Animation on MDN](https://developer.mozilla.org/docs/Web/API/Animation)
*/
@editor.completeFrom(Animation)
type rec animation = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/id)
    */
  mutable id: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/effect)
    */
  mutable effect: Null.t<animationEffect>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/timeline)
    */
  mutable timeline: Null.t<animationTimeline>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/playbackRate)
    */
  mutable playbackRate: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/playState)
    */
  playState: animationPlayState,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/replaceState)
    */
  replaceState: animationReplaceState,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/pending)
    */
  pending: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/ready)
    */
  ready: promise<animation>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/finished)
    */
  finished: promise<animation>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/startTime)
    */
  mutable startTime: Null.t<float>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/currentTime)
    */
  mutable currentTime: Null.t<float>,
}

type elementDefinitionOptions = {mutable extends?: string}

type documentTimelineOptions = {mutable originTime?: float}

type getRootNodeOptions = {mutable composed?: bool}

type shadowRootInit = {
  mutable mode: shadowRootMode,
  mutable delegatesFocus?: bool,
  mutable slotAssignment?: slotAssignmentMode,
  mutable serializable?: bool,
}

type checkVisibilityOptions = {
  mutable checkOpacity?: bool,
  mutable checkVisibilityCSS?: bool,
  mutable contentVisibilityAuto?: bool,
  mutable opacityProperty?: bool,
  mutable visibilityProperty?: bool,
}

type scrollOptions = {mutable behavior?: scrollBehavior}

type scrollToOptions = {
  ...scrollOptions,
  mutable left?: float,
  mutable top?: float,
}

type fullscreenOptions = {mutable navigationUI?: fullscreenNavigationUI}

type getHTMLOptions = {
  mutable serializableShadowRoots?: bool,
  mutable shadowRoots?: array<shadowRoot>,
}

type pointerLockOptions = {mutable unadjustedMovement?: bool}

type caretPositionFromPointOptions = {mutable shadowRoots?: array<shadowRoot>}

type idleRequestOptions = {mutable timeout?: int}

type domRectInit = {
  mutable x?: float,
  mutable y?: float,
  mutable width?: float,
  mutable height?: float,
}

type validityStateFlags = {
  mutable valueMissing?: bool,
  mutable typeMismatch?: bool,
  mutable patternMismatch?: bool,
  mutable tooLong?: bool,
  mutable tooShort?: bool,
  mutable rangeUnderflow?: bool,
  mutable rangeOverflow?: bool,
  mutable stepMismatch?: bool,
  mutable badInput?: bool,
  mutable customError?: bool,
}

type cssStyleSheetInit = {
  mutable baseURL?: string,
  mutable media?: unknown,
  mutable disabled?: bool,
}

type videoFrameCallbackMetadata = {
  mutable presentationTime: float,
  mutable expectedDisplayTime: float,
  mutable width: int,
  mutable height: int,
  mutable mediaTime: float,
  mutable presentedFrames: int,
  mutable processingDuration?: float,
  mutable captureTime?: float,
  mutable receiveTime?: float,
  mutable rtpTimestamp?: int,
}

type assignedNodesOptions = {mutable flatten?: bool}

type focusOptions = {mutable preventScroll?: bool}

type effectTiming = {
  mutable fill?: fillMode,
  mutable iterationStart?: float,
  mutable iterations?: float,
  mutable direction?: playbackDirection,
  mutable easing?: string,
  mutable delay?: float,
  mutable endDelay?: float,
  mutable playbackRate?: float,
  mutable duration?: unknown,
}

type getAnimationsOptions = {mutable subtree?: bool}

type computedEffectTiming = {
  ...effectTiming,
  mutable progress?: Null.t<float>,
  mutable currentIteration?: Null.t<float>,
  mutable startTime?: float,
  mutable endTime?: float,
  mutable activeDuration?: float,
  mutable localTime?: Null.t<float>,
}

type optionalEffectTiming = {
  mutable delay?: float,
  mutable endDelay?: float,
  mutable fill?: fillMode,
  mutable iterationStart?: float,
  mutable iterations?: float,
  mutable duration?: unknown,
  mutable direction?: playbackDirection,
  mutable easing?: string,
  mutable playbackRate?: float,
}

type imageBitmapOptions = {
  mutable imageOrientation?: imageOrientation,
  mutable premultiplyAlpha?: premultiplyAlpha,
  mutable colorSpaceConversion?: colorSpaceConversion,
  mutable resizeWidth?: int,
  mutable resizeHeight?: int,
  mutable resizeQuality?: resizeQuality,
}

type scrollIntoViewOptions = {
  ...scrollOptions,
  mutable block?: scrollLogicalPosition,
  mutable inline?: scrollLogicalPosition,
}

type windowPostMessageOptions = {
  ...structuredSerializeOptions,
  mutable targetOrigin?: string,
}

type keyframeEffectOptions = {
  ...effectTiming,
  mutable composite?: compositeOperation,
  mutable pseudoElement?: Null.t<string>,
  mutable iterationComposite?: iterationCompositeOperation,
}

type keyframeAnimationOptions = {
  ...keyframeEffectOptions,
  mutable id?: string,
  mutable timeline?: Null.t<animationTimeline>,
}

type elementCreationOptions = {mutable is?: string}

type svgBoundingBoxOptions = {
  mutable fill?: bool,
  mutable stroke?: bool,
  mutable markers?: bool,
  mutable clipped?: bool,
}

type domMatrix2DInit = {
  mutable a?: float,
  mutable b?: float,
  mutable c?: float,
  mutable d?: float,
  mutable e?: float,
  mutable f?: float,
  mutable m11?: float,
  mutable m12?: float,
  mutable m21?: float,
  mutable m22?: float,
  mutable m41?: float,
  mutable m42?: float,
}

type domMatrixInit = {
  ...domMatrix2DInit,
  mutable m13?: float,
  mutable m14?: float,
  mutable m23?: float,
  mutable m24?: float,
  mutable m31?: float,
  mutable m32?: float,
  mutable m33?: float,
  mutable m34?: float,
  mutable m43?: float,
  mutable m44?: float,
  mutable is2D?: bool,
}

type videoFrameInit = {
  mutable duration?: int,
  mutable timestamp?: int,
  mutable alpha?: alphaOption,
  mutable visibleRect?: domRectInit,
  mutable displayWidth?: int,
  mutable displayHeight?: int,
}

type videoColorSpaceInit = {
  mutable primaries?: Null.t<videoColorPrimaries>,
  mutable transfer?: Null.t<videoTransferCharacteristics>,
  mutable matrix?: Null.t<videoMatrixCoefficients>,
  mutable fullRange?: Null.t<bool>,
}

type planeLayout = {
  mutable offset: int,
  mutable stride: int,
}

type videoFrameBufferInit = {
  mutable format: videoPixelFormat,
  mutable codedWidth: int,
  mutable codedHeight: int,
  mutable timestamp: int,
  mutable duration?: int,
  mutable layout?: array<planeLayout>,
  mutable visibleRect?: domRectInit,
  mutable displayWidth?: int,
  mutable displayHeight?: int,
  mutable colorSpace?: videoColorSpaceInit,
}

type imageDataSettings = {mutable colorSpace?: predefinedColorSpace}

type videoFrameCopyToOptions = {
  mutable rect?: domRectInit,
  mutable layout?: array<planeLayout>,
  mutable format?: videoPixelFormat,
  mutable colorSpace?: predefinedColorSpace,
}

type domPointInit = {
  mutable x?: float,
  mutable y?: float,
  mutable z?: float,
  mutable w?: float,
}

type xPathNSResolver = any

type timerHandler = any

type voidFunction = unit => unit
type imageBitmapSource = any

type customElementConstructor = htmlElement

type idleRequestCallback = idleDeadline => unit

type fileSystemEntriesCallback = array<fileSystemEntry> => unit

type blobCallback = blob => unit

type videoFrameRequestCallback = float => videoFrameCallbackMetadata => unit

type frameRequestCallback = float => unit

type timeoutId
