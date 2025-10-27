@val @scope(("process", "env")) @return(nullable) external nodeEnv: option<string> = "NODE_ENV"

let askTheLlmClientJsDevelopmentUrl = "http://localhost:5173/src/Main.res.mjs"
let askTheLlmClientJsProductionUrl = "https://ask-the-llm.vercel.app/ask-the-llm.es.js"

let askTheLlmClientJsUrl = isDev => {
  switch isDev {
  | true => askTheLlmClientJsDevelopmentUrl
  | false => askTheLlmClientJsProductionUrl
  }
}
