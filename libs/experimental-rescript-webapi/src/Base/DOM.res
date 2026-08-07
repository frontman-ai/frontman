@@warning("-30")

type domException = {
  name: string,
  message: string,
}

type domStringList = {
  length: int,
}

type window

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
  mutable files?: array<BaseFile.file>,
  mutable title?: string,
  mutable text?: string,
  mutable url?: string,
}

@editor.completeFrom(Location)
type location = {
  mutable href: string,
  origin: string,
  mutable protocol: string,
  mutable host: string,
  mutable hostname: string,
  mutable port: string,
  mutable pathname: string,
  mutable search: string,
  mutable hash: string,
  ancestorOrigins: domStringList,
}

type userActivation = {
  hasBeenActive: bool,
  isActive: bool,
}

@editor.completeFrom(Navigator)
type navigator

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
  ...BaseEvent.eventTarget,
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

@editor.completeFrom(StyleSheetList)
type rec styleSheetList = private {
  length: int,
}

and styleSheet = {
  @as("type")
  type_: string,
  href: Null.t<string>,
  ownerNode: Null.t<unknown>,
  parentStyleSheet: Null.t<cssStyleSheet>,
  title: Null.t<string>,
  media: mediaList,
  mutable disabled: bool,
}

@editor.completeFrom(CSSStyleSheet)
and cssStyleSheet = {
  @as("type")
  type_: string,
  href: Null.t<string>,
  ownerNode: Null.t<unknown>,
  parentStyleSheet: Null.t<cssStyleSheet>,
  title: Null.t<string>,
  media: mediaList,
  mutable disabled: bool,
  ownerRule: Null.t<cssRule>,
  cssRules: cssRuleList,
}

and cssRule = {
  mutable cssText: string,
  parentRule: Null.t<cssRule>,
  parentStyleSheet: Null.t<cssStyleSheet>,
}

@editor.completeFrom(CSSRuleList)
and cssRuleList = private {
  length: int,
}

