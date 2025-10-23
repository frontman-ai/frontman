// Agent configuration type
// Extracted to break circular dependency: Agent__Tool needs config type without depending on Agent module

type t = {
  projectRoot: string,
  apiKey: string,
}
