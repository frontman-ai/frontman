// Agent configuration type
// Extracted to break circular dependency: Agent__Tool needs config type without depending on Agent module

type t = {
  projectRoot: string,
  apiKey: string,
  // Optional model for testing - if None, will create default OpenAI model
  model?: Agent__Bindings__Vercel.languageModel,
}
