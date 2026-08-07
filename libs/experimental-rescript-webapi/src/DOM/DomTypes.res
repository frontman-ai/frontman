@@warning("-30")

type domStringList = DOM.domStringList
type eventTarget = EventTypes.eventTarget
type eventType = EventTypes.eventType
type file = FileTypes.file
type blob = FileTypes.blob
type fileSystemEntry = FileAndDirectoryEntriesTypes.fileSystemEntry
type remotePlayback = RemotePlaybackTypes.remotePlayback
type fontFaceSet = CssFontLoadingTypes.fontFaceSet
type structuredSerializeOptions = ChannelMessagingTypes.structuredSerializeOptions

type htmlElement = DOM.htmlElement
type mediaError = DOM.mediaError
type timeRanges = DOM.timeRanges
type textTrackList = DOM.textTrackList
type htmlFormElement = DOM.htmlFormElement
type htmlCollection<'a> = DOM.htmlCollection<'a>
type element = DOM.element
type validityState = DOM.validityState
type document = DOM.document
type cssStyleSheet = DOM.cssStyleSheet
type nodeList<'a> = DOM.nodeList<'a>
type htmlLabelElement = DOM.htmlLabelElement
type documentFragment = DOM.documentFragment
type node = DOM.node
type cssStyleDeclaration = DOM.cssStyleDeclaration
type domRectReadOnly = DOM.domRectReadOnly
type shadowRoot = DOM.shadowRoot
type styleSheet = DOM.styleSheet
type mediaQueryList = DOM.mediaQueryList
type domRect = DOM.domRect
type range = DOM.range
type documentType = DOM.documentType
type cssStyleValue = DOM.cssStyleValue
type treeWalker = DOM.treeWalker
type selection = DOM.selection
type abstractRange = DOM.abstractRange
type htmlOptionsCollection = DOM.htmlOptionsCollection
type styleSheetList = DOM.styleSheetList
type elementInternals = DOM.elementInternals
type nodeFilter = DOM.nodeFilter
type fileList = DOM.fileList
type cssRule = DOM.cssRule
type attr = DOM.attr
type domRectList = DOM.domRectList
type htmlFormControlsCollection = DOM.htmlFormControlsCollection
type domImplementation = DOM.domImplementation
type nodeIterator = DOM.nodeIterator
type xmlDocument = DOM.xmlDocument
type characterData = DOM.characterData
type text = DOM.text
type cdataSection = DOM.cdataSection
type comment = DOM.comment
type processingInstruction = DOM.processingInstruction
type caretPosition = DOM.caretPosition
type htmlTableElement = DOM.htmlTableElement
type htmlOutputElement = DOM.htmlOutputElement
type htmlTableCellElement = DOM.htmlTableCellElement
type htmlHeadElement = DOM.htmlHeadElement
type htmlSelectElement = DOM.htmlSelectElement
type htmlButtonElement = DOM.htmlButtonElement
type htmlTableSectionElement = DOM.htmlTableSectionElement
type htmlOptionElement = DOM.htmlOptionElement
type htmlEmbedElement = DOM.htmlEmbedElement
type htmlTextAreaElement = DOM.htmlTextAreaElement
type htmlTableCaptionElement = DOM.htmlTableCaptionElement
type htmlSlotElement = DOM.htmlSlotElement
type htmlDataListElement = DOM.htmlDataListElement
type htmlInputElement = DOM.htmlInputElement
type htmlScriptElement = DOM.htmlScriptElement
type htmlAnchorElement = DOM.htmlAnchorElement
type htmlTableRowElement = DOM.htmlTableRowElement
type htmlImageElement = DOM.htmlImageElement
type htmlAreaElement = DOM.htmlAreaElement
type videoPlaybackQuality = DOM.videoPlaybackQuality
type idleDeadline = DOM.idleDeadline
type cssRuleList = DOM.cssRuleList
type mediaKeySystemConfiguration = BaseEncryptedMediaExtensions.mediaKeySystemConfiguration

@editor.completeFrom(Window) type window = DOM.window

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

@editor.completeFrom(Location)
type location = DOM.location = private {...DOM.location}

type userActivation = {
  hasBeenActive: bool,
  isActive: bool,
}

@editor.completeFrom(Navigator)
type navigator = DOM.navigator

