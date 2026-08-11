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

type questionAnswer =
  | Answered(array<string>)
  | CustomText(string)
  | Skipped

type pendingQuestion = {
  questions: array<questionItem>,
  answers: Dict.t<questionAnswer>,
  currentStep: int,
  toolCallId: string,
  resolveOk: JSON.t => unit,
  resolveError: string => unit,
}