@editor.completeFrom(CSSStyleDeclaration)
and cssStyleDeclaration = {
  mutable cssText: string,
  length: int,
  parentRule: Null.t<cssRule>,
  mutable cx: string,
  mutable cy: string,
  mutable r: string,
  mutable rx: string,
  mutable ry: string,
  mutable x: string,
  mutable y: string,
  mutable vectorEffect: string,
  mutable d: string,
  mutable textAnchor: string,
  mutable fill: string,
  mutable stroke: string,
  mutable markerStart: string,
  mutable markerMid: string,
  mutable markerEnd: string,
  mutable marker: string,
  mutable paintOrder: string,
  mutable colorInterpolation: string,
  mutable shapeRendering: string,
  mutable textRendering: string,
  mutable pointerEvents: string,
  mutable stopColor: string,
  mutable stopOpacity: string,
  mutable webkitTextFillColor: string,
  mutable webkitTextStrokeColor: string,
  mutable webkitTextStrokeWidth: string,
  mutable webkitTextStroke: string,
  mutable touchAction: string,
  mutable positionArea: string,
  mutable top: string,
  mutable left: string,
  mutable right: string,
  mutable bottom: string,
  mutable justifySelf: string,
  mutable alignSelf: string,
  mutable justifyItems: string,
  mutable alignItems: string,
  mutable width: string,
  mutable height: string,
  mutable minWidth: string,
  mutable minHeight: string,
  mutable maxWidth: string,
  mutable maxHeight: string,
  mutable marginTop: string,
  mutable marginLeft: string,
  mutable marginRight: string,
  mutable marginBottom: string,
  mutable animationDuration: string,
  mutable animationComposition: string,
  mutable animationName: string,
  mutable animationTimingFunction: string,
  mutable animationIterationCount: string,
  mutable animationDirection: string,
  mutable animationPlayState: string,
  mutable animationDelay: string,
  mutable animationFillMode: string,
  mutable animation: string,
  mutable all: string,
  mutable containerType: string,
  mutable containerName: string,
  mutable container: string,
  mutable contain: string,
  mutable contentVisibility: string,
  mutable fontFamily: string,
  mutable fontWeight: string,
  mutable fontStyle: string,
  mutable fontSize: string,
  mutable fontSizeAdjust: string,
  mutable font: string,
  mutable fontSynthesisWeight: string,
  mutable fontSynthesisStyle: string,
  mutable fontSynthesisSmallCaps: string,
  mutable fontSynthesis: string,
  mutable fontKerning: string,
  mutable fontVariantLigatures: string,
  mutable fontVariantPosition: string,
  mutable fontVariantCaps: string,
  mutable fontVariantNumeric: string,
  mutable fontVariantAlternates: string,
  mutable fontVariantEastAsian: string,
  mutable fontVariant: string,
  mutable fontFeatureSettings: string,
  mutable fontOpticalSizing: string,
  mutable fontVariationSettings: string,
  mutable fontPalette: string,
  mutable fontStretch: string,
  mutable objectFit: string,
  mutable clipPath: string,
  mutable clipRule: string,
  mutable maskImage: string,
  mutable maskMode: string,
  mutable maskRepeat: string,
  mutable maskPosition: string,
  mutable maskClip: string,
  mutable maskOrigin: string,
  mutable maskSize: string,
  mutable maskComposite: string,
  mutable mask: string,
  mutable maskType: string,
  mutable transitionBehavior: string,
  mutable transitionProperty: string,
  mutable transitionDuration: string,
  mutable transitionTimingFunction: string,
  mutable transitionDelay: string,
  mutable transition: string,
  mutable viewTransitionName: string,
  mutable zoom: string,
  mutable filter: string,
  mutable colorInterpolationFilters: string,
  mutable display: string,
  mutable textTransform: string,
  mutable mathStyle: string,
  mutable mathDepth: string,
  mutable zIndex: string,
  mutable pageBreakBefore: string,
  mutable pageBreakAfter: string,
  mutable pageBreakInside: string,
  mutable mixBlendMode: string,
  mutable isolation: string,
  mutable backgroundBlendMode: string,
  mutable alignContent: string,
  mutable justifyContent: string,
  mutable placeContent: string,
  mutable placeSelf: string,
  mutable placeItems: string,
  mutable rowGap: string,
  mutable columnGap: string,
  mutable gap: string,
  mutable backgroundRepeat: string,
  mutable backgroundPosition: string,
  mutable backgroundPositionX: string,
  mutable backgroundPositionY: string,
  mutable backgroundClip: string,
  mutable backgroundColor: string,
  mutable backgroundImage: string,
  mutable backgroundAttachment: string,
  mutable backgroundOrigin: string,
  mutable backgroundSize: string,
  mutable background: string,
  mutable borderStyle: string,
  mutable borderWidth: string,
  mutable border: string,
  mutable borderImageSource: string,
  mutable borderImageSlice: string,
  mutable borderImageWidth: string,
  mutable borderImageOutset: string,
  mutable borderImageRepeat: string,
  mutable borderImage: string,
  mutable borderTopColor: string,
  mutable borderRightColor: string,
  mutable borderBottomColor: string,
  mutable borderLeftColor: string,
  mutable borderBlockStartColor: string,
  mutable borderBlockEndColor: string,
  mutable borderInlineStartColor: string,
  mutable borderInlineEndColor: string,
  mutable borderColor: string,
  mutable borderBlockColor: string,
  mutable borderInlineColor: string,
  mutable borderTopStyle: string,
  mutable borderRightStyle: string,
  mutable borderBottomStyle: string,
  mutable borderLeftStyle: string,
  mutable borderBlockStartStyle: string,
  mutable borderBlockEndStyle: string,
  mutable borderInlineStartStyle: string,
  mutable borderInlineEndStyle: string,
  mutable borderBlockStyle: string,
  mutable borderInlineStyle: string,
  mutable borderTopWidth: string,
  mutable borderRightWidth: string,
  mutable borderBottomWidth: string,
  mutable borderLeftWidth: string,
  mutable borderBlockStartWidth: string,
  mutable borderBlockEndWidth: string,
  mutable borderInlineStartWidth: string,
  mutable borderInlineEndWidth: string,
  mutable borderBlockWidth: string,
  mutable borderInlineWidth: string,
  mutable borderTop: string,
  mutable borderRight: string,
  mutable borderBottom: string,
  mutable borderLeft: string,
  mutable borderBlockStart: string,
  mutable borderBlockEnd: string,
  mutable borderInlineStart: string,
  mutable borderInlineEnd: string,
  mutable borderBlock: string,
  mutable borderInline: string,
  mutable borderTopLeftRadius: string,
  mutable borderTopRightRadius: string,
  mutable borderBottomRightRadius: string,
  mutable borderBottomLeftRadius: string,
  mutable borderStartStartRadius: string,
  mutable borderStartEndRadius: string,
  mutable borderEndStartRadius: string,
  mutable borderEndEndRadius: string,
  mutable borderRadius: string,
  mutable boxShadow: string,
  mutable margin: string,
  mutable paddingTop: string,
  mutable paddingRight: string,
  mutable paddingBottom: string,
  mutable paddingLeft: string,
  mutable padding: string,
  mutable breakBefore: string,
  mutable breakAfter: string,
  mutable breakInside: string,
  mutable orphans: string,
  mutable widows: string,
  mutable boxDecorationBreak: string,
  mutable colorScheme: string,
  mutable forcedColorAdjust: string,
  mutable printColorAdjust: string,
  mutable color: string,
  mutable opacity: string,
  mutable content: string,
  mutable quotes: string,
  mutable order: string,
  mutable visibility: string,
  mutable flexDirection: string,
  mutable flexWrap: string,
  mutable flexFlow: string,
  mutable flex: string,
  mutable flexGrow: string,
  mutable flexShrink: string,
  mutable flexBasis: string,
  mutable position: string,
  mutable float: string,
  mutable gridTemplateColumns: string,
  mutable gridTemplateRows: string,
  mutable gridAutoFlow: string,
  mutable gridTemplateAreas: string,
  mutable gridTemplate: string,
  mutable gridAutoColumns: string,
  mutable gridAutoRows: string,
  mutable grid: string,
  mutable gridRowStart: string,
  mutable gridColumnStart: string,
  mutable gridRowEnd: string,
  mutable gridColumnEnd: string,
  mutable gridRow: string,
  mutable gridColumn: string,
  mutable gridArea: string,
  mutable objectPosition: string,
  mutable imageRendering: string,
  mutable dominantBaseline: string,
  mutable verticalAlign: string,
  mutable lineHeight: string,
  mutable listStyleImage: string,
  mutable listStyleType: string,
  mutable listStylePosition: string,
  mutable listStyle: string,
  mutable counterReset: string,
  mutable counterIncrement: string,
  mutable counterSet: string,
  mutable blockSize: string,
  mutable inlineSize: string,
  mutable minBlockSize: string,
  mutable minInlineSize: string,
  mutable maxBlockSize: string,
  mutable maxInlineSize: string,
  mutable marginBlockStart: string,
  mutable marginBlockEnd: string,
  mutable marginInlineStart: string,
  mutable marginInlineEnd: string,
  mutable marginBlock: string,
  mutable marginInline: string,
  mutable paddingBlockStart: string,
  mutable paddingBlockEnd: string,
  mutable paddingInlineStart: string,
  mutable paddingInlineEnd: string,
  mutable paddingBlock: string,
  mutable paddingInline: string,
  mutable columnSpan: string,
  mutable columnWidth: string,
  mutable columnCount: string,
  mutable columns: string,
  mutable columnRuleColor: string,
  mutable columnRuleStyle: string,
  mutable columnRuleWidth: string,
  mutable columnRule: string,
  mutable columnFill: string,
  mutable overflowClipMargin: string,
  mutable textOverflow: string,
  mutable overflowX: string,
  mutable overflowY: string,
  mutable overflow: string,
  mutable scrollBehavior: string,
  mutable scrollbarGutter: string,
  mutable overscrollBehavior: string,
  mutable overscrollBehaviorX: string,
  mutable overscrollBehaviorY: string,
  mutable overscrollBehaviorInline: string,
  mutable overscrollBehaviorBlock: string,
  mutable clear: string,
  mutable page: string,
  mutable insetBlockStart: string,
  mutable insetInlineStart: string,
  mutable insetBlockEnd: string,
  mutable insetInlineEnd: string,
  mutable insetBlock: string,
  mutable insetInline: string,
  mutable inset: string,
  mutable rubyPosition: string,
  mutable rubyAlign: string,
  mutable overflowAnchor: string,
  mutable scrollSnapType: string,
  mutable scrollPadding: string,
  mutable scrollMargin: string,
  mutable scrollSnapAlign: string,
  mutable scrollSnapStop: string,
  mutable scrollPaddingTop: string,
  mutable scrollPaddingRight: string,
  mutable scrollPaddingBottom: string,
  mutable scrollPaddingLeft: string,
  mutable scrollPaddingInlineStart: string,
  mutable scrollPaddingBlockStart: string,
  mutable scrollPaddingInlineEnd: string,
  mutable scrollPaddingBlockEnd: string,
  mutable scrollPaddingBlock: string,
  mutable scrollPaddingInline: string,
  mutable scrollMarginTop: string,
  mutable scrollMarginRight: string,
  mutable scrollMarginBottom: string,
  mutable scrollMarginLeft: string,
  mutable scrollMarginBlockStart: string,
  mutable scrollMarginInlineStart: string,
  mutable scrollMarginBlockEnd: string,
  mutable scrollMarginInlineEnd: string,
  mutable scrollMarginBlock: string,
  mutable scrollMarginInline: string,
  mutable scrollbarColor: string,
  mutable scrollbarWidth: string,
  mutable shapeOutside: string,
  mutable shapeImageThreshold: string,
  mutable shapeMargin: string,
  mutable aspectRatio: string,
  mutable containIntrinsicWidth: string,
  mutable containIntrinsicHeight: string,
  mutable containIntrinsicBlockSize: string,
  mutable containIntrinsicInlineSize: string,
  mutable containIntrinsicSize: string,
  mutable boxSizing: string,
  mutable tableLayout: string,
  mutable borderCollapse: string,
  mutable borderSpacing: string,
  mutable captionSide: string,
  mutable emptyCells: string,
  mutable whiteSpace: string,
  mutable whiteSpaceCollapse: string,
  mutable tabSize: string,
  mutable textWrapMode: string,
  mutable textWrapStyle: string,
  mutable textWrap: string,
  mutable wordBreak: string,
  mutable lineBreak: string,
  mutable hyphens: string,
  mutable hyphenateCharacter: string,
  mutable overflowWrap: string,
  mutable textAlign: string,
  mutable textAlignLast: string,
  mutable wordSpacing: string,
  mutable letterSpacing: string,
  mutable textIndent: string,
  mutable textDecorationLine: string,
  mutable textDecorationStyle: string,
  mutable textDecorationColor: string,
  mutable textDecorationThickness: string,
  mutable textDecoration: string,
  mutable textUnderlinePosition: string,
  mutable textUnderlineOffset: string,
  mutable textDecorationSkipInk: string,
  mutable textEmphasisStyle: string,
  mutable textEmphasisColor: string,
  mutable textEmphasis: string,
  mutable textEmphasisPosition: string,
  mutable textShadow: string,
  mutable translate: string,
  mutable rotate: string,
  mutable scale: string,
  mutable transformStyle: string,
  mutable perspective: string,
  mutable perspectiveOrigin: string,
  mutable backfaceVisibility: string,
  mutable transform: string,
  mutable transformOrigin: string,
  mutable transformBox: string,
  mutable outline: string,
  mutable outlineWidth: string,
  mutable outlineStyle: string,
  mutable outlineColor: string,
  mutable outlineOffset: string,
  mutable resize: string,
  mutable cursor: string,
  mutable caretColor: string,
  mutable userSelect: string,
  mutable accentColor: string,
  mutable appearance: string,
  mutable willChange: string,
  mutable direction: string,
  mutable unicodeBidi: string,
  mutable writingMode: string,
  mutable textOrientation: string,
  mutable textCombineUpright: string,
  mutable fillRule: string,
  mutable fillOpacity: string,
  mutable strokeWidth: string,
  mutable strokeLinecap: string,
  mutable strokeLinejoin: string,
  mutable strokeMiterlimit: string,
  mutable strokeDasharray: string,
  mutable strokeDashoffset: string,
  mutable strokeOpacity: string,
  mutable backdropFilter: string,
  mutable offsetPath: string,
  mutable offsetDistance: string,
  mutable offsetPosition: string,
  mutable offsetAnchor: string,
  mutable offsetRotate: string,
  mutable offset: string,
  mutable cssFloat: string,
}

