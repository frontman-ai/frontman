@react.component
let make = (
  ~selectedElement: option<Client__Types.SelectElement.t>=?,
  ~onClear: option<unit => unit>=?,
) => {
  selectedElement->Option.mapOr(React.null, selectedElement => {
    <div
      style={
        position: "fixed",
        bottom: "20px",
        left: "50%",
        transform: "translateX(-50%)",
        zIndex: "1000000",
        backgroundColor: "#1f2937",
        color: "white",
        padding: "12px 16px",
        borderRadius: "8px",
        boxShadow: "0 4px 12px rgba(0, 0, 0, 0.15)",
        border: "1px solid #10b981",
        display: "flex",
        alignItems: "center",
        gap: "12px",
        fontSize: "13px",
        fontWeight: "500",
        maxWidth: "600px",
        animation: "slideUpFade 0.3s ease-out",
      }
    >
      <div
        style={
          width: "8px",
          height: "8px",
          backgroundColor: "#10b981",
          borderRadius: "50%",
        }
      />

      <div style={flex: "1", display: "flex", flexDirection: "column", gap: "4px"}>
        <div style={display: "flex", alignItems: "center", gap: "8px"}>
          <span style={color: "#10b981", fontWeight: "600"}> {React.string(`✓ Selected:`)} </span>
          <code
            style={
              backgroundColor: "#374151",
              padding: "2px 6px",
              borderRadius: "4px",
              fontSize: "12px",
              fontFamily: "Monaco, Consolas, monospace",
              maxWidth: "300px",
              overflow: "hidden",
              textOverflow: "ellipsis",
              whiteSpace: "nowrap",
              display: "inline-block",
              cursor: "pointer",
              transition: "all 0.2s",
            }
            title={`Click to copy: ${selectedElement.selector}`}
          >
            {React.string(selectedElement.selector)}
          </code>
        </div>

        {selectedElement.reactComponent->Option.mapOr(React.null, reactComponent => {
          <div style={display: "flex", flexDirection: "column", gap: "4px"}>
            <div style={display: "flex", alignItems: "center", gap: "8px"}>
              <span style={color: "#3b82f6", fontSize: "12px"}> {React.string(`React:`)} </span>
              <code
                style={
                  backgroundColor: "#1e3a8a",
                  color: "#93c5fd",
                  padding: "2px 6px",
                  borderRadius: "4px",
                  fontSize: "11px",
                  fontFamily: "Monaco, Consolas, monospace",
                  maxWidth: "400px",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                  display: "inline-block",
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
              sourceLocation={reactComponent.sourceLocation} compact={false}
            />}
          </div>
        })}
      </div>

      {onClear->Option.mapOr(React.null, onClear => {
        <button
          onClick={_ => onClear()}
          style={
            background: "none",
            border: "1px solid #6b7280",
            color: "#9ca3af",
            padding: "4px 8px",
            borderRadius: "4px",
            fontSize: "11px",
            cursor: "pointer",
            transition: "all 0.2s",
          }
        >
          {React.string(`Clear`)}
        </button>
      })}

      <style>
        {React.string("@keyframes slideUpFade {
              from { 
                opacity: 0; 
                transform: translateX(-50%) translateY(20px); 
              }
              to { 
                opacity: 1; 
                transform: translateX(-50%) translateY(0); 
              }
            }")}
      </style>
    </div>
  })
}
