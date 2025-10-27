@react.component
let make = (~sourceLocation: option<Client__Types.sourceLocation>, ~compact: bool=false) => {
  switch sourceLocation {
  | None => 
    <div
      style={
        display: "flex",
        alignItems: "center",
        gap: "6px",
        color: "#6b7280",
        fontSize: compact ? "11px" : "12px",
        fontStyle: "italic",
      }>
      <RadixUI__Icons.ReloadIcon
        width="12"
        height="12"
        style={"animation": "spin 1s linear infinite"}
      />
      <span> {React.string("Resolving source location...")} </span>
    </div>
    
  | Some({file, line}) =>
    <div
      style={
        display: "flex",
        alignItems: "flex-start",
        gap: "4px",
        color: "#10b981",
        fontSize: compact ? "11px" : "12px",
        fontFamily: "monospace",
        cursor: "pointer",
      }
      onClick={_ => {
        let text = file ++ ":" ++ Int.toString(line)
        // Note: navigator.clipboard.writeText would need to be implemented via external
        Js.log("Copy to clipboard: " ++ text)
      }}
      title={file ++ ":" ++ Int.toString(line) ++ " (click to copy)"}>
      <span style={color: "#6b7280", flexShrink: "0"}>
        {React.string("📍")}
      </span>
      <span
        style={
          wordBreak: "break-all",
        }>
        {React.string(file ++ ":" ++ Int.toString(line))}
      </span>
    </div>
  }
}
