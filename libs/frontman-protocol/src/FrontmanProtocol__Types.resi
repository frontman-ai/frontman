// Opaque model selection — can only be constructed via modelSelectionFromValueId
// or deserialized via modelSelectionSchema.
type modelSelection

let modelSelectionSchema: S.t<modelSelection>
let modelSelectionFromValueId: string => option<modelSelection>
let provider: modelSelection => string
let value: modelSelection => string
