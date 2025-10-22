open DOMAPI

/**
Returns the time for the start of the range with the given index.

Throws an "IndexSizeError" DOMException if the index is out of range.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TimeRanges/start)
*/
@send
external start: (timeRanges, int) => float = "start"

/**
Returns the time for the end of the range with the given index.

Throws an "IndexSizeError" DOMException if the index is out of range.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TimeRanges/end)
*/
@send
external end: (timeRanges, int) => float = "end"
