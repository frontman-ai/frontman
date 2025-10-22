open GeolocationAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Geolocation/getCurrentPosition)
*/
@send
external getCurrentPosition: (
  geolocation,
  ~successCallback: positionCallback,
  ~errorCallback: positionErrorCallback=?,
  ~options: positionOptions=?,
) => unit = "getCurrentPosition"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Geolocation/watchPosition)
*/
@send
external watchPosition: (
  geolocation,
  ~successCallback: positionCallback,
  ~errorCallback: positionErrorCallback=?,
  ~options: positionOptions=?,
) => int = "watchPosition"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Geolocation/clearWatch)
*/
@send
external clearWatch: (geolocation, int) => unit = "clearWatch"
