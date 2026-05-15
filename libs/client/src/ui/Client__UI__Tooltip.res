@@directive("'use client'")

open BaseUi.Types

@@live

@module("tailwind-merge")
external cn: (string, option<string>) => string = "twMerge"

@react.component
let make = (
  ~className=?,
  ~children=?,
  ~id=?,
  ~open_=?,
  ~defaultOpen=?,
  ~onOpenChange=?,
  ~delay=0.,
  ~closeDelay=?,
  ~style=?,
) =>
  <BaseUi.Tooltip.Root
    ?className
    ?children
    ?id
    ?open_
    ?defaultOpen
    ?onOpenChange
    delay
    ?closeDelay
    ?style
    dataSlot="tooltip"
  />

module Provider = {
  @react.component
  let make = (~children=?, ~delay=0., ~closeDelay=?, ~timeout=?) =>
    <BaseUi.Tooltip.Provider ?children ?closeDelay ?timeout delay />
}

module Trigger = {
  @react.component
  let make = (
    ~className=?,
    ~children=?,
    ~id=?,
    ~disabled=?,
    ~onClick=?,
    ~onKeyDown=?,
    ~ariaLabel=?,
    ~render=?,
    ~style=?,
  ) =>
    <BaseUi.Tooltip.Trigger
      ?className
      ?children
      ?id
      ?disabled
      ?onClick
      ?onKeyDown
      ?ariaLabel
      ?render
      ?style
      dataSlot="tooltip-trigger"
    />
}

type contentProps = {
  className?: string,
  children: React.element,
  id?: string,
  dir?: BaseUi.Types.TextDirection.t,
  style?: ReactDOM.style,
  onClick?: ReactEvent.Mouse.t => unit,
  onKeyDown?: ReactEvent.Keyboard.t => unit,
  align?: Align.t,
  alignOffset?: float,
  side?: Side.t,
  sideOffset?: float,
  hidden?: bool,
}

module Content = {
  @react.component(: contentProps)
  let make = (
    ~className=?,
    ~children,
    ~id=?,
    ~dir=?,
    ~style=?,
    ~onClick=?,
    ~onKeyDown=?,
    ~align=Align.Center,
    ~alignOffset=0.,
    ~side=Side.Top,
    ~sideOffset=4.,
    ~hidden=?,
  ) =>
    <BaseUi.Tooltip.Portal>
      <BaseUi.Tooltip.Positioner
        align
        alignOffset={Const(alignOffset)}
        side
        sideOffset={Const(sideOffset)}
        className="isolate z-50"
      >
        <BaseUi.Tooltip.Popup
          ?id
          dir=?{(dir :> option<string>)}
          ?style
          ?onClick
          ?onKeyDown
          dataSlot="tooltip-content"
          className={cn(
            "data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-[state=delayed-open]:animate-in data-[state=delayed-open]:fade-in-0 data-[state=delayed-open]:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2 bg-foreground text-background z-50 w-fit max-w-xs origin-(--transform-origin) rounded-md px-3 py-1.5 text-xs",
            className,
          )}
          ?hidden
        >
          {children}
          <BaseUi.Tooltip.Arrow
            className="bg-foreground fill-foreground z-50 size-2.5 translate-y-[calc(-50%_-_2px)] rotate-45 rounded-[2px] data-[side=bottom]:top-1 data-[side=inline-end]:top-1/2! data-[side=inline-end]:-left-1 data-[side=inline-end]:-translate-y-1/2 data-[side=inline-start]:top-1/2! data-[side=inline-start]:-right-1 data-[side=inline-start]:-translate-y-1/2 data-[side=left]:top-1/2! data-[side=left]:-right-1 data-[side=left]:-translate-y-1/2 data-[side=right]:top-1/2! data-[side=right]:-left-1 data-[side=right]:-translate-y-1/2 data-[side=top]:-bottom-2.5"
          />
        </BaseUi.Tooltip.Popup>
      </BaseUi.Tooltip.Positioner>
    </BaseUi.Tooltip.Portal>
}
