@@warning("-30")

type mediaDeviceKind =
  | @as("audioinput") Audioinput
  | @as("audiooutput") Audiooutput
  | @as("videoinput") Videoinput

type mediaStreamTrackState =
  | @as("ended") Ended
  | @as("live") Live

@editor.completeFrom(MediaDevices)
type mediaDevices = private {
  ...EventTypes.eventTarget,
}

@editor.completeFrom(MediaDeviceInfo)
type mediaDeviceInfo = private {
  deviceId: string,
  kind: mediaDeviceKind,
  label: string,
  groupId: string,
}

@editor.completeFrom(MediaStream)
type mediaStream = private {
  ...EventTypes.eventTarget,
  id: string,
  active: bool,
}

@editor.completeFrom(MediaStreamTrack)
type mediaStreamTrack = {
  ...EventTypes.eventTarget,
  kind: string,
  id: string,
  label: string,
  mutable enabled: bool,
  muted: bool,
  readyState: mediaStreamTrackState,
  mutable contentHint: string,
}

type mediaTrackSupportedConstraints = {
  mutable width?: bool,
  mutable height?: bool,
  mutable aspectRatio?: bool,
  mutable frameRate?: bool,
  mutable facingMode?: bool,
  mutable sampleRate?: bool,
  mutable sampleSize?: bool,
  mutable echoCancellation?: bool,
  mutable autoGainControl?: bool,
  mutable noiseSuppression?: bool,
  mutable channelCount?: bool,
  mutable deviceId?: bool,
  mutable groupId?: bool,
  mutable backgroundBlur?: bool,
  mutable displaySurface?: bool,
}

type mediaStreamConstraints = {
  mutable video?: unknown,
  mutable audio?: unknown,
  mutable preferCurrentTab?: bool,
  mutable peerIdentity?: string,
}

type displayMediaStreamOptions = {
  mutable video?: unknown,
  mutable audio?: unknown,
}

type uLongRange = {
  mutable max?: int,
  mutable min?: int,
}

type doubleRange = {
  mutable max?: float,
  mutable min?: float,
}

type mediaTrackCapabilities = {
  mutable width?: uLongRange,
  mutable height?: uLongRange,
  mutable aspectRatio?: doubleRange,
  mutable frameRate?: doubleRange,
  mutable facingMode?: array<string>,
  mutable sampleRate?: uLongRange,
  mutable sampleSize?: uLongRange,
  mutable echoCancellation?: array<bool>,
  mutable autoGainControl?: array<bool>,
  mutable noiseSuppression?: array<bool>,
  mutable channelCount?: uLongRange,
  mutable deviceId?: string,
  mutable groupId?: string,
  mutable backgroundBlur?: array<bool>,
  mutable displaySurface?: string,
}

type mediaTrackConstraintSet = {
  mutable width?: int,
  mutable height?: int,
  mutable aspectRatio?: float,
  mutable frameRate?: float,
  mutable facingMode?: string,
  mutable sampleRate?: int,
  mutable sampleSize?: int,
  mutable echoCancellation?: bool,
  mutable autoGainControl?: bool,
  mutable noiseSuppression?: bool,
  mutable channelCount?: int,
  mutable deviceId?: string,
  mutable groupId?: string,
  mutable backgroundBlur?: bool,
  mutable displaySurface?: string,
}

type mediaTrackConstraints = {
  ...mediaTrackConstraintSet,
  mutable advanced?: array<mediaTrackConstraintSet>,
}

type mediaTrackSettings = {
  mutable width?: int,
  mutable height?: int,
  mutable aspectRatio?: float,
  mutable frameRate?: float,
  mutable facingMode?: string,
  mutable sampleRate?: int,
  mutable sampleSize?: int,
  mutable echoCancellation?: bool,
  mutable autoGainControl?: bool,
  mutable noiseSuppression?: bool,
  mutable channelCount?: int,
  mutable deviceId?: string,
  mutable groupId?: string,
  mutable backgroundBlur?: bool,
  mutable displaySurface?: string,
}
