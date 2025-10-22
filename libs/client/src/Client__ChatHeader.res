@react.component
let make = (
  ~title=?,
  ~subtitle=?,
  ~learnMoreText=?,
  ~onLearnMoreClick: option<unit => unit>,
) => {
  let title = title->Option.getOr("New Chat")
  let subtitle = subtitle->Option.getOr("Using your project's AGENTS.md.")
  let learnMoreText = learnMoreText->Option.getOr("Learn more")

  <div
    style={
      padding: "20px",
      borderBottom: "1px solid #374151",
      backgroundColor: "#111827",
    }>
    <h2
      style={
        margin: "0",
        fontSize: "18px",
        fontWeight: "600",
        color: "#f9fafb",
      }>
      {React.string(title)}
    </h2>
    <p
      style={
        margin: "8px 0 0 0",
        fontSize: "14px",
        color: "#9ca3af",
        lineHeight: "1.4",
      }>
      {React.string(subtitle)}
      {React.string(" ")}
      <span
        style={
          color: "#60a5fa",
          cursor: "pointer",
        }
        onClick={_ => onLearnMoreClick->Option.forEach(fn => fn())}>
        {React.string(learnMoreText)}
      </span>
    </p>
  </div>
}
