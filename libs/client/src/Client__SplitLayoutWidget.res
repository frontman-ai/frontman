open WebAPI.Global
module AgentTaskMessage = AskTheLlmAgent.Agent__Task__Message
module AgentTaskPart = AgentTaskMessage.Part
module Types = Client__Types

@react.component
let make = () => {
  let (message, setMessage) = React.useState(_ => "")
  let (iframeUrl, setIframeUrl) = React.useState(_ => "")
  let (selectedElement, setSelectedElement) = React.useState(_ => None)
  let (messages, setMessages) = React.useState(_ => [])
  let (isLoading, setIsLoading) = React.useState(_ => false)

  React.useEffect(() => {
    let currentUrl = window->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)
    let originUrl = `${currentUrl.protocol}//${currentUrl.host}`
    setIframeUrl(_ => originUrl)
    None
  }, (setIframeUrl))

  let handleSSEMessage = React.useCallback((msg: AgentTaskMessage.t) => {
    Console.log2("[SSE] Message received:", msg)
  }, ())

  Client__Hooks__UseSSE.useSSE(handleSSEMessage)

  let handleSendMessage = React.useCallback(() => {
    // Console.log2("[SSE] Sending message:", msg)

    setMessages((prev: array<AgentTaskMessage.t>)=> {
        let userMessage = AgentTaskMessage.make(~role=User, ~parts=[AgentTaskPart.text(~text=message)])
        prev->Array.concat([userMessage])
    })

  }, (message))

  let handleElementSelected = React.useCallback((element: Types.SelectElement.t) => {
    Console.log2("Element selected:", element)
    setSelectedElement(_ => Some(element))
  }, ())

  let handleClearSelection = React.useCallback(() => {
    setSelectedElement(_ => None)
  }, ())

  let handleAcceptProposal = React.useCallback((messageId: string, toolIndex: int) => {
    // let message = messages->Array.find(m => m.messageId == messageId)
    Console.log(`Accepting proposal for message: ${messageId} ${toolIndex->Int.toString}`)
  }, ())

  let handleRejectProposal = React.useCallback((messageId: string, toolIndex: int) => {
    Console.log(`Rejecting proposal for message: ${messageId} ${toolIndex->Int.toString}`)
  }, ())

  let handleLearnMoreClick = React.useCallback(() => {
    Console.log("Learn more clicked")
  }, ())

  let handleSettingsClick = React.useCallback(() => {
    Console.log("Settings clicked")
  }, ())


    <div
        style={{
            display: "flex",
            height: "100vh",
            width: "100vw",
            fontFamily:
                `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,
            position: "fixed",
            top: "0",
            left: "0",
            zIndex: "999999",
            backgroundColor: "#fff",
        }}
    >
        <Client__ChatPanel
            message={message}
            onMessageChange={message => setMessage(_ => message)}
            onSendMessage={handleSendMessage}
            messages={messages}
            onLearnMoreClick={handleLearnMoreClick}
            onSettingsClick={handleSettingsClick}
            onElementSelected={handleElementSelected}
            selectedElement={selectedElement}
            onClearSelection={handleClearSelection}
            onAcceptProposal={handleAcceptProposal}
            onRejectProposal={handleRejectProposal}
        />

        <Client__ContentPanel iframeUrl={iframeUrl} />
    </div>
}
