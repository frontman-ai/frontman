// Component for displaying the current selected Figma node state
module Icons = Bindings__RadixUI__Icons
module FigmaNode = Client__State__Types.FigmaNode

// Extract name from either optimized format or legacy format
let getNodeName = (json: JSON.t): string => {
  switch json->JSON.Decode.object {
  | Some(obj) =>
    // Try optimized format first: { $: { N: "name" } }
    switch obj->Dict.get("$") {
    | Some(root) =>
      switch root->JSON.Decode.object {
      | Some(rootObj) =>
        switch rootObj->Dict.get("N") {
        | Some(name) => name->JSON.Decode.string->Option.getOr("Figma Node")
        | None => "Figma Node"
        }
      | None => "Figma Node"
      }
    // Try legacy format: { name: "name" }
    | None =>
      switch obj->Dict.get("name") {
      | Some(name) => name->JSON.Decode.string->Option.getOr("Figma Node")
      | None => "Figma Node"
      }
    }
  | None => "Figma Node"
  }
}

@react.component
let make = () => {
  let figmaNode = Client__State.useSelector(Client__State.Selectors.figmaNode)

  switch figmaNode {
  | FigmaNode.WaitingForSelection =>
    <div
      className="flex items-center gap-2 p-3 bg-purple-50 border-t border-purple-200 text-sm text-purple-900"
    >
      <Icons.FigmaIcon style={{"width": "16px", "height": "16px"}} />
      <span className="font-medium"> {React.string("Waiting for Figma node selection...")} </span>
      <button
        className="ml-auto text-purple-600 hover:text-purple-800"
        onClick={_ => Client__State.Actions.clearFigmaNodeWaiting()}
      >
        <Icons.Cross2Icon style={{"width": "14px", "height": "14px"}} />
      </button>
    </div>
  | FigmaNode.SelectedNode(node) =>
    let nodeName = getNodeName(node)
    <div
      className="flex items-center gap-2 p-3 bg-blue-50 border-t border-blue-200 text-sm text-blue-900"
    >
      <Icons.FigmaIcon style={{"width": "16px", "height": "16px"}} />
      <span className="font-medium"> {React.string(`Figma Node Selected: ${nodeName}`)} </span>
      <button
        className="ml-auto text-blue-600 hover:text-blue-800"
        onClick={_ => Client__State.Actions.clearFigmaNode()}
      >
        <Icons.Cross2Icon style={{"width": "14px", "height": "14px"}} />
      </button>
    </div>
  | FigmaNode.NoSelection => React.null
  }
}
