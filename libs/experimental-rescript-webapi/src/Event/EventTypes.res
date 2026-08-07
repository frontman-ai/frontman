@@warning("-30")

@unboxed
type eventType =
  | @as("abort") Abort
  | @as("activate") Activate
  | @as("auxclick") Auxclick
  | @as("beforeinput") Beforeinput
  | @as("beforetoggle") Beforetoggle
  | @as("blur") Blur
  | @as("cancel") Cancel
  | @as("canplay") Canplay
  | @as("canplaythrough") Canplaythrough
  | @as("change") Change
  | @as("click") Click
  | @as("close") Close
  | @as("contextlost") Contextlost
  | @as("contextmenu") Contextmenu
  | @as("contextrestored") Contextrestored
  | @as("copy") Copy
  | @as("cuechange") Cuechange
  | @as("cut") Cut
  | @as("dblclick") Dblclick
  | @as("DOMContentLoaded") DOMContentLoaded
  | @as("drag") Drag
  | @as("dragend") Dragend
  | @as("dragenter") Dragenter
  | @as("dragleave") Dragleave
  | @as("dragover") Dragover
  | @as("dragstart") Dragstart
  | @as("drop") Drop
  | @as("durationchange") Durationchange
  | @as("emptied") Emptied
  | @as("ended") Ended
  | @as("error") Error
  | @as("focus") Focus
  | @as("formdata") Formdata
  | @as("input") Input
  | @as("install") Install
  | @as("invalid") Invalid
  | @as("keydown") Keydown
  | @as("keypress") Keypress
  | @as("keyup") Keyup
  | @as("load") Load
  | @as("loadeddata") Loadeddata
  | @as("loadedmetadata") Loadedmetadata
  | @as("loadstart") Loadstart
  | @as("message") Message
  | @as("messageerror") MessageError
  | @as("mousedown") Mousedown
  | @as("mouseenter") Mouseenter
  | @as("mouseleave") Mouseleave
  | @as("mousemove") Mousemove
  | @as("mouseout") Mouseout
  | @as("mouseover") Mouseover
  | @as("mouseup") Mouseup
  | @as("notificationclick") NotificationClick
  | @as("paste") Paste
  | @as("pause") Pause
  | @as("play") Play
  | @as("playing") Playing
  | @as("progress") Progress
  | @as("ratechange") Ratechange
  | @as("reset") Reset
  | @as("resize") Resize
  | @as("scroll") Scroll
  | @as("scrollend") Scrollend
  | @as("securitypolicyviolation") Securitypolicyviolation
  | @as("seeked") Seeked
  | @as("seeking") Seeking
  | @as("select") Select
  | @as("slotchange") Slotchange
  | @as("stalled") Stalled
  | @as("submit") Submit
  | @as("suspend") Suspend
  | @as("timeupdate") Timeupdate
  | @as("toggle") Toggle
  | @as("volumechange") Volumechange
  | @as("waiting") Waiting
  | @as("webkitanimationend") Webkitanimationend
  | @as("webkitanimationiteration") Webkitanimationiteration
  | @as("webkitanimationstart") Webkitanimationstart
  | @as("webkittransitionend") Webkittransitionend
  | @as("wheel") Wheel
  | @as("animationstart") Animationstart
  | @as("animationiteration") Animationiteration
  | @as("animationend") Animationend
  | @as("animationcancel") Animationcancel
  | @as("transitionrun") Transitionrun
  | @as("transitionstart") Transitionstart
  | @as("transitionend") Transitionend
  | @as("transitioncancel") Transitioncancel
  | @as("pointerover") Pointerover
  | @as("pointerenter") Pointerenter
  | @as("pointerdown") Pointerdown
  | @as("pointermove") Pointermove
  | @as("pointerup") Pointerup
  | @as("pointercancel") Pointercancel
  | @as("pointerout") Pointerout
  | @as("pointerleave") Pointerleave
  | @as("push") Push
  | @as("gotpointercapture") Gotpointercapture
  | @as("lostpointercapture") Lostpointercapture
  | @as("selectstart") Selectstart
  | @as("selectionchange") Selectionchange
  | @as("touchstart") Touchstart
  | @as("touchend") Touchend
  | @as("touchmove") Touchmove
  | @as("touchcancel") Touchcancel
  | Custom(string)

type eventListener<'event> = 'event => unit

@editor.completeFrom(EventTarget)
type eventTarget = BaseEvent.eventTarget = private {...BaseEvent.eventTarget}

@editor.completeFrom(WebApiEvent)
type event = private {
  @as("type")
  type_: eventType,
  target: Null.t<eventTarget>,
  currentTarget: Null.t<eventTarget>,
  eventPhase: int,
  bubbles: bool,
  cancelable: bool,
  defaultPrevented: bool,
  composed: bool,
  isTrusted: bool,
  timeStamp: float,
}

@editor.completeFrom(AbortController)
type rec abortController = private {
  signal: abortSignal,
}

@editor.completeFrom(AbortSignal)
and abortSignal = private {
  ...eventTarget,
  aborted: bool,
  reason: JSON.t,
}

type eventListenerOptions = {mutable capture?: bool}

type addEventListenerOptions = {
  ...eventListenerOptions,
  mutable passive?: bool,
  mutable once?: bool,
  mutable signal?: abortSignal,
}

type eventInit = {
  mutable bubbles?: bool,
  mutable cancelable?: bool,
  mutable composed?: bool,
}

@editor.completeFrom(ExtendableEvent)
type extendableEvent = private {
  ...event,
}
