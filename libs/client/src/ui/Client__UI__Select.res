@@directive("'use client'")

open BaseUi.Types

@@live

@module("tailwind-merge")
external cn: (string, option<string>) => string = "twMerge"

module Size = {
  @unboxed
  type t =
    | @as("default") Default
    | @as("sm") Sm
}

let make = BaseUi.Select.Root.make

module Multiple = {
  @react.componentWithProps(BaseUi.Select.Root.Multiple.props)
  let make = (props: BaseUi.Select.Root.Multiple.props<'value>) =>
    <BaseUi.Select.Root.Multiple {...props} multiple=True />
}

module Group = {
  @react.componentWithProps(BaseUi.Types.BaseUIComponentProps.t)
  let make = (props: BaseUi.Types.BaseUIComponentProps.t) =>
    <BaseUi.Select.Group
      {...props}
      dataSlot={props.dataSlot->Option.getOr("select-group")}
      className={cn("scroll-my-1 p-1", props.className)}
    />
}

module Value = {
  @react.component
  let make = (~className=?, ~children=?, ~id=?, ~style=?, ~placeholder=?) =>
    <BaseUi.Select.Value
      ?id
      ?style
      ?placeholder
      ?children
      dataSlot="select-value"
      className={cn("flex flex-1 text-left", className)}
    />
}

module ScrollUpButton = {
  @react.component
  let make = (~className=?, ~id=?, ~style=?, ~onClick=?, ~onKeyDown=?) =>
    <BaseUi.Select.ScrollUpArrow
      ?id
      ?style
      ?onClick
      ?onKeyDown
      dataSlot="select-scroll-up-button"
      className={cn(
        "top-0 z-10 flex w-full cursor-default items-center justify-center bg-popover py-1 [&_svg:not([class*='size-'])]:size-4",
        className,
      )}
    >
      <Client__UI__Icons.ChevronUp />
    </BaseUi.Select.ScrollUpArrow>
}

module ScrollDownButton = {
  @react.component
  let make = (~className=?, ~id=?, ~style=?, ~onClick=?, ~onKeyDown=?) =>
    <BaseUi.Select.ScrollDownArrow
      ?id
      ?style
      ?onClick
      ?onKeyDown
      dataSlot="select-scroll-down-button"
      className={cn(
        "bottom-0 z-10 flex w-full cursor-default items-center justify-center bg-popover py-1 [&_svg:not([class*='size-'])]:size-4",
        className,
      )}
    >
      <Client__UI__Icons.ChevronDown />
    </BaseUi.Select.ScrollDownArrow>
}

module Trigger = {
  type triggerProps = {
    size?: Size.t,
    ...BaseUi.Types.BaseUIComponentProps.t,
  }

  let toBaseUiProps: triggerProps => BaseUi.Types.BaseUIComponentProps.t = %raw(`
    ({size, ...rest}) => rest
  `)

  @react.componentWithProps(triggerProps)
  let make = (props: triggerProps) => {
    let size = props.size->Option.getOr(Default)
    let baseUiProps = props->toBaseUiProps

    <BaseUi.Select.Trigger
      {...baseUiProps}
      dataSlot={props.dataSlot->Option.getOr("select-trigger")}
      dataSize={(size :> string)}
      className={cn(
        "flex w-fit items-center justify-between gap-1.5 rounded-lg border border-input bg-transparent py-2 pr-2 pl-2.5 text-sm whitespace-nowrap transition-colors outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 data-placeholder:text-muted-foreground data-[size=default]:h-8 data-[size=sm]:h-7 data-[size=sm]:rounded-[min(var(--radius-md),10px)] *:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex *:data-[slot=select-value]:items-center *:data-[slot=select-value]:gap-1.5 dark:bg-input/30 dark:hover:bg-input/50 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        props.className,
      )}
    >
      {props.children->Option.getOr(React.null)}
      <BaseUi.Select.Icon
        render={<Client__UI__Icons.ChevronDown
          className="pointer-events-none size-4 text-muted-foreground"
        />}
      />
    </BaseUi.Select.Trigger>
  }
}

module Content = {
  @react.component
  let make = (
    ~className=?,
    ~children=?,
    ~id=?,
    ~style=?,
    ~onClick=?,
    ~onKeyDown=?,
    ~side=Side.Bottom,
    ~sideOffset=4.,
    ~align=Align.Center,
    ~alignOffset=0.,
    ~dataAlignTrigger=true,
  ) => {
    let alignItemWithTrigger = dataAlignTrigger

    <BaseUi.Select.Portal>
      <BaseUi.Select.Positioner
        side
        sideOffset={Const(sideOffset)}
        align
        alignOffset={Const(alignOffset)}
        alignItemWithTrigger
        className="isolate z-50"
      >
        <BaseUi.Select.Popup
          ?id
          ?style
          ?onClick
          ?onKeyDown
          dataSlot="select-content"
          dataAlignTrigger={alignItemWithTrigger}
          className={cn(
            "cn-menu-target cn-menu-translucent relative isolate z-50 max-h-(--available-height) w-(--anchor-width) min-w-36 origin-(--transform-origin) overflow-x-hidden overflow-y-auto rounded-lg bg-popover text-popover-foreground shadow-md ring-1 ring-foreground/10 duration-100 data-[align-trigger=true]:animate-none data-[side=bottom]:slide-in-from-top-2 data-[side=inline-end]:slide-in-from-left-2 data-[side=inline-start]:slide-in-from-right-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95",
            className,
          )}
        >
          <ScrollUpButton />
          <BaseUi.Select.List ?children />
          <ScrollDownButton />
        </BaseUi.Select.Popup>
      </BaseUi.Select.Positioner>
    </BaseUi.Select.Portal>
  }
}

module Label = {
  @react.component
  let make = (~className=?, ~children=?, ~id=?, ~style=?, ~onClick=?, ~onKeyDown=?) =>
    <BaseUi.Select.GroupLabel
      ?id
      ?style
      ?onClick
      ?onKeyDown
      ?children
      dataSlot="select-label"
      className={cn("px-1.5 py-1 text-xs text-muted-foreground", className)}
    />
}

module Item = {
  @react.component
  let make = (
    ~className=?,
    ~children=?,
    ~id=?,
    ~style=?,
    ~onClick=?,
    ~onKeyDown=?,
    ~disabled=?,
    ~value=?,
    ~label=?,
  ) =>
    <BaseUi.Select.Item
      ?id
      ?style
      ?onClick
      ?onKeyDown
      ?disabled
      ?value
      ?label
      dataSlot="select-item"
      className={cn(
        "relative flex w-full cursor-default items-center gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 *:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2",
        className,
      )}
    >
      <BaseUi.Select.ItemText className="flex flex-1 shrink-0 gap-2 whitespace-nowrap" ?children />
      <BaseUi.Select.ItemIndicator
        render={<span
          className="pointer-events-none absolute right-2 flex size-4 items-center justify-center"
        />}
      >
        <Client__UI__Icons.Check className="pointer-events-none" />
      </BaseUi.Select.ItemIndicator>
    </BaseUi.Select.Item>
}

module Separator = {
  @react.component
  let make = (~className=?, ~id=?, ~style=?, ~onClick=?, ~onKeyDown=?) =>
    <BaseUi.Select.Separator
      ?id
      ?style
      ?onClick
      ?onKeyDown
      dataSlot="select-separator"
      className={cn("bg-border pointer-events-none -mx-1 my-1 h-px", className)}
    />
}
