// Radix UI React Icons bindings
// Each icon is exported as a separate React component
// Usage: <RadixUI__Icons.PaperPlaneIcon style={"width": "20px", "height": "20px"} />
// Note: width/height must be passed via style prop, not as direct props

module PaperPlaneIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "PaperPlaneIcon"
}

module ReloadIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "ReloadIcon"
}

module Crosshair1Icon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "Crosshair1Icon"
}

module CopyIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "CopyIcon"
}

module GlobeIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "GlobeIcon"
}

module PlusIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "PlusIcon"
}

module ArrowLeftIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "ArrowLeftIcon"
}

module ArrowRightIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "ArrowRightIcon"
}

module OpenInNewWindowIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "OpenInNewWindowIcon"
}

module EnterFullScreenIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "EnterFullScreenIcon"
}

module Cross2Icon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "Cross2Icon"
}

module GearIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "GearIcon"
}

module CubeIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "CubeIcon"
}

module ChevronUpIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "ChevronUpIcon"
}

module ChevronDownIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (~className: string=?, ~style: {..}=?) => React.element = "ChevronDownIcon"
}

module FigmaIcon = {
  @react.component
  let make = (~className: option<string>=?, ~style: option<{..}>=?) => {
    let emptyStyle: JsxDOM.style = %raw("{}")
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="480"
      height="720"
      fill="none"
      viewBox="0 0 480 720"
      className={className->Option.getOr("")}
      style={style->Option.mapOr(emptyStyle, s => s->Obj.magic)}
    >
      <path
        fill="#24CB71"
        d="M0 600c0-66.274 53.726-120 120-120h120v120c0 66.274-53.726 120-120 120S0 666.274 0 600"
      />
      <path fill="#FF7237" d="M240 0v240h120c66.274 0 120-53.726 120-120S426.274 0 360 0z" />
      <circle cx="359" cy="360" r="120" fill="#00B6FF" />
      <path
        fill="#FF3737" d="M0 120c0 66.274 53.726 120 120 120h120V0H120C53.726 0 0 53.726 0 120"
      />
      <path
        fill="#874FFF" d="M0 360c0 66.274 53.726 120 120 120h120V240H120C53.726 240 0 293.726 0 360"
      />
    </svg>
  }
}
