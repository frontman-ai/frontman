// Shared domain types used across protocol boundaries

S.enableJson()

// A model selection — identifies a provider + model pair.
// Used in MCP tool result metadata and prompt metadata.
@schema
type modelSelection = {
  provider: string,
  value: string,
}

// Accessors
let provider = (m: modelSelection) => m.provider
let value = (m: modelSelection) => m.value

// Parse an ACP sessionConfigValueId ("provider:modelName") into a modelSelection.
// Uses indexOf instead of split to handle model names containing colons
// (e.g. "openrouter:anthropic/claude-haiku-4.5").
let modelSelectionFromValueId = (valueId: string): option<modelSelection> =>
  switch valueId->String.indexOf(":") {
  | -1 => None
  | idx =>
    Some({
      provider: valueId->String.slice(~start=0, ~end=idx),
      value: valueId->String.slice(~start=idx + 1, ~end=String.length(valueId)),
    })
  }
