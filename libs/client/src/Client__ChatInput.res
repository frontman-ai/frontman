@react.component
let make = (
  ~message,
  ~onMessageChange,
  ~onSendMessage,
  ~placeholder=?,
  ~modelName=?,
  ~trialInfo=?,
  ~onSettingsClick: option<unit => unit>,
  ~onElementSelected: option<Client__Types.SelectElement.t => unit>,
  ~selectedElement: option<Client__Types.SelectElement.t>,
  ~onClearSelection: option<unit => unit>,
) => {
  let placeholder = placeholder->Option.getOr("Message the agent")
  let modelName = modelName->Option.getOr("Claude Sonnet 4")
  let trialInfo = trialInfo->Option.getOr("Trial mode: 0 / 20 messages available")

  let handleKeyPress = (e) => {
    if (e->ReactEvent.Keyboard.key == "Enter" && !(e->ReactEvent.Keyboard.shiftKey)) {
      ReactEvent.Keyboard.preventDefault(e)
      onSendMessage()
    }
  }

  let handleChange = (e) => {
    let target = e->ReactEvent.Form.target
    onMessageChange(target["value"])
  }

  <div
    style={
      padding: "20px",
      borderTop: "1px solid #374151",
    }>
    <div
      style={
        position: "relative",
        display: "flex",
        alignItems: "flex-end",
        gap: "8px",
      }>
      <div style={flex: "1", position: "relative"}>
        <textarea
          value={message}
          onChange={handleChange}
          onKeyPress={handleKeyPress}
          placeholder={placeholder}
          style={
            width: "100%",
            minHeight: "44px",
            maxHeight: "120px",
            padding: "12px 72px 12px 12px",
            backgroundColor: "#374151",
            border: "1px solid #4b5563",
            borderRadius: "8px",
            color: "white",
            fontSize: "14px",
            resize: "none",
            outline: "none",
            boxSizing: "border-box",
            fontFamily: "inherit",
          }
          rows={1}
        />
        <div
          style={
            position: "absolute",
            right: "8px",
            bottom: "8px",
            display: "flex",
            gap: "4px",
          }>
          {onElementSelected->Option.mapOr(
            React.null,
            onElementSelected => {
              <Client__SelectElementButton
                onElementSelected={onElementSelected}
                selectedElement=?{selectedElement}
                onClearSelection=?{onClearSelection}
                disabled=?{Some(false)}
              />
            }
          )}
          <button
            onClick={_ => onSendMessage()}
            disabled={!(message->String.trim->String.length > 0)}
            style={
              width: "28px",
              height: "28px",
              backgroundColor: message->String.trim->String.length > 0 ? "#3b82f6" : "#6b7280",
              border: "none",
              borderRadius: "4px",
              cursor: message->String.trim->String.length > 0 ? "pointer" : "not-allowed",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              transition: "background-color 0.2s",
            }>
            <RadixUI__Icons.PaperPlaneIcon width="14" height="14" color="white" />
          </button>
        </div>
      </div>
    </div>

    <div
      style={
        marginTop: "12px",
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        fontSize: "12px",
        color: "#6b7280",
      }>
      <span> {React.string(modelName)} </span>
      <div style={display: "flex", alignItems: "center", gap: "16px"}>
        <span> {React.string(trialInfo)} </span>
        {onSettingsClick->Option.mapOr(
          React.null,
          onSettingsClick => {
            <button
              onClick={_ => onSettingsClick()}
              style={
                background: "none",
                border: "none",
                color: "#6b7280",
                cursor: "pointer",
                fontSize: "12px",
                textDecoration: "underline",
              }>
              {React.string("Settings")}
            </button>
          }
        )}
      </div>
    </div>
  </div>
}