@editor.completeFrom(Node)
type rec node = {
  ...BaseEvent.eventTarget,
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
}

@editor.completeFrom(NodeList)
and nodeList<'tNode> = private {
  length: int,
}

@editor.completeFrom(Element)
and element = {
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  tagName: string,
  mutable id: string,
  mutable className: string,
  classList: domTokenList,
  mutable slot: string,
  attributes: namedNodeMap,
  shadowRoot: Null.t<shadowRoot>,
  part: domTokenList,
  mutable scrollTop: float,
  mutable scrollLeft: float,
  scrollWidth: int,
  scrollHeight: int,
  clientTop: int,
  clientLeft: int,
  clientWidth: int,
  clientHeight: int,
  currentCSSZoom: float,
  mutable innerHTML: string,
  mutable outerHTML: string,
  children: htmlCollection<element>,
  firstElementChild: Null.t<element>,
  lastElementChild: Null.t<element>,
  childElementCount: int,
  previousElementSibling: Null.t<element>,
  nextElementSibling: Null.t<element>,
  assignedSlot: Null.t<htmlSlotElement>,
  mutable ariaAtomic: Null.t<string>,
  mutable ariaAutoComplete: Null.t<string>,
  mutable ariaBrailleLabel: Null.t<string>,
  mutable ariaBrailleRoleDescription: Null.t<string>,
  mutable ariaBusy: Null.t<string>,
  mutable ariaChecked: Null.t<string>,
  mutable ariaColCount: Null.t<string>,
  mutable ariaColIndex: Null.t<string>,
  mutable ariaColIndexText: Null.t<string>,
  mutable ariaColSpan: Null.t<string>,
  mutable ariaCurrent: Null.t<string>,
  mutable ariaDescription: Null.t<string>,
  mutable ariaDisabled: Null.t<string>,
  mutable ariaExpanded: Null.t<string>,
  mutable ariaHasPopup: Null.t<string>,
  mutable ariaHidden: Null.t<string>,
  mutable ariaKeyShortcuts: Null.t<string>,
  mutable ariaLabel: Null.t<string>,
  mutable ariaLevel: Null.t<string>,
  mutable ariaLive: Null.t<string>,
  mutable ariaModal: Null.t<string>,
  mutable ariaMultiLine: Null.t<string>,
  mutable ariaMultiSelectable: Null.t<string>,
  mutable ariaOrientation: Null.t<string>,
  mutable ariaPlaceholder: Null.t<string>,
  mutable ariaPosInSet: Null.t<string>,
  mutable ariaPressed: Null.t<string>,
  mutable ariaReadOnly: Null.t<string>,
  mutable ariaRequired: Null.t<string>,
  mutable ariaRoleDescription: Null.t<string>,
  mutable ariaRowCount: Null.t<string>,
  mutable ariaRowIndex: Null.t<string>,
  mutable ariaRowIndexText: Null.t<string>,
  mutable ariaRowSpan: Null.t<string>,
  mutable ariaSelected: Null.t<string>,
  mutable ariaSetSize: Null.t<string>,
  mutable ariaSort: Null.t<string>,
  mutable ariaValueMax: Null.t<string>,
  mutable ariaValueMin: Null.t<string>,
  mutable ariaValueNow: Null.t<string>,
  mutable ariaValueText: Null.t<string>,
}

