%%raw("import './index.css'")

open WebAPI.Global

document->WebAPI.Document.addEventListener(Custom("DOMContentLoaded"), (_event) => {
    let rootElement = document->WebAPI.Document.querySelector("#root")
    switch rootElement->Null.toOption {
    | Some(rootElement) =>
        let root = ReactDOM.Client.createRoot(rootElement->WebAPI.Element.asRescriptElement)
        root->ReactDOM.Client.Root.render(
            <React.StrictMode>
                <Client__SplitLayoutWidget />
            </React.StrictMode>,
        )
    | None => ()
    }
})