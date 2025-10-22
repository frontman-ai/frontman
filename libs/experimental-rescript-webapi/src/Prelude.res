@@warning("-30")
type any = {}

external unsafeConversation: 'tinput => 'toutput = "%identity"

type bufferSource = any

type sharedArrayBuffer = any

type float64Array = any

/**
An abnormal event (called an exception) which occurs as a result of calling a method or accessing a property of a web API.
[See DOMException on MDN](https://developer.mozilla.org/docs/Web/API/DOMException)
*/
type domException = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMException/name)
    */
  name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMException/message)
    */
  message: string,
}

/**
A type returned by some APIs which contains a list of DOMString (strings).
[See DOMStringList on MDN](https://developer.mozilla.org/docs/Web/API/DOMStringList)
*/
type domStringList = {
  /**
    Returns the number of strings in strings.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMStringList/length)
    */
  length: int,
}
