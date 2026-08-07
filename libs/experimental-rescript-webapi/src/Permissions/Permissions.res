@send
external query: (
  PermissionsTypes.permissions,
  PermissionsTypes.permissionDescriptor,
) => promise<PermissionsTypes.permissionStatus> = "query"

module Types = PermissionsTypes
