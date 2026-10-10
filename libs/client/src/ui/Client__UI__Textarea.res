@@jsxConfig({version: 4, mode: "automatic", module_: "BaseUi.BaseUiJsxDOM"})

@@live

@module("tailwind-merge")
external cn: (string, option<string>) => string = "twMerge"

@react.componentWithProps(BaseUi.Types.DomProps.t)
let make = (props: BaseUi.Types.DomProps.t) =>
  <textarea
    {...props}
    dataSlot={props.dataSlot->Option.getOr("textarea")}
    className={cn(
      "border-input dark:bg-input/30 placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 flex w-full min-w-0 rounded-lg border bg-transparent px-3 py-2 text-base transition-colors outline-none focus-visible:ring-3 disabled:cursor-not-allowed disabled:opacity-50 md:text-sm",
      props.className,
    )}
  />
