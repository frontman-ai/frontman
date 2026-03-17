// Shared domain types used across protocol boundaries

S.enableJson()

// A model selection — identifies a provider + model pair.
// Used in client state, MCP tool result metadata, and prompt metadata.
@schema
type modelSelection = {
  provider: string,
  value: string,
}
