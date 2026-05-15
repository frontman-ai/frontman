@@live

@module("tailwind-merge")
external cn: (string, option<string>) => string = "twMerge"

@unboxed
type dataIcon =
  | @as("inline-start") InlineStart
  | @as("inline-end") InlineEnd

@react.component
let make = (~className=?, ~dataIcon: option<dataIcon>=?, ~dataSlot=?) => {
  <Client__UI__Icons.Loader2
    dataIcon=?{(dataIcon :> option<string>)}
    ?dataSlot
    role="status"
    ariaLabel="Loading"
    className={cn("size-4 animate-spin", className)}
  />
}
