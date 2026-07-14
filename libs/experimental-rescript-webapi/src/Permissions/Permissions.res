/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Permissions/query)
*/
@send
external query: (
  PermissionsTypes.permissions,
  PermissionsTypes.permissionDescriptor,
) => promise<PermissionsTypes.permissionStatus> = "query"

module Types = PermissionsTypes
