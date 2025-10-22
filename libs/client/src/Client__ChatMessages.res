module AgentTaskMessage = AskTheLlmAgent.Agent__Task__Message
module AgentId = AskTheLlmAgent.Agent__Id
@react.component
let make = (
  ~title: option<string>=?,
  ~subtitle: option<string>=?,
  ~messages: option<array<AgentTaskMessage.t>>,
  ~onAcceptProposal: option<(string, int) => unit>,
  ~onRejectProposal: option<(string, int) => unit>,
) => {
  let title = title->Option.getOr("What do you want to build?")
  let subtitle = subtitle->Option.getOr("Type a message below to begin")
  let hasMessages = messages->Option.mapOr(false, msgs => msgs->Array.length > 0)

  if (hasMessages) {
    let messagesList = messages->Option.getOr([])
    
    <div
      style={
        flex: "1",
        padding: "20px",
        overflowY: "auto",
        display: "flex",
        flexDirection: "column",
        gap: "16px",
      }>
      {messagesList->Array.mapWithIndex((message, idx) => {
        // Determine what to display
        let displayContent = message.parts->Array.map(part => {
          switch part {
          | AgentTaskMessage.Part.Text(textPart) => textPart.text
          | _ => ""
          }
        })->Array.join("\n")
        
        // If still sending and no content, show status message
        // let displayContent = 
        //   if (message.status == Some(Client__Types.Sending) && 
        //       message.content->String.length == 0 && 
        //       message.statusMessage != None) {
        //     message.statusMessage->Option.getOr("")
        //   } else {
        //     message.content
        //   }

        <div
          key={message.messageId->AgentId.toString}
          style={
            padding: "12px",
            borderRadius: "8px",
            backgroundColor: message.role == User ? "#374151" : "#1f2937",
            color: "#f3f4f6",
            fontSize: "14px",
            lineHeight: "1.5",
            opacity: message.role == User ? "0.7" : "1",
            border: message.role == System ? "1px solid #ef4444" : "none",
          }>
          <div style={display: "flex", alignItems: "center", gap: "8px"}>
            {message.role == User ?
              <div
                style={
                  width: "12px",
                  height: "12px",
                  border: "2px solid #9ca3af",
                  borderTop: "2px solid #60a5fa",
                  borderRadius: "50%",
                  animation: "spin 1s linear infinite",
                }
              />
              : React.null
            }
            {message.role == System ?
              <span style={color: "#ef4444", fontSize: "12px"}>
                {React.string(`⚠`)}
              </span>
              : React.null
            }
            <div style={flex: "1"}>
              {React.string(displayContent)}
            </div>
          </div>
        </div>
      })->React.array}
    </div>
  } else {
    <div
      style={
        flex: "1",
        padding: "20px",
        overflowY: "auto",
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        textAlign: "center",
      }>
      <div style={maxWidth: "280px"}>
        <h3
          style={
            margin: "0 0 12px 0",
            fontSize: "16px",
            fontWeight: "500",
            color: "#f3f4f6",
          }>
          {React.string(title)}
        </h3>
        <p
          style={
            margin: "0",
            fontSize: "14px",
            color: "#9ca3af",
            lineHeight: "1.5",
          }>
          {React.string(subtitle)}
        </p>
      </div>
    </div>
  }
}