open WebAudioAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PeriodicWave)
*/
@new
external make: (~context: baseAudioContext, ~options: periodicWaveOptions=?) => periodicWave =
  "PeriodicWave"
