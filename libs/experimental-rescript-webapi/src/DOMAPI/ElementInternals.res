open DOMAPI

/**
Sets both the state and submission value of internals's target element to value.

If value is null, the element won't participate in form submission.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/setFormValue)
*/
@send
external setFormValue: (elementInternals, ~value: unknown, ~state: unknown=?) => unit =
  "setFormValue"

/**
Marks internals's target element as suffering from the constraints indicated by the flags argument, and sets the element's validation message to message. If anchor is specified, the user agent might use it to indicate problems with the constraints of internals's target element when the form owner is validated interactively or reportValidity() is called.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/setValidity)
*/
@send
external setValidity: (
  elementInternals,
  ~flags: validityStateFlags=?,
  ~message: string=?,
  ~anchor: htmlElement=?,
) => unit = "setValidity"

/**
Returns true if internals's target element has no validity problems; false otherwise. Fires an invalid event at the element in the latter case.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/checkValidity)
*/
@send
external checkValidity: elementInternals => bool = "checkValidity"

/**
Returns true if internals's target element has no validity problems; otherwise, returns false, fires an invalid event at the element, and (if the event isn't canceled) reports the problem to the user.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ElementInternals/reportValidity)
*/
@send
external reportValidity: elementInternals => bool = "reportValidity"
