@react.component
let make = (
  ~selectedElement: option<Client__Types.SelectElement.t>,
  ~onClearSelection: option<unit => unit>,
) => {
  selectedElement->Option.mapOr(
    <div
      style={
        padding: "16px 20px",
        borderTop: "1px solid #374151",
        backgroundColor: "#111827",
        fontSize: "12px",
        color: "#6b7280",
        textAlign: "center",
      }
    >
      {React.string("No element selected")}
    </div>,
    selectedElement => {
      <div
        style={
          padding: "16px 20px",
          borderTop: "1px solid #374151",
          backgroundColor: "#111827",
          fontSize: "12px",
          color: "#f3f4f6",
        }
      >
        <div
          style={
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            marginBottom: "8px",
          }
        >
          <span style={color: "#10b981", fontWeight: "600", fontSize: "11px"}>
            {React.string(`✓ ELEMENT SELECTED`)}
          </span>

          {onClearSelection->Option.mapOr(React.null, onClearSelection => {
            <button
              onClick={_ => onClearSelection()}
              style={
                background: "none",
                border: "1px solid #6b7280",
                color: "#9ca3af",
                padding: "2px 6px",
                borderRadius: "3px",
                fontSize: "10px",
                cursor: "pointer",
                transition: "all 0.2s",
              }
            >
              {React.string(`Clear`)}
            </button>
          })}
        </div>

        <div style={marginBottom: "6px"}>
          <span style={color: "#9ca3af", fontSize: "11px"}> {React.string(`Selector: `)} </span>
          <code
            style={
              backgroundColor: "#374151",
              padding: "2px 4px",
              borderRadius: "3px",
              fontSize: "11px",
              fontFamily: "Monaco, Consolas, monospace",
              color: "#e5e7eb",
              wordBreak: "break-all",
            }
          >
            {React.string(selectedElement.selector)}
          </code>
        </div>

        {selectedElement.reactComponent->Option.mapOr(React.null, reactComponent => {
          <div>
            <div style={marginBottom: "4px"}>
              <span style={color: "#9ca3af", fontSize: "11px"}>
                {React.string(`React Component: `)}
              </span>
              <code
                style={
                  backgroundColor: "#1e3a8a",
                  color: "#93c5fd",
                  padding: "2px 4px",
                  borderRadius: "3px",
                  fontSize: "11px",
                  fontFamily: "Monaco, Consolas, monospace",
                  wordBreak: "break-all",
                  cursor: "pointer",
                  transition: "all 0.2s",
                }
                title={`Click to copy: ${reactComponent.name}`}
              >
                {React.string(
                  reactComponent.name
                  ->String.split(" ")
                  ->Array.toReversed
                  ->Array.slice(~start=0, ~end=3)
                  ->Array.toReversed
                  ->Array.join(" "),
                )}
              </code>
            </div>
            {<Client__SourceLocationDisplay
              sourceLocation={reactComponent.sourceLocation} compact={true}
            />}
          </div>
        })}
      </div>
    },
  )
}
