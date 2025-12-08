// Component for displaying the current selected Figma node state
module Icons = Bindings__RadixUI__Icons
module FigmaNode = Client__State__Types.FigmaNode

// Extract name from DSL string
// DSL format: "name(v:volume) #id:" on the first line
let getNodeNameFromDSL = (dsl: string): string => {
  // Get first line
  let firstLine = dsl->String.split("\n")->Array.get(0)->Option.getOr("")
  // Extract name before the first "(" or " #" or ":"
  let name = firstLine
    ->String.split("(")
    ->Array.get(0)
    ->Option.getOr(firstLine)
    ->String.split(" #")
    ->Array.get(0)
    ->Option.getOr(firstLine)
    ->String.trim
  
  if name == "" {
    "Figma Node"
  } else {
    name
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
  | FigmaNode.SelectedNode({nodeDSL, image, _}) =>
    let nodeName = getNodeNameFromDSL(nodeDSL)
    <div
      className="flex items-center gap-2 p-3 bg-blue-50 border-t border-blue-200 text-sm text-blue-900"
    >
      <Icons.FigmaIcon style={{"width": "16px", "height": "16px"}} />
      {image->Option.mapOr(React.null, imageUrl =>
        <img
          src={imageUrl}
          alt="Figma node preview"
          className="w-8 h-8 object-contain rounded border border-blue-200 flex-shrink-0"
        />
      )}
      <span className="font-medium flex-grow min-w-0 truncate">
        {React.string(`Figma Node Selected: ${nodeName}`)}
      </span>
      <button
        className="ml-auto text-blue-600 hover:text-blue-800 flex-shrink-0"
        onClick={_ => Client__State.Actions.clearFigmaNode()}
      >
        <Icons.Cross2Icon style={{"width": "14px", "height": "14px"}} />
      </button>
    </div>
  | FigmaNode.NoSelection => React.null
  }
}
