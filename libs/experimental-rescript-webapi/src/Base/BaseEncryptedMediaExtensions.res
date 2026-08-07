type mediaKeysRequirement =
  | @as("not-allowed") NotAllowed
  | @as("optional") Optional
  | @as("required") Required

type mediaKeySessionType =
  | @as("persistent-license") PersistentLicense
  | @as("temporary") Temporary

type mediaKeySessionClosedReason =
  | @as("closed-by-application") ClosedByApplication
  | @as("hardware-context-reset") HardwareContextReset
  | @as("internal-error") InternalError
  | @as("release-acknowledged") ReleaseAcknowledged
  | @as("resource-evicted") ResourceEvicted

type mediaKeyStatus =
  | @as("expired") Expired
  | @as("internal-error") InternalError
  | @as("output-downscaled") OutputDownscaled
  | @as("output-restricted") OutputRestricted
  | @as("released") Released
  | @as("status-pending") StatusPending
  | @as("usable") Usable
  | @as("usable-in-future") UsableInFuture

@editor.completeFrom(MediaKeySystemAccess)
type mediaKeySystemAccess = private {
  keySystem: string,
}

@editor.completeFrom(BaseEncryptedMediaExtensions.MediaKeys)
type mediaKeys = private {}

@editor.completeFrom(BaseEncryptedMediaExtensions.MediaKeyStatusMap)
type mediaKeyStatusMap = private {
  size: int,
}

@editor.completeFrom(BaseEncryptedMediaExtensions.MediaKeySession)
type mediaKeySession = private {
  ...BaseEvent.eventTarget,
  sessionId: string,
  expiration: float,
  closed: promise<mediaKeySessionClosedReason>,
  keyStatuses: mediaKeyStatusMap,
}

type mediaKeySystemMediaCapability = {
  mutable contentType?: string,
  mutable encryptionScheme?: Null.t<string>,
  mutable robustness?: string,
}

type mediaKeySystemConfiguration = {
  mutable label?: string,
  mutable initDataTypes?: array<string>,
  mutable audioCapabilities?: array<mediaKeySystemMediaCapability>,
  mutable videoCapabilities?: array<mediaKeySystemMediaCapability>,
  mutable distinctiveIdentifier?: mediaKeysRequirement,
  mutable persistentState?: mediaKeysRequirement,
  mutable sessionTypes?: array<string>,
}
