open PushAPI

/**
The json() method of the PushMessageData interface extracts push message data by parsing it as a JSON string and returning the result.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushMessageData/json)
*/
@send
external json: pushMessageData => JSON.t = "json"

/**
The text() method of the PushMessageData interface extracts push message data as a plain text string.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PushMessageData/text)
*/
@send
external text: pushMessageData => string = "text"
