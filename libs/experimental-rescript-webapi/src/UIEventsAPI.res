@@warning("-30")

open EventAPI
open DOMAPI

type touchType =
  | @as("direct") Direct
  | @as("stylus") Stylus

/**
Simple user interface events.
[See UIEvent on MDN](https://developer.mozilla.org/docs/Web/API/UIEvent)
*/
@editor.completeFrom(UIEvent)
type uiEvent = {
  ...event,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/UIEvent/view)
    */
  view: Null.t<window>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/UIEvent/detail)
    */
  detail: int,
}

/**
The DOM CompositionEvent represents events that occur due to the user indirectly entering text.
[See CompositionEvent on MDN](https://developer.mozilla.org/docs/Web/API/CompositionEvent)
*/
@editor.completeFrom(CompositionEvent)
type compositionEvent = {
  ...uiEvent,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CompositionEvent/data)
    */
  data: string,
}

/**
Focus-related events like focus, blur, focusin, or focusout.
[See FocusEvent on MDN](https://developer.mozilla.org/docs/Web/API/FocusEvent)
*/
@editor.completeFrom(FocusEvent)
type focusEvent = {
  ...uiEvent,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FocusEvent/relatedTarget)
    */
  relatedTarget: Null.t<eventTarget>,
}

/**
One drag data item. During a drag operation, each drag event has a dataTransfer property which contains a list of drag data items. Each item in the list is a DataTransferItem object.
[See DataTransferItem on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItem)
*/
@editor.completeFrom(DataTransferItem)
type dataTransferItem = {
  /**
    Returns the drag data item kind, one of: "string", "file".
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItem/kind)
    */
  kind: string,
  /**
    Returns the drag data item type string.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItem/type)
    */
  @as("type")
  type_: string,
}

/**
A list of DataTransferItem objects representing items being dragged. During a drag operation, each DragEvent has a dataTransfer property and that property is a DataTransferItemList.
[See DataTransferItemList on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItemList)
*/
@editor.completeFrom(DataTransferItemList)
type dataTransferItemList = {
  /**
    Returns the number of items in the drag data store.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransferItemList/length)
    */
  length: int,
}

/**
Used to hold the data that is being dragged during a drag and drop operation. It may hold one or more data items, each of one or more data types. For more information about drag and drop, see HTML Drag and Drop API.
[See DataTransfer on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer)
*/
@editor.completeFrom(DataTransfer)
type dataTransfer = {
  /**
    Returns the kind of operation that is currently selected. If the kind of operation isn't one of those that is allowed by the effectAllowed attribute, then the operation will fail.

Can be set, to change the selected operation.

The possible values are "none", "copy", "link", and "move".
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer/dropEffect)
    */
  mutable dropEffect: string,
  /**
    Returns the kinds of operations that are to be allowed.

Can be set (during the dragstart event), to change the allowed operations.

The possible values are "none", "copy", "copyLink", "copyMove", "link", "linkMove", "move", "all", and "uninitialized",
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer/effectAllowed)
    */
  mutable effectAllowed: string,
  /**
    Returns a DataTransferItemList object, with the drag data.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer/items)
    */
  items: dataTransferItemList,
  /**
    Returns a frozen array listing the formats that were set in the dragstart event. In addition, if any files are being dragged, then one of the types will be the string "Files".
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer/types)
    */
  types: array<string>,
  /**
    Returns a FileList of the files being dragged, if any.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer/files)
    */
  files: fileList,
}

/**
[See InputEvent on MDN](https://developer.mozilla.org/docs/Web/API/InputEvent)
*/
@editor.completeFrom(InputEvent)
type inputEvent = {
  ...uiEvent,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/InputEvent/data)
    */
  data: Null.t<string>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/InputEvent/isComposing)
    */
  isComposing: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/InputEvent/inputType)
    */
  inputType: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/InputEvent/dataTransfer)
    */
  dataTransfer: Null.t<dataTransfer>,
}

/**
KeyboardEvent objects describe a user interaction with the keyboard; each event describes a single interaction between the user and a key (or combination of a key with modifier keys) on the keyboard.
[See KeyboardEvent on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent)
*/
@editor.completeFrom(KeyboardEvent)
type keyboardEvent = {
  ...uiEvent,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/key)
    */
  key: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/code)
    */
  code: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/location)
    */
  location: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/ctrlKey)
    */
  ctrlKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/shiftKey)
    */
  shiftKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/altKey)
    */
  altKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/metaKey)
    */
  metaKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/repeat)
    */
  repeat: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/KeyboardEvent/isComposing)
    */
  isComposing: bool,
}

