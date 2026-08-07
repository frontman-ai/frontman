@send
external getCurrentPosition: (
  GeolocationTypes.geolocation,
  ~successCallback: GeolocationTypes.positionCallback,
  ~errorCallback: GeolocationTypes.positionErrorCallback=?,
  ~options: GeolocationTypes.positionOptions=?,
) => unit = "getCurrentPosition"

@send
external watchPosition: (
  GeolocationTypes.geolocation,
  ~successCallback: GeolocationTypes.positionCallback,
  ~errorCallback: GeolocationTypes.positionErrorCallback=?,
  ~options: GeolocationTypes.positionOptions=?,
) => int = "watchPosition"

@send
external clearWatch: (GeolocationTypes.geolocation, int) => unit = "clearWatch"

module GeolocationCoordinates = GeolocationCoordinates
module GeolocationPosition = GeolocationPosition
module Types = GeolocationTypes
