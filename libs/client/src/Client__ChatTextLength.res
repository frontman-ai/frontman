module AgentTaskMessage = AskTheLlmAgent.Agent__Task__Message
@react.component
let make = (~messages: option<array<AgentTaskMessage.t>>) => {
  let messages = messages->Option.getOr([])

  let totalCharacters =
    messages->Array.reduce(0, (total, message) =>
      AgentTaskMessage.getContent(message)->String.length + total
    )

  let totalWords = messages->Array.reduce(0, (total, message) => {
    AgentTaskMessage.getContent(message)
    ->String.trim
    ->String.split(" ")
    ->Array.filter(word => word->String.length > 0)
    ->Array.length + total
  })

  let messageCount = messages->Array.length

  let conversationStatus = if totalCharacters > 10000 {
    `🔥 Large conversation`
  } else if totalCharacters > 5000 {
    `📚 Medium conversation`
  } else if totalCharacters > 1000 {
    `💬 Active chat`
  } else {
    `✨ Getting started`
  }

  <div
    style={
      padding: "16px 20px",
      borderTop: "1px solid #374151",
      backgroundColor: "#111827",
      fontSize: "12px",
      color: "#9ca3af",
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
    }
  >
    <div style={display: "flex", gap: "16px"}>
      <span>
        <strong style={color: "#d1d5db"}> {React.string(totalCharacters->Int.toString)} </strong>
        {React.string(` characters`)}
      </span>
      <span>
        <strong style={color: "#d1d5db"}> {React.string(totalWords->Int.toString)} </strong>
        {React.string(` words`)}
      </span>
      <span>
        <strong style={color: "#d1d5db"}> {React.string(messageCount->Int.toString)} </strong>
        {React.string(` messages`)}
      </span>
    </div>

    {totalCharacters > 0
      ? <div style={fontSize: "11px", color: "#6b7280"}> {React.string(conversationStatus)} </div>
      : React.null}
  </div>
}