@editor.completeFrom(DOMTokenList)
type domTokenList = {
  length: int,
  mutable value: string,
}

@editor.completeFrom(NamedNodeMap)
type namedNodeMap = private {
  length: int,
}

type fragmentDirective = {}

@editor.completeFrom(CustomElementRegistry)
type customElementRegistry = private {}

type barProp = {
  visible: bool,
}

@editor.completeFrom(ScreenOrientation)
type screenOrientation = private {
  ...eventTarget,
  @as("type")
  type_: orientationType,
  angle: int,
}

type screen = {
  availWidth: int,
  availHeight: int,
  width: int,
  height: int,
  colorDepth: int,
  pixelDepth: int,
  orientation: screenOrientation,
}

@unboxed
type vibratePattern =
  | Int(int)
  | IntArray(array<int>)

type renderingContext = unknown

type offscreenRenderingContext = unknown

@editor.completeFrom(Animation)
type rec animationTimeline = private {
  currentTime: Null.t<float>,
}

@editor.completeFrom(DocumentTimeline)
and documentTimeline = private {
  currentTime: Null.t<float>,
}

@editor.completeFrom(MediaList)
type mediaList = {
  mutable mediaText: string,
  length: int,
}

@editor.completeFrom(StylePropertyMapReadOnly)
type stylePropertyMapReadOnly = private {
  size: int,
}

@editor.completeFrom(StylePropertyMap)
type stylePropertyMap = private {
  ...stylePropertyMapReadOnly,
}

type domStringMap = {}

type mediaProvider = unknown

@editor.completeFrom(HTMLMediaElement)
type htmlMediaElement = {
  ...htmlElement,
  error: Null.t<mediaError>,
  mutable src: string,
  mutable srcObject: Null.t<mediaProvider>,
  currentSrc: string,
  mutable crossOrigin: Null.t<string>,
  networkState: int,
  mutable preload: string,
  buffered: timeRanges,
  readyState: int,
  mutable currentTime: float,
  duration: float,
  paused: bool,
  mutable defaultPlaybackRate: float,
  mutable playbackRate: float,
  mutable preservesPitch: bool,
  seekable: timeRanges,
  ended: bool,
  mutable autoplay: bool,
  mutable loop: bool,
  mutable controls: bool,
  mutable volume: float,
  mutable muted: bool,
  mutable defaultMuted: bool,
  textTracks: textTrackList,
  sinkId: string,
  remote: remotePlayback,
  mutable disableRemotePlayback: bool,
}

@editor.completeFrom(HTMLAudioElement)
type htmlAudioElement = private {
  ...htmlMediaElement,
}

@editor.completeFrom(HTMLBaseElement)
type htmlBaseElement = {
  ...htmlElement,
  mutable href: string,
  mutable target: string,
}

@editor.completeFrom(HTMLBodyElement)
type htmlBodyElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLBRElement)
type htmlbrElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLCanvasElement)
type htmlCanvasElement = {
  ...htmlElement,
  mutable width: int,
  mutable height: int,
}

@editor.completeFrom(HTMLDataElement)
type htmlDataElement = {
  ...htmlElement,
  mutable value: string,
}

@editor.completeFrom(HTMLDialogElement)
type htmlDialogElement = {
  ...htmlElement,
  @as("open")
  mutable open_: bool,
  mutable returnValue: string,
}

@editor.completeFrom(HTMLDivElement)
type htmlDivElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLDListElement)
type htmldListElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLFieldSetElement)
type htmlFieldSetElement = {
  ...htmlElement,
  mutable disabled: bool,
  form: Null.t<htmlFormElement>,
  mutable name: string,
  @as("type")
  type_: string,
  elements: htmlCollection<element>,
  willValidate: bool,
  validity: validityState,
  validationMessage: string,
}

@editor.completeFrom(HTMLFrameSetElement)
type htmlFrameSetElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLHeadingElement)
type htmlHeadingElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLHRElement)
type htmlhrElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLHtmlElement)
type htmlHtmlElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLIFrameElement)
type htmliFrameElement = {
  ...htmlElement,
  mutable src: string,
  mutable srcdoc: string,
  mutable name: string,
  sandbox: domTokenList,
  mutable allow: string,
  mutable allowFullscreen: bool,
  mutable width: string,
  mutable height: string,
  mutable referrerPolicy: referrerPolicy,
  mutable loading: string,
  contentDocument: Null.t<document>,
  contentWindow: Null.t<window>,
}

