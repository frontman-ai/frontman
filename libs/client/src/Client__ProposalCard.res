@react.component
let make = (
  ~proposalState: Client__Types.proposalState,
  ~onAccept=?,
  ~onReject=?,
) => {
  <div
    style={
      backgroundColor: "#111827",
      borderRadius: "6px",
      padding: "12px",
      marginTop: "8px",
      border: "1px solid #374151",
    }>
    <div
      style={
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        marginBottom: "8px",
      }>
      <div>
        <div
          style={
            fontSize: "12px",
            fontWeight: "600",
            color: "#f3f4f6",
            fontFamily: "Monaco, Consolas, monospace",
          }>
          {React.string(
            (proposalState.proposal.changeType == Client__Types.Create ? "Create" : "Modify") ++ 
            " " ++ proposalState.proposal.filePath
          )}
        </div>
        <div
          style={
            fontSize: "11px",
            color: "#9ca3af",
            marginTop: "2px",
          }>
          {React.string(proposalState.proposal.description)}
        </div>
      </div>
      
      {proposalState.status == Client__Types.Accepted ? 
        <span
          style={
            fontSize: "11px",
            color: "#86efac",
            fontWeight: "500",
          }>
          {React.string("Applied")}
        </span>
        : proposalState.status == Client__Types.Rejected ?
          <span
            style={
              fontSize: "11px",
              color: "#9ca3af",
              fontWeight: "500",
            }>
            {React.string("Rejected")}
          </span>
          : React.null
      }
    </div>

    <div style={fontSize: "10px", color: "#6b7280", marginBottom: "8px"}>
      {React.string(
        proposalState.proposal.currentExists ?
          (proposalState.proposal.currentLines->Int.toString) ++ " → " ++ 
          (proposalState.proposal.proposedLines->Int.toString) ++ " lines (" ++
          (proposalState.proposal.lineDiff >= 0 ? "+" : "") ++ 
          (proposalState.proposal.lineDiff->Int.toString) ++ ")"
          : "New file, " ++ (proposalState.proposal.proposedLines->Int.toString) ++ " lines"
      )}
    </div>

    <Client__ProposalDiff diff={proposalState.proposal.diff} />

    {proposalState.status == Client__Types.Error && proposalState.errorMessage != None ?
      <div
        style={
          marginTop: "8px",
          padding: "8px",
          backgroundColor: "#7f1d1d",
          color: "#fca5a5",
          borderRadius: "4px",
          fontSize: "11px",
        }>
        {React.string("! " ++ (proposalState.errorMessage->Option.getOr("Unknown error")))}
      </div>
      : React.null
    }

    {proposalState.status == Client__Types.Pending ?
      <div
        style={
          display: "flex",
          gap: "8px",
          marginTop: "12px",
          justifyContent: "flex-end",
        }>
        <button
          onClick={_ => onReject->Option.forEach(fn => fn())}
          style={
            background: "none",
            border: "1px solid #6b7280",
            color: "#9ca3af",
            padding: "4px 12px",
            borderRadius: "4px",
            fontSize: "11px",
            cursor: "pointer",
            transition: "all 0.2s",
          }>
          {React.string("Reject")}
        </button>
        <button
          onClick={_ => onAccept->Option.forEach(fn => fn())}
          style={
            backgroundColor: "#10b981",
            border: "none",
            color: "white",
            padding: "4px 12px",
            borderRadius: "4px",
            fontSize: "11px",
            fontWeight: "500",
            cursor: "pointer",
            transition: "all 0.2s",
          }>
          {React.string("Accept")}
        </button>
      </div>
      : React.null
    }
  </div>
}
