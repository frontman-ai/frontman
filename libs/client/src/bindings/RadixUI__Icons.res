// Radix UI React Icons bindings
// Each icon is exported as a separate React component
// Usage: <RadixUI__Icons.PaperPlaneIcon width={20} height={20} color="white" />

module PaperPlaneIcon = {
  @module("@radix-ui/react-icons") @react.component 
  external make: (
    ~className: string=?,
    ~style: {..}=?,
    ~width: string=?,
    ~height: string=?,
    ~color: string=?,
  ) => React.element = "PaperPlaneIcon"
}


module ReloadIcon = {
 @module("@radix-ui/react-icons") @react.component 
  external make: (
    ~className: string=?,
    ~style: {..}=?,
    ~width: string=?,
    ~height: string=?,
    ~color: string=?,
  ) => React.element = "ReloadIcon"
}


module TargetIcon = {
 @module("@radix-ui/react-icons") @react.component 
  external make: (
    ~className: string=?,
    ~style: {..}=?,
    ~width: string=?,
    ~height: string=?,
    ~color: string=?,
  ) => React.element = "TargetIcon"
}
