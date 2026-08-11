/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer)
*/
@new
external make: unit => UiEventsTypes.dataTransfer = "DataTransfer"

/**
Uses the given element to update the drag feedback, replacing any previously specified feedback.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer/setDragImage)
*/
@send
external setDragImage: (
  UiEventsTypes.dataTransfer,
  ~image: DomTypes.element,
  ~x: int,
  ~y: int,
) => unit = "setDragImage"

/**
Returns the specified data. If there is no such data, returns the empty string.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer/getData)
*/
@send
external getData: (UiEventsTypes.dataTransfer, string) => string = "getData"

/**
Adds the specified data.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer/setData)
*/
@send
external setData: (UiEventsTypes.dataTransfer, ~format: string, ~data: string) => unit = "setData"

/**
Removes the data of the specified formats. Removes all data if the argument is omitted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DataTransfer/clearData)
*/
@send
external clearData: (UiEventsTypes.dataTransfer, ~format: string=?) => unit = "clearData"
