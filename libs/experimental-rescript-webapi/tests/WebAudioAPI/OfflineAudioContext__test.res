let offlineAudioContextOptions: WebAudioTypes.offlineAudioContextOptions = Obj.magic()

let _fromOptions = OfflineAudioContext.fromOptions(offlineAudioContextOptions)

let _fromChannelCountLengthAndSampleRate = OfflineAudioContext.fromChannelCountLengthAndSampleRate(
  ~numberOfChannels=2,
  ~length=1024,
  ~sampleRate=44_100.,
)
