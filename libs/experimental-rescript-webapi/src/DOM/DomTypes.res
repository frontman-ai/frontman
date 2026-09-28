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

/**
A window containing a WebApiDOM document; the document property points to the WebApiDOM document loaded in that window.
[See Window on MDN](https://developer.mozilla.org/docs/Web/API/Window)
*/
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

/**
@editor.completeFrom(Window) The location (WebApiURL) of the object it is linked to. Changes done on it are reflected on the object it relates to. Both the Document and Window interface have such a linked Location, accessible via Document.location and Window.location respectively.
[See Location on MDN](https://developer.mozilla.org/docs/Web/API/Location)
*/
@editor.completeFrom(Location)
type location = DOM.location = private {...DOM.location}

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
type navigator = DOM.navigator

// TODO: mark as private once mutating fields of private records is allowed
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
type namedNodeMap = private {
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
type customElementRegistry = private {}

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
type screenOrientation = private {
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

type renderingContext = unknown

type offscreenRenderingContext = unknown

/**
[See AnimationTimeline on MDN](https://developer.mozilla.org/docs/Web/API/AnimationTimeline)
*/
@editor.completeFrom(Animation)
type rec animationTimeline = private {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnimationTimeline/currentTime)
    */
  currentTime: Null.t<float>,
}

/**
[See DocumentTimeline on MDN](https://developer.mozilla.org/docs/Web/API/DocumentTimeline)
*/
@editor.completeFrom(DocumentTimeline) and documentTimeline = private {
  // Base properties from AnimationTimeline
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnimationTimeline/currentTime)
    */
  currentTime: Null.t<float>,
  // End base properties from AnimationTimeline
}

/**
[See MediaList on MDN](https://developer.mozilla.org/docs/Web/API/MediaList)
TODO: mark as private once mutating fields of private records is allowed
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
type stylePropertyMapReadOnly = private {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly/size)
    */
  size: int,
}

/**
[See StylePropertyMap on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap)
*/
@editor.completeFrom(StylePropertyMap)
type stylePropertyMap = private {
  ...stylePropertyMapReadOnly,
}

/**
Used by the dataset HTML attribute to represent data for custom attributes added to elements.
[See DOMStringMap on MDN](https://developer.mozilla.org/docs/Web/API/DOMStringMap)
*/
type domStringMap = {}

type mediaProvider = unknown

