@react.component
let make = (
  ~url: string,
  ~onReload: option<unit => unit>,
  ~iframeId: string="main-content-iframe",
) => {
  let handleReload = () => {
    ()
  }

  <div
    style={
      height: "50px",
      backgroundColor: "#f8fafc",
      borderBottom: "1px solid #e2e8f0",
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "0 16px",
    }>
    <div
      style={
        fontSize: "14px",
        color: "#64748b",
        display: "flex",
        alignItems: "center",
        gap: "8px",
      }>
      <RadixUI__Icons.ReloadIcon width="16" height="16" />
      {React.string(url)}
    </div>

    <button
      onClick={_ => handleReload()}
      style={
        padding: "6px 12px",
        backgroundColor: "#3b82f6",
        color: "white",
        border: "none",
        borderRadius: "4px",
        fontSize: "12px",
        cursor: "pointer",
      }>
      {React.string("Reload")}
    </button>
  </div>
}
