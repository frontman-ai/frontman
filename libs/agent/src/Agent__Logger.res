let output = (entry: AskTheLlmLogger.Logger.Types.logEntry): unit => {
  Console.log(entry.message)
}

module Log = AskTheLlmLogger.Logger.Make({
  let output = output
  let minLevel = AskTheLlmLogger.Logger.Types.Debug
  let enabled = true
})
