@@jsxConfig({version: 4, mode: "automatic", module_: "BaseUi.BaseUiJsxDOM"})

@@live

@module("tailwind-merge")
external cn: (string, string, option<string>) => string = "twMerge"

@unboxed
type dataIcon =
  | @as("inline-start") InlineStart
  | @as("inline-end") InlineEnd

module Variant = {
  @unboxed
  type t =
    | @as("default") Default
    | @as("secondary") Secondary
    | @as("destructive") Destructive
    | @as("outline") Outline
    | @as("ghost") Ghost
    | @as("link") Link
    | @as("blue") Blue
    | @as("emerald") Emerald
    | @as("amber") Amber
    | @as("red") Red
    | @as("zinc") Zinc
}

let badgeVariantClass = (~variant: Variant.t) =>
  switch variant {
  | Default => "bg-primary text-primary-foreground [a]:hover:bg-primary/80"
  | Secondary => "bg-secondary text-secondary-foreground [a]:hover:bg-secondary/80"
  | Destructive => "bg-destructive/10 text-destructive focus-visible:ring-destructive/20 dark:bg-destructive/20 dark:focus-visible:ring-destructive/40 [a]:hover:bg-destructive/20"
  | Outline => "border-border text-foreground [a]:hover:bg-muted [a]:hover:text-muted-foreground"
  | Ghost => "hover:bg-muted hover:text-muted-foreground dark:hover:bg-muted/50"
  | Link => "text-primary underline-offset-4 hover:underline"
  | Blue => "bg-blue-500/20 text-blue-200"
  | Emerald => "bg-emerald-500/20 text-emerald-200"
  | Amber => "bg-amber-500/20 text-amber-200"
  | Red => "bg-red-500/20 text-red-200"
  | Zinc => "bg-zinc-700/50 text-zinc-400"
  }

let base = "group/badge inline-flex h-5 w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-4xl border border-transparent px-2 py-0.5 text-xs font-medium whitespace-nowrap transition-all focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&>svg]:pointer-events-none [&>svg]:size-3!"

@react.component
let make = (
  ~className=?,
  ~children=?,
  ~variant=Variant.Default,
  ~id=?,
  ~onClick=?,
  ~onKeyDown=?,
  ~style=?,
  ~render=?,
  ~dataIcon: option<dataIcon>=?,
) => {
  let props: BaseUi.Types.BaseUIComponentProps.t = {
    ?id,
    ?style,
    ?onClick,
    ?onKeyDown,
    ?children,
    dataIcon: ?{(dataIcon :> option<string>)},
    dataSlot: "badge",
    dataVariant: (variant :> string),
    className: cn(base, badgeVariantClass(~variant), className),
  }
  BaseUi.Render.use({defaultTagName: "span", props, ?render})
}
