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
  external make: (
    ~className: string=?,
    ~style: {..}=?,
  ) => React.element = "CopyIcon"
}

module GlobeIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (
    ~className: string=?,
    ~style: {..}=?,
  ) => React.element = "GlobeIcon"
}

module PlusIcon = {
  @module("@radix-ui/react-icons") @react.component
  external make: (
    ~className: string=?,
    ~style: {..}=?,
  ) => React.element = "PlusIcon"
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
