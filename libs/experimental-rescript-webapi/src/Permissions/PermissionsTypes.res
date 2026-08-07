@@warning("-30")

type permissionName =
  | @as("geolocation") Geolocation
  | @as("midi") Midi
  | @as("notifications") Notifications
  | @as("persistent-storage") PersistentStorage
  | @as("push") Push
  | @as("screen-wake-lock") ScreenWakeLock
  | @as("storage-access") StorageAccess

type permissionState =
  | @as("denied") Denied
  | @as("granted") Granted
  | @as("prompt") Prompt

@editor.completeFrom(WebApiPermissions)
type permissions = private {}

type permissionStatus = {
  ...EventTypes.eventTarget,
  state: permissionState,
  name: string,
}

type permissionDescriptor = {mutable name: permissionName}