@editor.completeFrom(HTMLLegendElement)
type htmlLegendElement = private {
  ...htmlElement,
  form: Null.t<htmlFormElement>,
}

@editor.completeFrom(HTMLLIElement)
type htmlliElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLLinkElement)
type htmlLinkElement = {
  ...htmlElement,
  mutable href: string,
  mutable crossOrigin: Null.t<string>,
  mutable rel: string,
  @as("as")
  mutable as_: string,
  relList: domTokenList,
  mutable media: string,
  mutable integrity: string,
  mutable hreflang: string,
  @as("type")
  mutable type_: string,
  mutable referrerPolicy: string,
  mutable disabled: bool,
  mutable fetchPriority: string,
  sheet: Null.t<cssStyleSheet>,
}

@editor.completeFrom(HTMLMapElement)
type htmlMapElement = {
  ...htmlElement,
  mutable name: string,
  areas: htmlCollection<element>,
}

@editor.completeFrom(HTMLMenuElement)
type htmlMenuElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLMetaElement)
type htmlMetaElement = {
  ...htmlElement,
  mutable name: string,
  mutable httpEquiv: string,
  mutable content: string,
  mutable media: string,
}

@editor.completeFrom(HTMLMeterElement)
type htmlMeterElement = {
  ...htmlElement,
  mutable value: float,
  mutable min: float,
  mutable max: float,
  mutable low: float,
  mutable high: float,
  mutable optimum: float,
  labels: nodeList<htmlLabelElement>,
}

@editor.completeFrom(HTMLModElement)
type htmlModElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLObjectElement)
type htmlObjectElement = {
  ...htmlElement,
  mutable data: string,
  @as("type")
  mutable type_: string,
  mutable name: string,
  form: Null.t<htmlFormElement>,
  mutable width: string,
  mutable height: string,
  contentDocument: Null.t<document>,
  contentWindow: Null.t<window>,
  willValidate: bool,
  validity: validityState,
  validationMessage: string,
}

@editor.completeFrom(HTMLOListElement)
type htmloListElement = {
  ...htmlElement,
  mutable reversed: bool,
  mutable start: int,
  @as("type")
  mutable type_: string,
}

@editor.completeFrom(HTMLOptGroupElement)
type htmlOptGroupElement = {
  ...htmlElement,
  mutable disabled: bool,
  mutable label: string,
}

@editor.completeFrom(HTMLParagraphElement)
type htmlParagraphElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLPictureElement)
type htmlPictureElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLPreElement)
type htmlPreElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLProgressElement)
type htmlProgressElement = {
  ...htmlElement,
  mutable value: float,
  mutable max: float,
  position: float,
  labels: nodeList<htmlLabelElement>,
}

@editor.completeFrom(HTMLQuoteElement)
type htmlQuoteElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLSourceElement)
type htmlSourceElement = {
  ...htmlElement,
  mutable width: int,
  mutable height: int,
}

@editor.completeFrom(HTMLSpanElement)
type htmlSpanElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLStyleElement)
type htmlStyleElement = {
  ...htmlElement,
  mutable disabled: bool,
  mutable media: string,
  sheet: Null.t<cssStyleSheet>,
}

@editor.completeFrom(HTMLTemplateElement)
type htmlTemplateElement = {
  ...htmlElement,
  content: documentFragment,
  mutable shadowRootMode: string,
  mutable shadowRootDelegatesFocus: bool,
  mutable shadowRootClonable: bool,
  mutable shadowRootSerializable: bool,
}

@editor.completeFrom(HTMLTimeElement)
type htmlTimeElement = {
  ...htmlElement,
  mutable dateTime: string,
}

@editor.completeFrom(HTMLTitleElement)
type htmlTitleElement = {
  ...htmlElement,
  mutable text: string,
}

@editor.completeFrom(HTMLTrackElement)
type htmlTrackElement = {
  ...htmlElement,
  mutable src: string,
}

