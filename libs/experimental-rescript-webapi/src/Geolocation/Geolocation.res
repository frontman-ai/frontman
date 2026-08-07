/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Geolocation/getCurrentPosition)
*/
@send
external getCurrentPosition: (
  GeolocationTypes.geolocation,
  ~successCallback: GeolocationTypes.positionCallback,
  ~errorCallback: GeolocationTypes.positionErrorCallback=?,
  ~options: GeolocationTypes.positionOptions=?,
) => unit = "getCurrentPosition"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Geolocation/watchPosition)
*/
@send
external watchPosition: (
  GeolocationTypes.geolocation,
  ~successCallback: GeolocationTypes.positionCallback,
  ~errorCallback: GeolocationTypes.positionErrorCallback=?,
  ~options: GeolocationTypes.positionOptions=?,
) => int = "watchPosition"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Geolocation/clearWatch)
*/
@send
external clearWatch: (GeolocationTypes.geolocation, int) => unit = "clearWatch"

module GeolocationCoordinates = GeolocationCoordinates
module GeolocationPosition = GeolocationPosition
module Types = GeolocationTypes
