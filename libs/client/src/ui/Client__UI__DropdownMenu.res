@@directive("'use client'")

@@jsxConfig({version: 4, mode: "automatic", module_: "BaseUi.BaseUiJsxDOM"})

open BaseUi.Types

@@live

@module("tailwind-merge")
external cn: (string, option<string>) => string = "twMerge"

module Variant = {
  @unboxed
  type t =
    | @as("default") Default
    | @as("destructive") Destructive
}

@react.component
let make = (
  ~children=?,
  ~open_=?,
  ~defaultOpen=?,
  ~onOpenChange=?,
  ~onOpenChangeComplete=?,
  ~modal=?,
  ~dataSlot="dropdown-menu",
) =>
  <BaseUi.Menu.Root
    ?children ?open_ ?defaultOpen ?onOpenChange ?onOpenChangeComplete ?modal dataSlot
  />

module Portal = {
  @react.component
  let make = (~children=?, ~container=?) =>
    <BaseUi.Menu.Portal ?children ?container dataSlot="dropdown-menu-portal" />
}

module Group = {
  @react.componentWithProps(BaseUi.Types.BaseUIComponentProps.t)
  let make = (props: BaseUi.Types.BaseUIComponentProps.t) =>
    <BaseUi.Menu.Group {...props} dataSlot="dropdown-menu-group" />
}

module Trigger = {
  @react.componentWithProps(BaseUi.Menu.Trigger.props)
  let make = (props: BaseUi.Menu.Trigger.props) =>
    <BaseUi.Menu.Trigger {...props} dataSlot="dropdown-menu-trigger" />
}

module Content = {
  type contentProps = {
    className?: string,
    children?: React.element,
    id?: string,
    dir?: string,
    dataLang?: string,
    style?: ReactDOM.style,
    onClick?: JsxEvent.Mouse.t => unit,
    onKeyDown?: JsxEvent.Keyboard.t => unit,
    align?: Align.t,
    alignOffset?: float,
    side?: Side.t,
    sideOffset?: float,
    dataSlot?: string,
  }

  @react.component(: contentProps)
  let make = (
    ~align=Align.Start,
    ~alignOffset=0.,
    ~side=Side.Bottom,
    ~sideOffset=4.,
    ~className=?,
    ~dataSlot="dropdown-menu-content",
    ~children=?,
    ~id=?,
    ~dir=?,
    ~dataLang=?,
    ~style=?,
    ~onClick=?,
    ~onKeyDown=?,
  ) =>
    <BaseUi.Menu.Portal>
      <BaseUi.Menu.Positioner
        className="isolate z-50 outline-none"
        align
        alignOffset={Const(alignOffset)}
        side
        sideOffset={Const(sideOffset)}
      >
        <BaseUi.Menu.Popup
          ?id
          ?dir
          ?dataLang
          ?style
          ?onClick
          ?onKeyDown
          ?children
          dataSlot
          className={cn(
            "data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2 cn-menu-target z-50 max-h-(--available-height) w-(--anchor-width) min-w-32 origin-(--transform-origin) overflow-x-hidden overflow-y-auto rounded-lg p-1 shadow-md ring-1 duration-100 outline-none data-closed:overflow-hidden",
            className,
          )}
        />
      </BaseUi.Menu.Positioner>
    </BaseUi.Menu.Portal>
}

module Label = {
  @react.component
  let make = (
    ~className=?,
    ~children=?,
    ~id=?,
    ~style=?,
    ~onClick=?,
    ~onKeyDown=?,
    ~inset=?,
    ~dataSlot="dropdown-menu-label",
  ) =>
    <BaseUi.Menu.GroupLabel
      ?id
      ?style
      ?onClick
      ?onKeyDown
      dataInset=?inset
      ?children
      dataSlot
      className={cn(
        "text-muted-foreground px-1.5 py-1 text-xs font-medium data-inset:pl-7",
        className,
      )}
    />
}

module Item = {
  @react.component
  let make = (
    ~className=?,
    ~children=?,
    ~inset=?,
    ~variant=Variant.Default,
    ~id=?,
    ~style=?,
    ~onClick=?,
    ~onKeyDown=?,
    ~disabled=?,
    ~closeOnClick=?,
    ~dataSlot="dropdown-menu-item",
  ) =>
    <BaseUi.Menu.Item
      ?id
      ?style
      ?onClick
      ?onKeyDown
      ?disabled
      ?closeOnClick
      dataInset=?inset
      ?children
      dataSlot
      dataVariant={(variant :> string)}
      className={cn(
        "focus:bg-accent focus:text-accent-foreground data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 dark:data-[variant=destructive]:focus:bg-destructive/20 data-[variant=destructive]:focus:text-destructive data-[variant=destructive]:*:[svg]:text-destructive not-data-[variant=destructive]:focus:**:text-accent-foreground group/dropdown-menu-item relative flex cursor-default items-center gap-1.5 rounded-md px-1.5 py-1 text-sm outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 data-inset:pl-7 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className,
      )}
    />
}

module Separator = {
  @react.component
  let make = (~className=?, ~children=?, ~id=?, ~style=?, ~dataSlot="dropdown-menu-separator") =>
    <BaseUi.Menu.Separator
      ?id ?style ?children dataSlot className={cn("bg-border -mx-1 my-1 h-px", className)}
    />
}
