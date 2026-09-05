@schema
type response = {
  installedVersion: string,
  latestVersion: string,
  autoUpdateEnabled: bool,
}

type t = NotChecked | Unsupported | Available({autoUpdateEnabled: bool})