/**
Adds to HTMLElement the properties and methods needed to support basic media-related capabilities that are common to audio and video.
[See HTMLMediaElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement)
TODO: mark as private once mutating fields of private records is allowed
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
    The address or WebApiURL of the a media resource that is to be considered.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/src)
    */
  mutable src: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/srcObject)
    */
  mutable srcObject: Null.t<mediaProvider>,
  /**
    Gets the address or WebApiURL of the current media resource that is selected by IHTMLMediaElement.
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
type htmlAudioElement = private {
  ...htmlMediaElement,
}

/**
Contains the base URI for a document. This object inherits all of the properties and methods as described in the HTMLElement interface.
[See HTMLBaseElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLBaseElement)
TODO: mark as private once mutating fields of private records is allowed
*/
@editor.completeFrom(HTMLBaseElement)
type htmlBaseElement = {
  ...htmlElement,
  /**
    Gets or sets the baseline WebApiURL on which relative links are based.
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
type htmlBodyElement = private {
  ...htmlElement,
}

/**
A HTML line break element (<br>). It inherits from HTMLElement.
[See HTMLBRElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLBRElement)
*/
@editor.completeFrom(HTMLBRElement)
type htmlbrElement = private {
  ...htmlElement,
}

/**
Provides properties and methods for manipulating the layout and presentation of <canvas> elements. The HTMLCanvasElement interface also inherits the properties and methods of the HTMLElement interface.
[See HTMLCanvasElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement)
TODO: mark as private once mutating fields of private records is allowed
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
TODO: mark as private once mutating fields of private records is allowed
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
TODO: mark as private once mutating fields of private records is allowed
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
type htmlDivElement = private {
  ...htmlElement,
}

/**
Provides special properties (beyond those of the regular HTMLElement interface it also has available to it by inheritance) for manipulating definition list (<dl>) elements.
[See HTMLDListElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLDListElement)
*/
@editor.completeFrom(HTMLDListElement)
type htmldListElement = private {
  ...htmlElement,
}

/**
Provides special properties and methods (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of <fieldset> elements.
[See HTMLFieldSetElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLFieldSetElement)
TODO: mark as private once mutating fields of private records is allowed
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
  elements: htmlCollection<element>,
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
type htmlFrameSetElement = private {
  ...htmlElement,
}

/**
The different heading elements. It inherits methods and properties from the HTMLElement interface.
[See HTMLHeadingElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLHeadingElement)
*/
@editor.completeFrom(HTMLHeadingElement)
type htmlHeadingElement = private {
  ...htmlElement,
}

/**
Provides special properties (beyond those of the HTMLElement interface it also has available to it by inheritance) for manipulating <hr> elements.
[See HTMLHRElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLHRElement)
*/
@editor.completeFrom(HTMLHRElement)
type htmlhrElement = private {
  ...htmlElement,
}

/**
Serves as the root node for a given HTML document. This object inherits the properties and methods described in the HTMLElement interface.
[See HTMLHtmlElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLHtmlElement)
*/
@editor.completeFrom(HTMLHtmlElement)
type htmlHtmlElement = private {
  ...htmlElement,
}

/**
Provides special properties and methods (beyond those of the HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of inline frame elements.
[See HTMLIFrameElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLIFrameElement)
TODO: mark as private once mutating fields of private records is allowed
*/
@editor.completeFrom(HTMLIFrameElement)
type htmliFrameElement = {
  ...htmlElement,
  /**
    Sets or retrieves a WebApiURL to be loaded by the object.
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
type htmlLegendElement = private {
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
type htmlliElement = private {
  ...htmlElement,
}

/**
Reference information for external resources and the relationship of those resources to a document and vice-versa. This object inherits all of the properties and methods of the HTMLElement interface.
[See HTMLLinkElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLLinkElement)
TODO: mark as private once mutating fields of private records is allowed
*/
@editor.completeFrom(HTMLLinkElement)
type htmlLinkElement = {
  ...htmlElement,
  /**
    Sets or retrieves a destination WebApiURL or an anchor point.
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
TODO: mark as private once mutating fields of private records is allowed
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
  areas: htmlCollection<element>,
}

/**
[See HTMLMenuElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMenuElement)
*/
@editor.completeFrom(HTMLMenuElement)
type htmlMenuElement = private {
  ...htmlElement,
}

/**
Contains descriptive metadata about a document. It inherits all of the properties and methods described in the HTMLElement interface.
[See HTMLMetaElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMetaElement)
TODO: mark as private once mutating fields of private records is allowed
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
TODO: mark as private once mutating fields of private records is allowed
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
  labels: nodeList<htmlLabelElement>,
}

/**
Provides special properties (beyond the regular methods and properties available through the HTMLElement interface they also have available to them by inheritance) for manipulating modification elements, that is <del> and <ins>.
[See HTMLModElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLModElement)
*/
@editor.completeFrom(HTMLModElement)
type htmlModElement = private {
  ...htmlElement,
}

/**
Provides special properties and methods (beyond those on the HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of <object> element, representing external resources.
[See HTMLObjectElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLObjectElement)
TODO: mark as private once mutating fields of private records is allowed
*/
@editor.completeFrom(HTMLObjectElement)
type htmlObjectElement = {
  ...htmlElement,
  /**
    Sets or retrieves the WebApiURL that references the data of the object.
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
TODO: mark as private once mutating fields of private records is allowed
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
TODO: mark as private once mutating fields of private records is allowed
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
type htmlParagraphElement = private {
  ...htmlElement,
}

/**
A <picture> HTML element. It doesn't implement specific properties or methods.
[See HTMLPictureElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLPictureElement)
*/
@editor.completeFrom(HTMLPictureElement)
type htmlPictureElement = private {
  ...htmlElement,
}

/**
Exposes specific properties and methods (beyond those of the HTMLElement interface it also has available to it by inheritance) for manipulating a block of preformatted text (<pre>).
[See HTMLPreElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLPreElement)
*/
@editor.completeFrom(HTMLPreElement)
type htmlPreElement = private {
  ...htmlElement,
}

/**
Provides special properties and methods (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating the layout and presentation of <progress> elements.
[See HTMLProgressElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLProgressElement)
TODO: mark as private once mutating fields of private records is allowed
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
  labels: nodeList<htmlLabelElement>,
}

/**
Provides special properties and methods (beyond the regular HTMLElement interface it also has available to it by inheritance) for manipulating quoting elements, like <blockquote> and <q>, but not the <cite> element.
[See HTMLQuoteElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLQuoteElement)
*/
@editor.completeFrom(HTMLQuoteElement)
type htmlQuoteElement = private {
  ...htmlElement,
}

/**
Provides special properties (beyond the regular HTMLElement object interface it also has available to it by inheritance) for manipulating <source> elements.
[See HTMLSourceElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSourceElement)
TODO: mark as private once mutating fields of private records is allowed
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
type htmlSpanElement = private {
  ...htmlElement,
}

/**
A <style> element. It inherits properties and methods from its parent, HTMLElement, and from LinkStyle.
[See HTMLStyleElement on MDN](https://developer.mozilla.org/docs/Web/API/HTMLStyleElement)
TODO: mark as private once mutating fields of private records is allowed
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
TODO: mark as private once mutating fields of private records is allowed
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
TODO: mark as private once mutating fields of private records is allowed
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
TODO: mark as private once mutating fields of private records is allowed
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
TODO: mark as private once mutating fields of private records is allowed
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
type htmluListElement = private {
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
TODO: mark as private once mutating fields of private records is allowed
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
    Gets or sets a WebApiURL of an image to display, for example, like a movie poster. This can be a still frame from the video, or another image if no video data is available.
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
type animationEffect = private {}

/**
This interface is a compiled XPath expression that can be evaluated on a document or specific node to return information its WebApiDOM tree.
[See XPathExpression on MDN](https://developer.mozilla.org/docs/Web/API/XPathExpression)
*/
@editor.completeFrom(XPathExpression)
type xPathExpression = private {}

/**
The results generated by evaluating an XPath expression within the context of a given node.
[See XPathResult on MDN](https://developer.mozilla.org/docs/Web/API/XPathResult)
*/
@editor.completeFrom(XPathResult)
type xPathResult = private {
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
type svgLength = private {}

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
All of the SVG WebApiDOM interfaces that correspond directly to elements in the SVG language derive from the SVGElement interface.
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
type svgGraphicsElement = private {
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
type domMatrixReadOnly = private {
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
type domMatrix = private {
  ...domMatrixReadOnly,
}

/**
[See VideoColorSpace on MDN](https://developer.mozilla.org/docs/Web/API/VideoColorSpace)
*/
@editor.completeFrom(VideoColorSpace)
type videoColorSpace = private {
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
type videoFrame = private {
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
type imageData = private {
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
  data: Uint8ClampedArray.t,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageData/colorSpace)
    */
  colorSpace: predefinedColorSpace,
}

/**
[See DOMPointReadOnly on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly)
*/
@editor.completeFrom(DOMPointReadOnly)
type domPointReadOnly = private {
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
type domPoint = private {
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
The CanvasRenderingContext2D interface, part of the WebApiCanvas API, provides the 2D rendering context for the drawing surface of a <canvas> element. It is used for drawing shapes, text, images, and other objects.
[See CanvasRenderingContext2D on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D)
*/
@editor.completeFrom(CanvasRenderingContext2D)
type canvasRenderingContext2D

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

type xPathNSResolver

type imageBitmapSource

type customElementConstructor

type timeoutId
