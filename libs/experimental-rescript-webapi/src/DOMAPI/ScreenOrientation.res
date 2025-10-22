open DOMAPI

include EventTarget.Impl({type t = screenOrientation})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ScreenOrientation/unlock)
*/
@send
external unlock: screenOrientation => unit = "unlock"
