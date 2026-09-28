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

/**
[See WebApiPermissions on MDN](https://developer.mozilla.org/docs/Web/API/Permissions)
*/
@editor.completeFrom(WebApiPermissions)
type permissions = private {}

/**
[See PermissionStatus on MDN](https://developer.mozilla.org/docs/Web/API/PermissionStatus)
*/
type permissionStatus = {
  ...EventTypes.eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PermissionStatus/state)
    */
  state: permissionState,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PermissionStatus/name)
    */
  name: string,
}

type permissionDescriptor = {mutable name: permissionName}
