// Shared types for the question tool UI.
// Used by the task reducer, question drawer, and question tool block components.

S.enableJson()

@schema
type questionOption = {
  label: string,
  description: string,
}

@schema
type questionItem = {
  question: string,
  header: string,
  options: array<questionOption>,
  multiple: option<bool>,
}

// Per-question answer state (used by the reducer/UI)
type questionAnswer =
  | Answered(array<string>)
  | CustomText(string)
  | Skipped

type pendingQuestion = {
  questions: array<questionItem>,
  answers: Dict.t<questionAnswer>, // keyed by string index ("0", "1", ...)
  currentStep: int,
  toolCallId: string, // for display/tracking only
  resolveOk: JSON.t => unit, // resolve the tool promise with Ok(output)
  resolveError: string => unit, // resolve the tool promise with Error(msg)
}