@editor.completeFrom(HTMLUListElement)
type htmluListElement = private {
  ...htmlElement,
}

type htmlUnknownElement = {
  ...htmlElement,
}

@editor.completeFrom(HTMLVideoElement)
type htmlVideoElement = {
  ...htmlMediaElement,
  mutable width: int,
  mutable height: int,
  videoWidth: int,
  videoHeight: int,
  mutable poster: string,
  mutable disablePictureInPicture: bool,
}

@editor.completeFrom(AnimationEffect)
type animationEffect = private {}

@editor.completeFrom(XPathExpression)
type xPathExpression = private {}

@editor.completeFrom(XPathResult)
type xPathResult = private {
  resultType: int,
  numberValue: float,
  stringValue: string,
  booleanValue: bool,
  singleNodeValue: Null.t<node>,
  invalidIteratorState: bool,
  snapshotLength: int,
}

type svgAnimatedPreserveAspectRatio = {}

@editor.completeFrom(SVGLength)
type svgLength = private {}

type svgAnimatedLength = {
  baseVal: svgLength,
  animVal: svgLength,
}

type svgElement = {
  ...element,
  dataset: domStringMap,
  mutable nonce?: string,
  mutable autofocus: bool,
  mutable tabIndex: int,
  style: cssStyleDeclaration,
  attributeStyleMap: stylePropertyMap,
}

@editor.completeFrom(SVGGraphicsElement)
type svgGraphicsElement = private {
  ...svgElement,
}

type svgImageElement = {
  ...svgGraphicsElement,
  x: svgAnimatedLength,
  y: svgAnimatedLength,
  width: svgAnimatedLength,
  height: svgAnimatedLength,
  preserveAspectRatio: svgAnimatedPreserveAspectRatio,
}

@editor.completeFrom(DOMMatrixReadOnly)
type domMatrixReadOnly = private {
  a: float,
  b: float,
  c: float,
  d: float,
  e: float,
  f: float,
  m11: float,
  m12: float,
  m13: float,
  m14: float,
  m21: float,
  m22: float,
  m23: float,
  m24: float,
  m31: float,
  m32: float,
  m33: float,
  m34: float,
  m41: float,
  m42: float,
  m43: float,
  m44: float,
}

@editor.completeFrom(DOMMatrix)
type domMatrix = private {
  ...domMatrixReadOnly,
}

@editor.completeFrom(VideoColorSpace)
type videoColorSpace = private {
  primaries: Null.t<videoColorPrimaries>,
  transfer: Null.t<videoTransferCharacteristics>,
  matrix: Null.t<videoMatrixCoefficients>,
  fullRange: Null.t<bool>,
}

@editor.completeFrom(VideoFrame)
type videoFrame = private {
  format: Null.t<videoPixelFormat>,
  codedWidth: int,
  codedHeight: int,
  codedRect: Null.t<domRectReadOnly>,
  visibleRect: Null.t<domRectReadOnly>,
  displayWidth: int,
  displayHeight: int,
  duration: Null.t<int>,
  timestamp: int,
  colorSpace: videoColorSpace,
}

@editor.completeFrom(ImageData)
type imageData = private {
  width: int,
  height: int,
  data: Uint8ClampedArray.t,
  colorSpace: predefinedColorSpace,
}

@editor.completeFrom(DOMPointReadOnly)
type domPointReadOnly = private {
  x: float,
  y: float,
  z: float,
  w: float,
}

@editor.completeFrom(DOMPoint)
type domPoint = private {
  ...domPointReadOnly,
}

type canvasContext2DAttributes = {
  alpha: bool,
  colorspace?: predefinedColorSpace,
  desynchronized: bool,
  willReadFrequently: bool,
}

@editor.completeFrom(CanvasRenderingContext2D)
type canvasRenderingContext2D

type rec animation = {
  ...eventTarget,
  mutable id: string,
  mutable effect: Null.t<animationEffect>,
  mutable timeline: Null.t<animationTimeline>,
  mutable playbackRate: float,
  playState: animationPlayState,
  replaceState: animationReplaceState,
  pending: bool,
  ready: promise<animation>,
  finished: promise<animation>,
  mutable startTime: Null.t<float>,
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

type xPathNSResolver

type imageBitmapSource

type customElementConstructor

type timeoutId
