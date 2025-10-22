@@warning("-30")

open EventAPI

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

/**
This EncryptedMediaExtensions API interface provides access to a Key System for decryption and/or a content protection provider. You can request an instance of this object using the Navigator.requestMediaKeySystemAccess method.
[See MediaKeySystemAccess on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySystemAccess)
*/
@editor.completeFrom(MediaKeySystemAccess)
type mediaKeySystemAccess = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySystemAccess/keySystem)
    */
  keySystem: string,
}

/**
This EncryptedMediaExtensions API interface the represents a set of keys that an associated HTMLMediaElement can use for decryption of media data during playback.
[See MediaKeys on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeys)
*/
@editor.completeFrom(MediaKeys)
type mediaKeys = {}

/**
This EncryptedMediaExtensions API interface is a read-only map of media key statuses by key IDs.
[See MediaKeyStatusMap on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeyStatusMap)
*/
@editor.completeFrom(MediaKeyStatusMap)
type mediaKeyStatusMap = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeyStatusMap/size)
    */
  size: int,
}

/**
This EncryptedMediaExtensions API interface represents a context for message exchange with a content decryption module (CDM).
[See MediaKeySession on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession)
*/
@editor.completeFrom(MediaKeySession)
type mediaKeySession = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/sessionId)
    */
  sessionId: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/expiration)
    */
  expiration: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/closed)
    */
  closed: promise<mediaKeySessionClosedReason>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/keyStatuses)
    */
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

type mediaKeysPolicy = {mutable minHdcpVersion?: string}
