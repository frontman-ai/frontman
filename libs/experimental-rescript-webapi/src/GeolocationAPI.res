@@warning("-30")
/**
An object able to programmatically obtain the position of the device. It gives Web content access to the location of the device. This allows a Web site or app to offer customized results based on the user's location.
[See Geolocation on MDN](https://developer.mozilla.org/docs/Web/API/Geolocation)
*/
@editor.completeFrom(Geolocation)
type geolocation = {}

/**
[See GeolocationCoordinates on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationCoordinates)
*/
@editor.completeFrom(GeolocationCoordinates)
type geolocationCoordinates = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationCoordinates/accuracy)
    */
  accuracy: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationCoordinates/latitude)
    */
  latitude: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationCoordinates/longitude)
    */
  longitude: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationCoordinates/altitude)
    */
  altitude: Null.t<float>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationCoordinates/altitudeAccuracy)
    */
  altitudeAccuracy: Null.t<float>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationCoordinates/heading)
    */
  heading: Null.t<float>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationCoordinates/speed)
    */
  speed: Null.t<float>,
}

/**
[See GeolocationPosition on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationPosition)
*/
@editor.completeFrom(GeolocationPosition)
type geolocationPosition = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationPosition/coords)
    */
  coords: geolocationCoordinates,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationPosition/timestamp)
    */
  timestamp: int,
}

/**
[See GeolocationPositionError on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationPositionError)
*/
type geolocationPositionError = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationPositionError/code)
    */
  code: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GeolocationPositionError/message)
    */
  message: string,
}

type positionOptions = {
  mutable enableHighAccuracy?: bool,
  mutable timeout?: int,
  mutable maximumAge?: int,
}

type positionCallback = geolocationPosition => unit

type positionErrorCallback = geolocationPositionError => unit
