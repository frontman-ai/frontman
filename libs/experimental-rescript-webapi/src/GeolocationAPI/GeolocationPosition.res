open GeolocationAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationPosition/toJSON)
*/
@send
external toJSON: geolocationPosition => Dict.t<string> = "toJSON"
