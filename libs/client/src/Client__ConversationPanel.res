module Tabs = Client__UI__Tabs

@react.component
let make = (~onConfigureProvider: unit => unit) => {
  let supportsChanges =
    Client__RuntimeConfig.read().framework->Client__RuntimeConfig.supportsFileChanges
  let taskClientId = Client__State.useSelector(Client__State.Selectors.currentTaskClientId)
  let snapshot = Client__State.useSelector(Client__State.Selectors.completedFileChanges)
  let (activeTab, setActiveTab) = React.useState(() => "chat")

  React.useEffect1(() => {
    setActiveTab(_ => "chat")
    None
  }, [taskClientId])

  switch supportsChanges {
  | false => <Client__Chatbox onConfigureProvider />
  | true =>
    <Tabs
      value=activeTab
      onValueChange={(value, _eventDetails) => setActiveTab(_ => value)}
      className="h-full min-h-0 gap-0 bg-[#130d20]"
    >
      <div className="shrink-0 border-b border-white/8 px-3 pt-2">
        <Tabs.List variant=Tabs.Variant.Line className="h-8">
          <Tabs.Trigger value="chat"> {React.string("Chat")} </Tabs.Trigger>
          <Tabs.Trigger value="changes">
            <span> {React.string("Changes")} </span>
            {switch Array.length(snapshot.files) {
            | 0 => React.null
            | count =>
              <span className="rounded-full bg-violet-500/20 px-1.5 text-[10px] text-violet-200">
                {React.int(count)}
              </span>
            }}
          </Tabs.Trigger>
        </Tabs.List>
      </div>
      <Tabs.Content value="chat" className="min-h-0 overflow-hidden">
        <Client__Chatbox onConfigureProvider />
      </Tabs.Content>
      <Tabs.Content value="changes" className="min-h-0 overflow-hidden">
        <Client__ChangesView />
      </Tabs.Content>
    </Tabs>
  }
}
