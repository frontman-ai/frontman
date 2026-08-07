@@warning("-30")
@editor.completeFrom(WebApiGeolocation)
type geolocation = private {}

@editor.completeFrom(GeolocationCoordinates)
type geolocationCoordinates = private {
  accuracy: float,
  latitude: float,
  longitude: float,
  altitude: Null.t<float>,
  altitudeAccuracy: Null.t<float>,
  heading: Null.t<float>,
  speed: Null.t<float>,
}

@editor.completeFrom(GeolocationPosition)
type geolocationPosition = private {
  coords: geolocationCoordinates,
  timestamp: int,
}

type geolocationPositionError = {
  code: int,
  message: string,
}

type positionOptions = {
  mutable enableHighAccuracy?: bool,
  mutable timeout?: int,
  mutable maximumAge?: int,
}

type positionCallback = geolocationPosition => unit

type positionErrorCallback = geolocationPositionError => unit