@editor.completeFrom(ShadowRoot)
and shadowRoot = {
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  mode: shadowRootMode,
  delegatesFocus: bool,
  slotAssignment: slotAssignmentMode,
  clonable: bool,
  serializable: bool,
  host: element,
  mutable innerHTML: string,
  styleSheets: styleSheetList,
  mutable adoptedStyleSheets: array<cssStyleSheet>,
  fullscreenElement: Null.t<element>,
  activeElement: Null.t<element>,
  pictureInPictureElement: Null.t<element>,
  pointerLockElement: Null.t<element>,
}

@editor.completeFrom(HTMLCollection)
and htmlCollection<'t> = private {
  length: int,
}

@editor.completeFrom(DOM.HTMLFormControlsCollection)
and htmlFormControlsCollection = private {
  length: int,
}

@editor.completeFrom(HTMLElement)
and htmlElement = {
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  tagName: string,
  mutable id: string,
  mutable className: string,
  classList: domTokenList,
  mutable slot: string,
  attributes: namedNodeMap,
  shadowRoot: Null.t<shadowRoot>,
  part: domTokenList,
  mutable scrollTop: float,
  mutable scrollLeft: float,
  scrollWidth: int,
  scrollHeight: int,
  clientTop: int,
  clientLeft: int,
  clientWidth: int,
  clientHeight: int,
  currentCSSZoom: float,
  mutable innerHTML: string,
  mutable outerHTML: string,
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  mutable title: string,
  mutable lang: string,
  mutable translate: bool,
  mutable dir: string,
  mutable hidden: unknown,
  mutable inert: bool,
  mutable accessKey: string,
  accessKeyLabel: string,
  mutable draggable: bool,
  mutable spellcheck: bool,
  mutable autocapitalize: string,
  mutable innerText: string,
  mutable outerText: string,
  mutable popover: Null.t<string>,
  offsetParent: Null.t<element>,
  offsetTop: int,
  offsetLeft: int,
  offsetWidth: int,
  offsetHeight: int,
  style: cssStyleDeclaration,
  attributeStyleMap: stylePropertyMap,
  mutable contentEditable: string,
  mutable enterKeyHint: string,
  isContentEditable: bool,
  mutable inputMode: string,
  dataset: domStringMap,
  mutable nonce?: string,
  mutable autofocus: bool,
  mutable tabIndex: int,
}

@editor.completeFrom(HTMLHeadElement)
and htmlHeadElement = {
  mutable title: string,
  mutable lang: string,
  mutable translate: bool,
  mutable dir: string,
  mutable hidden: unknown,
  mutable inert: bool,
  mutable accessKey: string,
  accessKeyLabel: string,
  mutable draggable: bool,
  mutable spellcheck: bool,
  mutable autocapitalize: string,
  mutable innerText: string,
  mutable outerText: string,
  mutable popover: Null.t<string>,
  offsetParent: Null.t<element>,
  offsetTop: int,
  offsetLeft: int,
  offsetWidth: int,
  offsetHeight: int,
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  tagName: string,
  mutable id: string,
  mutable className: string,
  classList: domTokenList,
  mutable slot: string,
  attributes: namedNodeMap,
  shadowRoot: Null.t<shadowRoot>,
  part: domTokenList,
  mutable scrollTop: float,
  mutable scrollLeft: float,
  scrollWidth: int,
  scrollHeight: int,
  clientTop: int,
  clientLeft: int,
  clientWidth: int,
  clientHeight: int,
  currentCSSZoom: float,
  mutable innerHTML: string,
  mutable outerHTML: string,
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
}

@editor.completeFrom(HTMLFormElement)
and htmlFormElement = {
  mutable title: string,
  mutable lang: string,
  mutable translate: bool,
  mutable dir: string,
  mutable hidden: unknown,
  mutable inert: bool,
  mutable accessKey: string,
  accessKeyLabel: string,
  mutable draggable: bool,
  mutable spellcheck: bool,
  mutable autocapitalize: string,
  mutable innerText: string,
  mutable outerText: string,
  mutable popover: Null.t<string>,
  offsetParent: Null.t<element>,
  offsetTop: int,
  offsetLeft: int,
  offsetWidth: int,
  offsetHeight: int,
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  tagName: string,
  mutable id: string,
  mutable className: string,
  classList: domTokenList,
  mutable slot: string,
  attributes: namedNodeMap,
  shadowRoot: Null.t<shadowRoot>,
  part: domTokenList,
  mutable scrollTop: float,
  mutable scrollLeft: float,
  scrollWidth: int,
  scrollHeight: int,
  clientTop: int,
  clientLeft: int,
  clientWidth: int,
  clientHeight: int,
  currentCSSZoom: float,
  mutable innerHTML: string,
  mutable outerHTML: string,
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  mutable acceptCharset: string,
  mutable action: string,
  mutable autocomplete: autoFillBase,
  mutable enctype: string,
  mutable encoding: string,
  mutable method: string,
  mutable name: string,
  mutable target: string,
  elements: htmlFormControlsCollection,
  length: int,
}

