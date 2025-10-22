@react.component
let make = (
  ~isSelecting: bool,
  ~isIframeMode: bool=false,
  ~onCancel: option<unit => unit>=?,
) => {
  let (isVisible, setIsVisible) = React.useState(() => false)

  React.useEffect1(
    () => {
      if (isSelecting) {
        setIsVisible(_ => true)
        None
      } else {
        let timer = Js.Global.setTimeout(
          () => setIsVisible(_ => false),
          300
        )
        Some(() => Js.Global.clearTimeout(timer))
      }
    },
    [isSelecting]
  )

  if (!isVisible) {
    React.null
  } else {
    <div
      style={
        position: "fixed",
        top: "20px",
        left: "50%",
        transform: "translateX(-50%)",
        zIndex: "1000000",
        backgroundColor: isSelecting ? "#1f2937" : "#059669",
        color: "white",
        padding: "12px 20px",
        borderRadius: "8px",
        boxShadow: "0 4px 12px rgba(0, 0, 0, 0.15)",
        display: "flex",
        alignItems: "center",
        gap: "12px",
        fontSize: "14px",
        fontWeight: "500",
        transition: "all 0.3s ease",
        opacity: isSelecting ? "1" : "0",
        border: isSelecting ? "2px solid #3b82f6" : "2px solid #10b981",
      }>
      {if (isSelecting) {
        <>
          <div
            style={
              width: "8px",
              height: "8px",
              backgroundColor: "#3b82f6",
              borderRadius: "50%",
              animation: "pulse 2s infinite",
            }
          />
          <span>
            {React.string(
              if (isIframeMode) {
                `🎯 Click any element inside the iframe to select it`
              } else {
                `🎯 Click any element to select it`
              }
            )}
          </span>
          <span style={color: "#9ca3af", fontSize: "12px"}>
            {React.string(`Press ESC to cancel`)}
          </span>
          {onCancel->Option.mapOr(
            React.null,
            onCancel => {
              <button
                onClick={_ => onCancel()}
                style={
                  background: "none",
                  border: "1px solid #6b7280",
                  color: "#9ca3af",
                  padding: "4px 8px",
                  borderRadius: "4px",
                  fontSize: "12px",
                  cursor: "pointer",
                  transition: "all 0.2s",
                }
>
                {React.string(`Cancel`)}
              </button>
            },
          )}
        </>
      } else {
        <>
          <div
            style={
              width: "8px",
              height: "8px",
              backgroundColor: "#10b981",
              borderRadius: "50%",
            }
          />
          <span> {React.string(`✅ Element selected successfully!`)} </span>
        </>
      }}
      
      <style>
        {React.string(
          "@keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
          }"
        )}
      </style>
    </div>
  }
}
