@@warning("-30")

type mediaKeysRequirement = BaseEncryptedMediaExtensions.mediaKeysRequirement

type mediaKeySessionType = BaseEncryptedMediaExtensions.mediaKeySessionType

type mediaKeySessionClosedReason = BaseEncryptedMediaExtensions.mediaKeySessionClosedReason

type mediaKeyStatus = BaseEncryptedMediaExtensions.mediaKeyStatus

@editor.completeFrom(MediaKeySystemAccess)
type mediaKeySystemAccess = BaseEncryptedMediaExtensions.mediaKeySystemAccess

@editor.completeFrom(MediaKeys)
type mediaKeys = BaseEncryptedMediaExtensions.mediaKeys

@editor.completeFrom(MediaKeyStatusMap)
type mediaKeyStatusMap = BaseEncryptedMediaExtensions.mediaKeyStatusMap

@editor.completeFrom(MediaKeySession)
type mediaKeySession = BaseEncryptedMediaExtensions.mediaKeySession

type mediaKeySystemMediaCapability = BaseEncryptedMediaExtensions.mediaKeySystemMediaCapability

type mediaKeySystemConfiguration = BaseEncryptedMediaExtensions.mediaKeySystemConfiguration

type mediaKeysPolicy = {mutable minHdcpVersion?: string}