@editor.completeFrom(HTMLImageElement)
and htmlImageElement = {
  mutable title: string,
  mutable lang: string,
  mutable translate: bool,
  mutable dir: string,
  mutable hidden: unknown,
  mutable inert: bool,
  mutable accessKey: string,
  accessKeyLabel: string,
  mutable draggable: bool,
  mutable spellcheck: bool,
  mutable autocapitalize: string,
  mutable innerText: string,
  mutable outerText: string,
  mutable popover: Null.t<string>,
  offsetParent: Null.t<element>,
  offsetTop: int,
  offsetLeft: int,
  offsetWidth: int,
  offsetHeight: int,
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  tagName: string,
  mutable id: string,
  mutable className: string,
  classList: domTokenList,
  mutable slot: string,
  attributes: namedNodeMap,
  shadowRoot: Null.t<shadowRoot>,
  part: domTokenList,
  mutable scrollTop: float,
  mutable scrollLeft: float,
  scrollWidth: int,
  scrollHeight: int,
  clientTop: int,
  clientLeft: int,
  clientWidth: int,
  clientHeight: int,
  currentCSSZoom: float,
  mutable innerHTML: string,
  mutable outerHTML: string,
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  mutable alt: string,
  mutable src: string,
  mutable srcset: string,
  mutable sizes: string,
  mutable crossOrigin: Null.t<string>,
  mutable useMap: string,
  mutable isMap: bool,
  mutable width: int,
  mutable height: int,
  naturalWidth: int,
  naturalHeight: int,
  complete: bool,
  currentSrc: string,
  mutable referrerPolicy: string,
  mutable decoding: string,
  mutable loading: string,
  mutable fetchPriority: string,
  x: int,
  y: int,
}

@editor.completeFrom(HTMLEmbedElement)
and htmlEmbedElement = {
  mutable title: string,
  mutable lang: string,
  mutable translate: bool,
  mutable dir: string,
  mutable hidden: unknown,
  mutable inert: bool,
  mutable accessKey: string,
  accessKeyLabel: string,
  mutable draggable: bool,
  mutable spellcheck: bool,
  mutable autocapitalize: string,
  mutable innerText: string,
  mutable outerText: string,
  mutable popover: Null.t<string>,
  offsetParent: Null.t<element>,
  offsetTop: int,
  offsetLeft: int,
  offsetWidth: int,
  offsetHeight: int,
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  tagName: string,
  mutable id: string,
  mutable className: string,
  classList: domTokenList,
  mutable slot: string,
  attributes: namedNodeMap,
  shadowRoot: Null.t<shadowRoot>,
  part: domTokenList,
  mutable scrollTop: float,
  mutable scrollLeft: float,
  scrollWidth: int,
  scrollHeight: int,
  clientTop: int,
  clientLeft: int,
  clientWidth: int,
  clientHeight: int,
  currentCSSZoom: float,
  mutable innerHTML: string,
  mutable outerHTML: string,
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  mutable src: string,
  mutable width: string,
  mutable height: string,
}

@editor.completeFrom(HTMLAnchorElement)
and htmlAnchorElement = {
  mutable title: string,
  mutable lang: string,
  mutable translate: bool,
  mutable dir: string,
  mutable hidden: unknown,
  mutable inert: bool,
  mutable accessKey: string,
  accessKeyLabel: string,
  mutable draggable: bool,
  mutable spellcheck: bool,
  mutable autocapitalize: string,
  mutable innerText: string,
  mutable outerText: string,
  mutable popover: Null.t<string>,
  offsetParent: Null.t<element>,
  offsetTop: int,
  offsetLeft: int,
  offsetWidth: int,
  offsetHeight: int,
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  tagName: string,
  mutable id: string,
  mutable className: string,
  classList: domTokenList,
  mutable slot: string,
  attributes: namedNodeMap,
  shadowRoot: Null.t<shadowRoot>,
  part: domTokenList,
  mutable scrollTop: float,
  mutable scrollLeft: float,
  scrollWidth: int,
  scrollHeight: int,
  clientTop: int,
  clientLeft: int,
  clientWidth: int,
  clientHeight: int,
  currentCSSZoom: float,
  mutable innerHTML: string,
  mutable outerHTML: string,
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  mutable target: string,
  mutable download: string,
  mutable ping: string,
  mutable rel: string,
  relList: domTokenList,
  mutable hreflang: string,
  @as("type")
  mutable type_: string,
  mutable text: string,
  mutable referrerPolicy: string,
  mutable href: string,
  origin: string,
  mutable protocol: string,
  mutable username: string,
  mutable password: string,
  mutable host: string,
  mutable hostname: string,
  mutable port: string,
  mutable pathname: string,
  mutable search: string,
  mutable hash: string,
}

@editor.completeFrom(HTMLAreaElement)
and htmlAreaElement = {
  mutable title: string,
  mutable lang: string,
  mutable translate: bool,
  mutable dir: string,
  mutable hidden: unknown,
  mutable inert: bool,
  mutable accessKey: string,
  accessKeyLabel: string,
  mutable draggable: bool,
  mutable spellcheck: bool,
  mutable autocapitalize: string,
  mutable innerText: string,
  mutable outerText: string,
  mutable popover: Null.t<string>,
  offsetParent: Null.t<element>,
  offsetTop: int,
  offsetLeft: int,
  offsetWidth: int,
  offsetHeight: int,
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  tagName: string,
  mutable id: string,
  mutable className: string,
  classList: domTokenList,
  mutable slot: string,
  attributes: namedNodeMap,
  shadowRoot: Null.t<shadowRoot>,
  part: domTokenList,
  mutable scrollTop: float,
  mutable scrollLeft: float,
  scrollWidth: int,
  scrollHeight: int,
  clientTop: int,
  clientLeft: int,
  clientWidth: int,
  clientHeight: int,
  currentCSSZoom: float,
  mutable innerHTML: string,
  mutable outerHTML: string,
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  mutable target: string,
  mutable ping: string,
  mutable rel: string,
  relList: domTokenList,
  mutable referrerPolicy: string,
  mutable href: string,
  origin: string,
  mutable protocol: string,
  mutable username: string,
  mutable password: string,
  mutable host: string,
  mutable hostname: string,
  mutable port: string,
  mutable pathname: string,
  mutable search: string,
  mutable hash: string,
}

