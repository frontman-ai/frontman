include EventTarget.Impl({type t = DomTypes.screenOrientation})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ScreenOrientation/unlock)
*/
@send
external unlock: DomTypes.screenOrientation => unit = "unlock"
