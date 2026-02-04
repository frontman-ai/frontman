let main = () => {
  let runtimeId = %raw(`chrome.runtime.id`)
  Console.log2("Browser runtime ID:", runtimeId)
}