@editor.completeFrom(HTMLScriptElement)
and htmlScriptElement = {
  mutable title: string,
  mutable lang: string,
  mutable translate: bool,
  mutable dir: string,
  mutable hidden: unknown,
  mutable inert: bool,
  mutable accessKey: string,
  accessKeyLabel: string,
  mutable draggable: bool,
  mutable spellcheck: bool,
  mutable autocapitalize: string,
  mutable innerText: string,
  mutable outerText: string,
  mutable popover: Null.t<string>,
  offsetParent: Null.t<element>,
  offsetTop: int,
  offsetLeft: int,
  offsetWidth: int,
  offsetHeight: int,
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  tagName: string,
  mutable id: string,
  mutable className: string,
  classList: domTokenList,
  mutable slot: string,
  attributes: namedNodeMap,
  shadowRoot: Null.t<shadowRoot>,
  part: domTokenList,
  mutable scrollTop: float,
  mutable scrollLeft: float,
  scrollWidth: int,
  scrollHeight: int,
  clientTop: int,
  clientLeft: int,
  clientWidth: int,
  clientHeight: int,
  currentCSSZoom: float,
  mutable innerHTML: string,
  mutable outerHTML: string,
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  mutable src: string,
  @as("type")
  mutable type_: string,
  mutable noModule: bool,
  mutable async: bool,
  mutable defer: bool,
  mutable crossOrigin: Null.t<string>,
  mutable text: string,
  mutable integrity: string,
  mutable referrerPolicy: string,
  mutable fetchPriority: string,
}

@editor.completeFrom(DOMImplementation) and domImplementation = private {}

and documentType = {
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  name: string,
  publicId: string,
  systemId: string,
}

@editor.completeFrom(Document)
and document = {
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  implementation: domImplementation,
  @as("URL")
  url: string,
  documentURI: string,
  compatMode: string,
  characterSet: string,
  contentType: string,
  doctype: Null.t<documentType>,
  documentElement: htmlElement,
  scrollingElement: Null.t<element>,
  fullscreenEnabled: bool,
  mutable location: location,
  referrer: string,
  mutable cookie: string,
  lastModified: string,
  readyState: documentReadyState,
  mutable title: string,
  mutable dir: string,
  mutable body: htmlElement,
  head: htmlHeadElement,
  images: htmlCollection<htmlImageElement>,
  embeds: htmlCollection<htmlEmbedElement>,
  plugins: htmlCollection<htmlEmbedElement>,
  links: htmlCollection<element>,
  forms: htmlCollection<htmlFormElement>,
  scripts: htmlCollection<htmlScriptElement>,
  currentScript: Null.t<htmlElement>,
  defaultView: Null.t<window>,
  mutable designMode: string,
  hidden: bool,
  visibilityState: documentVisibilityState,
  pictureInPictureEnabled: bool,
  fragmentDirective: fragmentDirective,
  timeline: documentTimeline,
  fonts: BaseCSSFontLoading.fontFaceSet,
  styleSheets: styleSheetList,
  mutable adoptedStyleSheets: array<cssStyleSheet>,
  fullscreenElement: Null.t<element>,
  activeElement: Null.t<element>,
  pictureInPictureElement: Null.t<element>,
  pointerLockElement: Null.t<element>,
  children: htmlCollection<element>,
  firstElementChild: Null.t<element>,
  lastElementChild: Null.t<element>,
  childElementCount: int,
}

and mutationRecord = {
  @as("type")
  type_: string,
  target: node,
  addedNodes: nodeList<node>,
  removedNodes: nodeList<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  attributeName: Null.t<string>,
  attributeNamespace: Null.t<string>,
  oldValue: Null.t<string>,
}

and attr = {
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  name: string,
  mutable value: string,
  ownerElement: Null.t<element>,
}

@editor.completeFrom(CharacterData)
and characterData = {
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  mutable data: string,
  length: int,
  previousElementSibling: Null.t<element>,
  nextElementSibling: Null.t<element>,
}

@editor.completeFrom(DocumentFragment)
and documentFragment = {
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  children: htmlCollection<element>,
  firstElementChild: Null.t<element>,
  lastElementChild: Null.t<element>,
  childElementCount: int,
}

@editor.completeFrom(HTMLSlotElement)
and htmlSlotElement = {
  mutable title: string,
  mutable lang: string,
  mutable translate: bool,
  mutable dir: string,
  mutable hidden: unknown,
  mutable inert: bool,
  mutable accessKey: string,
  accessKeyLabel: string,
  mutable draggable: bool,
  mutable spellcheck: bool,
  mutable autocapitalize: string,
  mutable innerText: string,
  mutable outerText: string,
  mutable popover: Null.t<string>,
  offsetParent: Null.t<element>,
  offsetTop: int,
  offsetLeft: int,
  offsetWidth: int,
  offsetHeight: int,
  namespaceURI: Null.t<string>,
  prefix: Null.t<string>,
  localName: string,
  tagName: string,
  mutable id: string,
  mutable className: string,
  classList: domTokenList,
  mutable slot: string,
  attributes: namedNodeMap,
  shadowRoot: Null.t<shadowRoot>,
  part: domTokenList,
  mutable scrollTop: float,
  mutable scrollLeft: float,
  scrollWidth: int,
  scrollHeight: int,
  clientTop: int,
  clientLeft: int,
  clientWidth: int,
  clientHeight: int,
  currentCSSZoom: float,
  mutable innerHTML: string,
  mutable outerHTML: string,
  nodeType: int,
  nodeName: string,
  baseURI: string,
  isConnected: bool,
  ownerDocument: Null.t<document>,
  parentNode: Null.t<node>,
  parentElement: Null.t<htmlElement>,
  childNodes: nodeList<node>,
  firstChild: Null.t<node>,
  lastChild: Null.t<node>,
  previousSibling: Null.t<node>,
  nextSibling: Null.t<node>,
  mutable nodeValue: Null.t<string>,
  mutable textContent: Null.t<string>,
  mutable name: string,
}

