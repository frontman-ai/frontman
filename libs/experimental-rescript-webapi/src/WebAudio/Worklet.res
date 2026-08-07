@send
external addModule: (
  WebAudioTypes.worklet,
  ~moduleURL: string,
  ~options: WebAudioTypes.workletOptions=?,
) => promise<unit> = "addModule"
