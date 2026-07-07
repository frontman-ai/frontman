@@directive("'use client'")

open BaseUi.Types

@@live

@module("tailwind-merge")
external cn: (string, option<string>) => string = "twMerge"

@react.componentWithProps(BaseUIComponentProps.t)
let make = (props: BaseUIComponentProps.t) =>
  <BaseUi.Separator
    {...props}
    dataSlot={props.dataSlot->Option.getOr("separator")}
    orientation={props.orientation->Option.getOr(Horizontal)}
    className={cn(
      "bg-border shrink-0 data-horizontal:h-px data-horizontal:w-full data-vertical:w-px data-vertical:self-stretch",
      props.className,
    )}
  />
