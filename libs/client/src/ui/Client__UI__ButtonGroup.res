@@jsxConfig({version: 4, mode: "automatic", module_: "BaseUi.BaseUiJsxDOM"})

@@live

@module("tailwind-merge")
external cn: (string, string, option<string>) => string = "twMerge"

@react.component
let make = (~ariaLabel: string, ~children: React.element, ~className=?) =>
  <div
    role="group"
    ariaLabel
    dataSlot="button-group"
    className={cn(
      "flex w-fit items-stretch has-[>[data-slot=button-group]]:gap-2 [&>*]:focus-visible:relative [&>*]:focus-visible:z-10 [&>input]:flex-1",
      "[&>*:not(:first-child)]:rounded-l-none [&>*:not(:first-child)]:border-l-0 [&>*:not(:last-child)]:rounded-r-none",
      className,
    )}
  >
    {children}
  </div>
