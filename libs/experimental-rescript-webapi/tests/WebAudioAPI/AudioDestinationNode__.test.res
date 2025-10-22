open WebAudioAPI

let ctx = AudioContext.make()

let destinationNode = ctx.destination->AudioDestinationNode.asAudioNode
let context = AudioContext.asBaseAudioContext(ctx)

let osc = OscillatorNode.make(
  ~context,
  ~options={
    type_: Sine,
    frequency: 440.0,
  },
)
let gain = GainNode.make(
  ~context,
  ~options={
    gain: 0.3,
  },
)
let _ = gain->GainNode.connect(~destinationNode)
let _ =
  osc
  ->OscillatorNode.asAudioScheduledSourceNode
  ->AudioScheduledSourceNode.connect(~destinationNode=gain->GainNode.asAudioNode)

osc->OscillatorNode.start
