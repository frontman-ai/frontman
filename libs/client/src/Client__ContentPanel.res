@react.component
let make = (
  ~iframeUrl: string,
  ~iframeId: string="main-content-iframe",
  ~title: string="Original Page Content",
  ~onReload: option<unit => unit>=?,
) => {
  <div
    style={
      flex: "1",
      display: "flex",
      flexDirection: "column",
    }>
    <Client__ContentToolbar
      url={iframeUrl}
      onReload={onReload}
      iframeId={iframeId}
    />
    
    <iframe
      id={iframeId}
      src={iframeUrl}
      style={
        flex: "1",
        border: "none",
        width: "100%",
      }
      title={title}
    />
  </div>
}
