@@directive("'use client'")

@@live

@module("tailwind-merge")
external cn: (string, string, string, option<string>) => string = "twMerge"

module Variant = {
  @unboxed
  type t =
    | @as("default") Default
    | @as("secondary") Secondary
    | @as("destructive") Destructive
    | @as("outline") Outline
    | @as("ghost") Ghost
    | @as("link") Link
}

module Size = {
  @unboxed
  type t =
    | @as("default") Default
    | @as("xs") Xs
    | @as("sm") Sm
    | @as("lg") Lg
    | @as("icon") Icon
    | @as("icon-xs") IconXs
    | @as("icon-sm") IconSm
    | @as("icon-lg") IconLg
}

let buttonVariantClass = (~variant: Variant.t) =>
  switch variant {
  | Default => "bg-primary text-primary-foreground [a]:hover:bg-primary/80"
  | Outline => "border-border bg-background hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50"
  | Secondary => "bg-secondary text-secondary-foreground hover:bg-secondary/80 aria-expanded:bg-secondary aria-expanded:text-secondary-foreground"
  | Ghost => "hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground dark:hover:bg-muted/50"
  | Destructive => "bg-destructive/10 text-destructive hover:bg-destructive/20 focus-visible:border-destructive/40 focus-visible:ring-destructive/20 dark:bg-destructive/20 dark:hover:bg-destructive/30 dark:focus-visible:ring-destructive/40"
  | Link => "text-primary underline-offset-4 hover:underline"
  }

let buttonSizeClass = (~size: Size.t) =>
  switch size {
  | Xs => "h-6 gap-1 rounded-[min(var(--radius-md),10px)] px-2 text-xs in-data-[slot=button-group]:rounded-lg has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3"
  | Sm => "h-7 gap-1 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] in-data-[slot=button-group]:rounded-lg has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3.5"
  | Lg => "h-9 gap-1.5 rounded-lg px-2.5 has-data-[icon=inline-end]:pr-3 has-data-[icon=inline-start]:pl-3"
  | Icon => "size-8 rounded-lg"
  | IconXs => "size-6 rounded-[min(var(--radius-md),10px)] in-data-[slot=button-group]:rounded-lg [&_svg:not([class*='size-'])]:size-3"
  | IconSm => "size-7 rounded-[min(var(--radius-md),12px)] in-data-[slot=button-group]:rounded-lg"
  | IconLg => "size-9 rounded-lg"
  | Default => "h-8 gap-1.5 rounded-lg px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2"
  }

let baseClass = "group/button inline-flex shrink-0 items-center justify-center rounded-lg border border-transparent bg-clip-padding text-sm font-medium whitespace-nowrap transition-all outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 active:translate-y-px disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"

let buttonVariants = (~variant=Variant.Default, ~size=Size.Default, ~className=?) =>
  cn(baseClass, buttonVariantClass(~variant), buttonSizeClass(~size), className)

type props = {
  variant?: Variant.t,
  size?: Size.t,
  ...BaseUi.Types.BaseUIComponentProps.t,
  ...BaseUi.Types.NativeButtonProps.t,
  focusableWhenDisabled?: bool,
}

let toBaseUiProps: props => BaseUi.Button.props = %raw(`
  ({variant, size, ...rest}) => rest
`)

@react.componentWithProps(props)
let make = (props: props) => {
  let variant = props.variant->Option.getOr(Default)
  let size = props.size->Option.getOr(Default)
  let className = props.className
  let baseUiProps = props->toBaseUiProps
  <BaseUi.Button
    {...baseUiProps}
    dataSlot={props.dataSlot->Option.getOr("button")}
    className={buttonVariants(~variant, ~size, ~className?)}
  />
}
