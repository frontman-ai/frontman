@react.component
let make = (~diff) => {
  <div
    style={
      backgroundColor: "#0f172a",
      border: "1px solid #374151",
      borderRadius: "4px",
      padding: "8px",
      fontSize: "11px",
      fontFamily: "Monaco, Consolas, monospace",
      overflow: "auto",
      maxHeight: "200px",
    }>
    <pre style={margin: "0", whiteSpace: "pre-wrap"}>
      {React.string(diff)}
    </pre>
  </div>
}
