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

type questionWaiter = {
  resolveOk: JSON.t => unit,
  resolveError: string => unit,
}

type pendingQuestion = {
  questions: array<questionItem>,
  answers: Dict.t<questionAnswer>,
  currentStep: int,
  toolCallId: string,
  waiters: array<questionWaiter>,
}
