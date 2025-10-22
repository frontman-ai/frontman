open WebAudioAPI

module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  external asAudioNode: T.t => audioNode = "%identity"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/connect)
*/
  @send
  external connect: (T.t, ~destinationNode: audioNode, ~output: int=?, ~input: int=?) => audioNode =
    "connect"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/connect)
*/
  @send
  external connect2: (T.t, ~destinationParam: audioParam, ~output: int=?) => unit = "connect"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/disconnect)
*/
  @send
  external disconnect: T.t => unit = "disconnect"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/disconnect)
*/
  @send
  external disconnect2: (T.t, int) => unit = "disconnect"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/disconnect)
*/
  @send
  external disconnect3: (T.t, audioNode) => unit = "disconnect"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/disconnect)
*/
  @send
  external disconnect4: (T.t, ~destinationNode: audioNode, ~output: int) => unit = "disconnect"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/disconnect)
*/
  @send
  external disconnect5: (T.t, ~destinationNode: audioNode, ~output: int, ~input: int) => unit =
    "disconnect"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/disconnect)
*/
  @send
  external disconnect6: (T.t, audioParam) => unit = "disconnect"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/disconnect)
*/
  @send
  external disconnect7: (T.t, ~destinationParam: audioParam, ~output: int) => unit = "disconnect"
}
