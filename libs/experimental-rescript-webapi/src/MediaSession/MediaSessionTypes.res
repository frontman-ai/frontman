@@warning("-30")

type mediaSessionPlaybackState =
  | @as("none") None
  | @as("paused") Paused
  | @as("playing") Playing

type mediaSessionAction =
  | @as("nexttrack") Nexttrack
  | @as("pause") Pause
  | @as("play") Play
  | @as("previoustrack") Previoustrack
  | @as("seekbackward") Seekbackward
  | @as("seekforward") Seekforward
  | @as("seekto") Seekto
  | @as("skipad") Skipad
  | @as("stop") Stop

type mediaImage = {
  mutable src: string,
  mutable sizes?: string,
  @as("type") mutable type_?: string,
}

@editor.completeFrom(MediaMetadata)
type mediaMetadata = {
  mutable title: string,
  mutable artist: string,
  mutable album: string,
  mutable artwork: array<mediaImage>,
}

@editor.completeFrom(WebApiMediaSession)
type mediaSession = {
  mutable metadata: Null.t<mediaMetadata>,
  mutable playbackState: mediaSessionPlaybackState,
}

type mediaMetadataInit = {
  mutable title?: string,
  mutable artist?: string,
  mutable album?: string,
  mutable artwork?: array<mediaImage>,
}

type mediaSessionActionDetails = {
  mutable action: mediaSessionAction,
  mutable seekOffset?: float,
  mutable seekTime?: float,
  mutable fastSeek?: bool,
}

type mediaPositionState = {
  mutable duration?: float,
  mutable playbackRate?: float,
  mutable position?: float,
}

type mediaSessionActionHandler = mediaSessionActionDetails => unit
