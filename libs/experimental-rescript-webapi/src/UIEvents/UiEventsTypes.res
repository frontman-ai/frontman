@@warning("-30")

type touchType =
  | @as("direct") Direct
  | @as("stylus") Stylus

@editor.completeFrom(UIEvent)
type uiEvent = private {
  ...EventTypes.event,
  view: Null.t<DOM.window>,
  detail: int,
}

@editor.completeFrom(CompositionEvent)
type compositionEvent = private {
  ...uiEvent,
  data: string,
}

@editor.completeFrom(FocusEvent)
type focusEvent = private {
  ...uiEvent,
  relatedTarget: Null.t<EventTypes.eventTarget>,
}

@editor.completeFrom(DataTransferItem)
type dataTransferItem = private {
  kind: string,
  @as("type")
  type_: string,
}

@editor.completeFrom(DataTransferItemList)
type dataTransferItemList = private {
  length: int,
}

@editor.completeFrom(DataTransfer)
type dataTransfer = {
  mutable dropEffect: string,
  mutable effectAllowed: string,
  items: dataTransferItemList,
  types: array<string>,
  files: DomTypes.fileList,
}

@editor.completeFrom(ClipboardEvent)
type clipboardEvent = private {
  ...EventTypes.event,
  clipboardData: Null.t<dataTransfer>,
}

@editor.completeFrom(InputEvent)
type inputEvent = private {
  ...uiEvent,
  data: Null.t<string>,
  isComposing: bool,
  inputType: string,
  dataTransfer: Null.t<dataTransfer>,
}

@editor.completeFrom(KeyboardEvent)
type keyboardEvent = private {
  ...uiEvent,
  key: string,
  code: string,
  location: int,
  ctrlKey: bool,
  shiftKey: bool,
  altKey: bool,
  metaKey: bool,
  repeat: bool,
  isComposing: bool,
}

@editor.completeFrom(MouseEvent)
type mouseEvent = private {
  ...uiEvent,
  screenX: int,
  screenY: int,
  clientX: int,
  clientY: int,
  layerX: int,
  layerY: int,
  ctrlKey: bool,
  shiftKey: bool,
  altKey: bool,
  metaKey: bool,
  button: int,
  buttons: int,
  relatedTarget: Null.t<EventTypes.eventTarget>,
  pageX: float,
  pageY: float,
  x: float,
  y: float,
  offsetX: float,
  offsetY: float,
  movementX: float,
  movementY: float,
}

@editor.completeFrom(DragEvent)
type dragEvent = private {
  ...mouseEvent,
  dataTransfer: Null.t<dataTransfer>,
}

@editor.completeFrom(WheelEvent)
type wheelEvent = private {
  ...mouseEvent,
  deltaX: float,
  deltaY: float,
  deltaZ: float,
  deltaMode: int,
}

@editor.completeFrom(Touch)
type touch = private {
  identifier: int,
  target: EventTypes.eventTarget,
  screenX: float,
  screenY: float,
  clientX: float,
  clientY: float,
  pageX: float,
  pageY: float,
  radiusX: float,
  radiusY: float,
  rotationAngle: float,
  force: float,
}

@editor.completeFrom(TouchList)
type touchList = private {
  length: int,
}

@editor.completeFrom(TouchEvent)
type touchEvent = private {
  ...uiEvent,
  touches: touchList,
  targetTouches: touchList,
  changedTouches: touchList,
  altKey: bool,
  metaKey: bool,
  ctrlKey: bool,
  shiftKey: bool,
}

@editor.completeFrom(PointerEvent)
type pointerEvent = private {
  ...mouseEvent,
  pointerId: int,
  width: float,
  height: float,
  pressure: float,
  tangentialPressure: float,
  tiltX: int,
  tiltY: int,
  twist: int,
  altitudeAngle: float,
  azimuthAngle: float,
  pointerType: string,
  isPrimary: bool,
}

type uiEventInit = {
  ...EventTypes.eventInit,
  mutable view?: Null.t<DOM.window>,
  mutable detail?: int,
  mutable which?: int,
}

type eventModifierInit = {
  ...uiEventInit,
  mutable ctrlKey?: bool,
  mutable shiftKey?: bool,
  mutable altKey?: bool,
  mutable metaKey?: bool,
  mutable modifierAltGraph?: bool,
  mutable modifierCapsLock?: bool,
  mutable modifierFn?: bool,
  mutable modifierFnLock?: bool,
  mutable modifierHyper?: bool,
  mutable modifierNumLock?: bool,
  mutable modifierScrollLock?: bool,
  mutable modifierSuper?: bool,
  mutable modifierSymbol?: bool,
  mutable modifierSymbolLock?: bool,
}

type mouseEventInit = {
  ...eventModifierInit,
  mutable screenX?: int,
  mutable screenY?: int,
  mutable clientX?: int,
  mutable clientY?: int,
  mutable button?: int,
  mutable buttons?: int,
  mutable relatedTarget?: Null.t<EventTypes.eventTarget>,
  mutable movementX?: float,
  mutable movementY?: float,
}

type focusEventInit = {
  ...uiEventInit,
  mutable relatedTarget?: Null.t<EventTypes.eventTarget>,
}

type compositionEventInit = {
  ...uiEventInit,
  mutable data?: string,
}

type wheelEventInit = {
  ...mouseEventInit,
  mutable deltaX?: float,
  mutable deltaY?: float,
  mutable deltaZ?: float,
  mutable deltaMode?: int,
}

type keyboardEventInit = {
  ...eventModifierInit,
  mutable key?: string,
  mutable code?: string,
  mutable location?: int,
  mutable repeat?: bool,
  mutable isComposing?: bool,
  mutable charCode?: int,
  mutable keyCode?: int,
}

type inputEventInit = {
  ...uiEventInit,
  mutable data?: Null.t<string>,
  mutable isComposing?: bool,
  mutable inputType?: string,
  mutable dataTransfer?: Null.t<dataTransfer>,
  mutable targetRanges?: array<DOM.staticRange>,
}

type clipboardEventInit = {
  ...EventTypes.eventInit,
  mutable clipboardData?: Null.t<dataTransfer>,
}

type dragEventInit = {
  ...mouseEventInit,
  mutable dataTransfer?: Null.t<dataTransfer>,
}

type touchInit = {
  mutable identifier: int,
  mutable target: EventTypes.eventTarget,
  mutable clientX?: float,
  mutable clientY?: float,
  mutable screenX?: float,
  mutable screenY?: float,
  mutable pageX?: float,
  mutable pageY?: float,
  mutable radiusX?: float,
  mutable radiusY?: float,
  mutable rotationAngle?: float,
  mutable force?: float,
  mutable altitudeAngle?: float,
  mutable azimuthAngle?: float,
  mutable touchType?: touchType,
}

type pointerEventInit = {
  ...mouseEventInit,
  mutable pointerId?: int,
  mutable width?: float,
  mutable height?: float,
  mutable pressure?: float,
  mutable tangentialPressure?: float,
  mutable tiltX?: int,
  mutable tiltY?: int,
  mutable twist?: int,
  mutable altitudeAngle?: float,
  mutable azimuthAngle?: float,
  mutable pointerType?: string,
  mutable isPrimary?: bool,
  mutable coalescedEvents?: array<pointerEvent>,
  mutable predictedEvents?: array<pointerEvent>,
}

type touchEventInit = {
  ...eventModifierInit,
  mutable touches?: array<touch>,
  mutable targetTouches?: array<touch>,
  mutable changedTouches?: array<touch>,
}
