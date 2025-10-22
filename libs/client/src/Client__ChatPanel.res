module AgentTaskMessage = AskTheLlmAgent.Agent__Task__Message

@react.component
let make = (
  ~message: string,
  ~onMessageChange: string => unit,
  ~onSendMessage: unit => unit,
  ~messages: option<array<AgentTaskMessage.t>>=?,
  ~onLearnMoreClick: option<unit => unit>=?,
  ~onSettingsClick: option<unit => unit>=?,
  ~onElementSelected: option<Client__Types.SelectElement.t => unit>=?,
  ~selectedElement: option<Client__Types.SelectElement.t>,
  ~onClearSelection: option<unit => unit>=?,
  ~onAcceptProposal: option<(string, int) => unit>=?,
  ~onRejectProposal: option<(string, int) => unit>=?,
) => {
  <div
    data="widget-ui"
    style={
      width: "400px",
      minWidth: "300px",
      maxWidth: "500px",
      backgroundColor: "#1f2937",
      color: "white",
      display: "flex",
      flexDirection: "column",
      borderRight: "1px solid #374151",
    }>
    <Client__ChatHeader 
      onLearnMoreClick={onLearnMoreClick}
    />
    
    <Client__ChatMessages
      messages={messages}
      onAcceptProposal={onAcceptProposal}
      onRejectProposal={onRejectProposal}
    />
    
    <Client__ChatSelectedElement
      selectedElement={selectedElement}
      onClearSelection={onClearSelection}
    />
    
    <Client__ChatTextLength
      messages={messages}
    />
    
    <Client__ChatInput
      message={message}
      onMessageChange={onMessageChange}
      onSendMessage={onSendMessage}
      onSettingsClick={onSettingsClick}
      onElementSelected={onElementSelected}
      selectedElement={selectedElement}
      onClearSelection={onClearSelection}
    />
  </div>
}