@editor.completeFrom(DOMRectReadOnly)
type domRectReadOnly = private {
  x: float,
  y: float,
  width: float,
  height: float,
  top: float,
  right: float,
  bottom: float,
  left: float,
}

@editor.completeFrom(DOMRect)
type domRect = private {
  ...domRectReadOnly,
}

@editor.completeFrom(DOMRectList) type domRectList = private {}

type validityState = {
  valueMissing: bool,
  typeMismatch: bool,
  patternMismatch: bool,
  tooLong: bool,
  tooShort: bool,
  rangeUnderflow: bool,
  rangeOverflow: bool,
  stepMismatch: bool,
  badInput: bool,
  customError: bool,
  valid: bool,
}

type customStateSet = {}

@editor.completeFrom(ElementInternals)
type elementInternals = {
  shadowRoot: Null.t<shadowRoot>,
  form: Null.t<htmlFormElement>,
  willValidate: bool,
  validity: validityState,
  validationMessage: string,
  labels: nodeList<unknown>,
  states: customStateSet,
  mutable ariaAtomic: Null.t<string>,
  mutable ariaAutoComplete: Null.t<string>,
  mutable ariaBrailleLabel: Null.t<string>,
  mutable ariaBrailleRoleDescription: Null.t<string>,
  mutable ariaBusy: Null.t<string>,
  mutable ariaChecked: Null.t<string>,
  mutable ariaColCount: Null.t<string>,
  mutable ariaColIndex: Null.t<string>,
  mutable ariaColIndexText: Null.t<string>,
  mutable ariaColSpan: Null.t<string>,
  mutable ariaCurrent: Null.t<string>,
  mutable ariaDescription: Null.t<string>,
  mutable ariaDisabled: Null.t<string>,
  mutable ariaExpanded: Null.t<string>,
  mutable ariaHasPopup: Null.t<string>,
  mutable ariaHidden: Null.t<string>,
  mutable ariaKeyShortcuts: Null.t<string>,
  mutable ariaLabel: Null.t<string>,
  mutable ariaLevel: Null.t<string>,
  mutable ariaLive: Null.t<string>,
  mutable ariaModal: Null.t<string>,
  mutable ariaMultiLine: Null.t<string>,
  mutable ariaMultiSelectable: Null.t<string>,
  mutable ariaOrientation: Null.t<string>,
  mutable ariaPlaceholder: Null.t<string>,
  mutable ariaPosInSet: Null.t<string>,
  mutable ariaPressed: Null.t<string>,
  mutable ariaReadOnly: Null.t<string>,
  mutable ariaRequired: Null.t<string>,
  mutable ariaRoleDescription: Null.t<string>,
  mutable ariaRowCount: Null.t<string>,
  mutable ariaRowIndex: Null.t<string>,
  mutable ariaRowIndexText: Null.t<string>,
  mutable ariaRowSpan: Null.t<string>,
  mutable ariaSelected: Null.t<string>,
  mutable ariaSetSize: Null.t<string>,
  mutable ariaSort: Null.t<string>,
  mutable ariaValueMax: Null.t<string>,
  mutable ariaValueMin: Null.t<string>,
  mutable ariaValueNow: Null.t<string>,
  mutable ariaValueText: Null.t<string>,
}

type xmlDocument = {
  ...document,
}

@editor.completeFrom(Text)
type text = private {
  ...characterData,
  wholeText: string,
  assignedSlot: Null.t<htmlSlotElement>,
}

type cdataSection = {
  ...text,
}

@editor.completeFrom(Comment)
type comment = private {
  ...characterData,
}

type processingInstruction = {
  ...characterData,
  target: string,
  sheet: Null.t<cssStyleSheet>,
}

type abstractRange = {
  startContainer: node,
  startOffset: int,
  endContainer: node,
  endOffset: int,
  collapsed: bool,
}

@editor.completeFrom(Range)
type range = private {
  ...abstractRange,
  commonAncestorContainer: node,
}

type staticRange = {
  ...abstractRange,
}

@editor.completeFrom(NodeFilter) type nodeFilter = private {}

@editor.completeFrom(NodeIterator)
type nodeIterator = private {
  root: node,
  referenceNode: node,
  pointerBeforeReferenceNode: bool,
  whatToShow: int,
  filter: Null.t<nodeFilter>,
}

@editor.completeFrom(TreeWalker)
type treeWalker = {
  root: node,
  whatToShow: int,
  filter: Null.t<nodeFilter>,
  mutable currentNode: node,
}

@editor.completeFrom(CaretPosition)
type caretPosition = private {}

@editor.completeFrom(Selection)
type selection = private {
  anchorNode: Null.t<node>,
  anchorOffset: int,
  focusNode: Null.t<node>,
  focusOffset: int,
  isCollapsed: bool,
  rangeCount: int,
  @as("type")
  type_: string,
  direction: string,
}

@editor.completeFrom(MediaQueryList)
type mediaQueryList = private {
  ...BaseEvent.eventTarget,
  media: string,
  matches: bool,
}

@editor.completeFrom(IdleDeadline)
type idleDeadline = private {
  didTimeout: bool,
}

@editor.completeFrom(CSSStyleValue)
type cssStyleValue = private {}

@editor.completeFrom(FileList)
type fileList = private {
  length: int,
}

type mediaError = {
  code: int,
  message: string,
}

@editor.completeFrom(TimeRanges)
type timeRanges = private {
  length: int,
}

@editor.completeFrom(TextTrackList)
type textTrackList = private {
  ...BaseEvent.eventTarget,
  length: int,
}

type videoPlaybackQuality = {
  creationTime: float,
  droppedVideoFrames: int,
  totalVideoFrames: int,
}