/**
Events that occur due to the user interacting with a pointing device (such as a mouse). Common events using this interface include click, dblclick, mouseup, mousedown.
[See MouseEvent on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent)
*/
@editor.completeFrom(MouseEvent)
type mouseEvent = {
  ...uiEvent,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/screenX)
    */
  screenX: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/screenY)
    */
  screenY: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/clientX)
    */
  clientX: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/clientY)
    */
  clientY: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/layerX)
    */
  layerX: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/layerY)
    */
  layerY: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/ctrlKey)
    */
  ctrlKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/shiftKey)
    */
  shiftKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/altKey)
    */
  altKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/metaKey)
    */
  metaKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/button)
    */
  button: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/buttons)
    */
  buttons: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/relatedTarget)
    */
  relatedTarget: Null.t<eventTarget>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/pageX)
    */
  pageX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/pageY)
    */
  pageY: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/x)
    */
  x: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/y)
    */
  y: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/offsetX)
    */
  offsetX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/offsetY)
    */
  offsetY: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/movementX)
    */
  movementX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MouseEvent/movementY)
    */
  movementY: float,
}

/**
Events that occur due to the user moving a mouse wheel or similar input device.
[See WheelEvent on MDN](https://developer.mozilla.org/docs/Web/API/WheelEvent)
*/
@editor.completeFrom(WheelEvent)
type wheelEvent = {
  ...mouseEvent,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WheelEvent/deltaX)
    */
  deltaX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WheelEvent/deltaY)
    */
  deltaY: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WheelEvent/deltaZ)
    */
  deltaZ: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WheelEvent/deltaMode)
    */
  deltaMode: int,
}

/**
A single contact point on a touch-sensitive device. The contact point is commonly a finger or stylus and the device may be a touchscreen or trackpad.
[See Touch on MDN](https://developer.mozilla.org/docs/Web/API/Touch)
*/
@editor.completeFrom(Touch)
type touch = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/identifier)
    */
  identifier: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/target)
    */
  target: eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/screenX)
    */
  screenX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/screenY)
    */
  screenY: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/clientX)
    */
  clientX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/clientY)
    */
  clientY: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/pageX)
    */
  pageX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/pageY)
    */
  pageY: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/radiusX)
    */
  radiusX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/radiusY)
    */
  radiusY: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/rotationAngle)
    */
  rotationAngle: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Touch/force)
    */
  force: float,
}

/**
A list of contact points on a touch surface. For example, if the user has three fingers on the touch surface (such as a screen or trackpad), the corresponding TouchList object would have one Touch object for each finger, for a total of three entries.
[See TouchList on MDN](https://developer.mozilla.org/docs/Web/API/TouchList)
*/
@editor.completeFrom(TouchList)
type touchList = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TouchList/length)
    */
  length: int,
}

/**
An event sent when the state of contacts with a touch-sensitive surface changes. This surface can be a touch screen or trackpad, for example. The event can describe one or more points of contact with the screen and includes support for detecting movement, addition and removal of contact points, and so forth.
[See TouchEvent on MDN](https://developer.mozilla.org/docs/Web/API/TouchEvent)
*/
@editor.completeFrom(TouchEvent)
type touchEvent = {
  ...uiEvent,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TouchEvent/touches)
    */
  touches: touchList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TouchEvent/targetTouches)
    */
  targetTouches: touchList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TouchEvent/changedTouches)
    */
  changedTouches: touchList,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TouchEvent/altKey)
    */
  altKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TouchEvent/metaKey)
    */
  metaKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TouchEvent/ctrlKey)
    */
  ctrlKey: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TouchEvent/shiftKey)
    */
  shiftKey: bool,
}

/**
The state of a DOM event produced by a pointer such as the geometry of the contact point, the device type that generated the event, the amount of pressure that was applied on the contact surface, etc.
[See PointerEvent on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent)
*/
@editor.completeFrom(PointerEvent)
type pointerEvent = {
  ...mouseEvent,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/pointerId)
    */
  pointerId: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/width)
    */
  width: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/height)
    */
  height: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/pressure)
    */
  pressure: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/tangentialPressure)
    */
  tangentialPressure: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/tiltX)
    */
  tiltX: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/tiltY)
    */
  tiltY: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/twist)
    */
  twist: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/altitudeAngle)
    */
  altitudeAngle: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/azimuthAngle)
    */
  azimuthAngle: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/pointerType)
    */
  pointerType: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PointerEvent/isPrimary)
    */
  isPrimary: bool,
}

type uiEventInit = {
  ...eventInit,
  mutable view?: Null.t<window>,
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
  mutable relatedTarget?: Null.t<eventTarget>,
  mutable movementX?: float,
  mutable movementY?: float,
}

type focusEventInit = {
  ...uiEventInit,
  mutable relatedTarget?: Null.t<eventTarget>,
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
  mutable targetRanges?: array<staticRange>,
}

type touchInit = {
  mutable identifier: int,
  mutable target: eventTarget,
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