@editor.completeFrom(HTMLTableElement)
type rec htmlTableElement = {
  ...htmlElement,
  mutable caption: Null.t<htmlTableCaptionElement>,
  mutable tHead: Null.t<htmlTableSectionElement>,
  mutable tFoot: Null.t<htmlTableSectionElement>,
  tBodies: htmlCollection<htmlTableSectionElement>,
  rows: htmlCollection<htmlTableRowElement>,
}

@editor.completeFrom(HTMLTableCaptionElement)
and htmlTableCaptionElement = private {
  ...htmlElement,
}

@editor.completeFrom(HTMLTableSectionElement)
and htmlTableSectionElement = private {
  ...htmlElement,
  rows: htmlCollection<htmlTableRowElement>,
}

@editor.completeFrom(HTMLTableCellElement)
and htmlTableCellElement = {
  ...htmlElement,
  mutable colSpan: int,
  mutable rowSpan: int,
  mutable headers: string,
  cellIndex: int,
  mutable scope: string,
  mutable abbr: string,
}

@editor.completeFrom(HTMLTableRowElement)
and htmlTableRowElement = private {
  ...htmlElement,
  rowIndex: int,
  sectionRowIndex: int,
  cells: htmlCollection<htmlTableCellElement>,
}

@editor.completeFrom(HTMLButtonElement)
type rec htmlButtonElement = {
  ...htmlElement,
  mutable disabled: bool,
  form: Null.t<htmlFormElement>,
  mutable formAction: string,
  mutable formEnctype: string,
  mutable formMethod: string,
  mutable name: string,
  @as("type")
  mutable type_: string,
  mutable value: string,
  willValidate: bool,
  validity: validityState,
  validationMessage: string,
  labels: nodeList<htmlLabelElement>,
  mutable popoverTargetElement: Null.t<element>,
  mutable popoverTargetAction: string,
}

@editor.completeFrom(HTMLLabelElement)
and htmlLabelElement = {
  ...htmlElement,
  form: Null.t<htmlFormElement>,
  mutable htmlFor: string,
  control: Null.t<htmlElement>,
}

@editor.completeFrom(HTMLTextAreaElement)
and htmlTextAreaElement = {
  ...htmlElement,
  mutable autocomplete: string,
  mutable cols: int,
  mutable disabled: bool,
  form: Null.t<htmlFormElement>,
  mutable maxLength: int,
  mutable minLength: int,
  mutable name: string,
  mutable placeholder: string,
  mutable readOnly: bool,
  mutable required: bool,
  mutable rows: int,
  mutable wrap: string,
  @as("type")
  type_: string,
  mutable defaultValue: string,
  mutable value: string,
  textLength: int,
  willValidate: bool,
  validity: validityState,
  validationMessage: string,
  labels: nodeList<htmlLabelElement>,
  mutable selectionStart: int,
  mutable selectionEnd: int,
  mutable selectionDirection: string,
}

@editor.completeFrom(HTMLOutputElement)
and htmlOutputElement = {
  ...htmlElement,
  htmlFor: domTokenList,
  form: Null.t<htmlFormElement>,
  mutable name: string,
  @as("type")
  type_: string,
  mutable defaultValue: string,
  mutable value: string,
  willValidate: bool,
  validity: validityState,
  validationMessage: string,
  labels: nodeList<htmlLabelElement>,
}

@editor.completeFrom(HTMLInputElement)
and htmlInputElement = {
  ...htmlElement,
  mutable accept: string,
  mutable alt: string,
  mutable autocomplete: string,
  mutable defaultChecked: bool,
  mutable checked: bool,
  mutable disabled: bool,
  form: Null.t<htmlFormElement>,
  mutable files: Null.t<fileList>,
  mutable formAction: string,
  mutable formEnctype: string,
  mutable formMethod: string,
  mutable height: int,
  mutable indeterminate: bool,
  list: Null.t<htmlDataListElement>,
  mutable max: string,
  mutable maxLength: int,
  mutable min: string,
  mutable minLength: int,
  mutable multiple: bool,
  mutable name: string,
  mutable pattern: string,
  mutable placeholder: string,
  mutable readOnly: bool,
  mutable required: bool,
  mutable size: int,
  mutable src: string,
  mutable step: string,
  @as("type")
  mutable type_: string,
  mutable defaultValue: string,
  mutable value: string,
  mutable valueAsDate: Null.t<Date.t>,
  mutable valueAsNumber: float,
  mutable width: int,
  willValidate: bool,
  validity: validityState,
  validationMessage: string,
  labels: Null.t<nodeList<htmlLabelElement>>,
  mutable selectionStart: Null.t<int>,
  mutable selectionEnd: Null.t<int>,
  mutable selectionDirection: Null.t<string>,
  mutable webkitdirectory: bool,
  webkitEntries: array<BaseFileAndDirectoryEntries.fileSystemEntry>,
  mutable capture: string,
  mutable popoverTargetElement: Null.t<element>,
  mutable popoverTargetAction: string,
}

@editor.completeFrom(HTMLDataListElement)
and htmlDataListElement = private {
  ...htmlElement,
  options: htmlCollection<htmlOptionElement>,
}

@editor.completeFrom(HTMLSelectElement)
and htmlSelectElement = {
  ...htmlElement,
  mutable disabled: bool,
  form: Null.t<htmlFormElement>,
  mutable multiple: bool,
  mutable name: string,
  mutable required: bool,
  mutable size: int,
  @as("type")
  type_: string,
  options: htmlOptionsCollection,
  mutable length: int,
  selectedOptions: htmlCollection<htmlOptionElement>,
  mutable selectedIndex: int,
  mutable value: string,
  willValidate: bool,
  validity: validityState,
  validationMessage: string,
  labels: nodeList<htmlLabelElement>,
}

@editor.completeFrom(HTMLOptionElement)
and htmlOptionElement = {
  ...htmlElement,
  mutable disabled: bool,
  form: Null.t<htmlFormElement>,
  mutable label: string,
  mutable defaultSelected: bool,
  mutable selected: bool,
  mutable value: string,
  mutable text: string,
  index: int,
}

@editor.completeFrom(HTMLOptionsCollection)
and htmlOptionsCollection = {
  ...htmlCollection<htmlOptionElement>,
  mutable selectedIndex: int,
}
