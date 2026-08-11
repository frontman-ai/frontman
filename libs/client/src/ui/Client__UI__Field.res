@@jsxConfig({version: 4, mode: "automatic", module_: "BaseUi.BaseUiJsxDOM"})

@@directive("'use client'")

@@live

@module("tailwind-merge")
external cn: (string, option<string>) => string = "twMerge"

module Orientation = {
  @unboxed
  type t =
    | @as("horizontal") Horizontal
    | @as("vertical") Vertical
    | @as("responsive") Responsive
}

module Variant = {
  @unboxed
  type t =
    | @as("legend") Legend
    | @as("label") Label
}

let fieldOrientationClass = (~orientation: Orientation.t) =>
  switch orientation {
  | Horizontal => "flex-row items-center *:data-[slot=field-label]:flex-auto has-[>[data-slot=field-content]]:items-start has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px"
  | Responsive => "flex-col *:w-full [&>.sr-only]:w-auto @md/field-group:flex-row @md/field-group:items-center @md/field-group:*:w-auto @md/field-group:*:data-[slot=field-label]:flex-auto @md/field-group:has-[>[data-slot=field-content]]:items-start @md/field-group:has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px"
  | Vertical => "flex-col *:w-full [&>.sr-only]:w-auto"
  }

let fieldVariants = (~orientation=Orientation.Vertical) => {
  let base = "data-[invalid=true]:text-destructive gap-2 group/field flex w-full"
  `${base} ${fieldOrientationClass(~orientation)}`
}

module Set = {
  @react.component
  let make = (~className=?, ~children=?, ~id=?, ~style=?, ~onClick=?, ~onKeyDown=?) =>
    <fieldset
      ?id
      ?children
      ?style
      ?onClick
      ?onKeyDown
      dataSlot="field-set"
      className={cn(
        "flex flex-col gap-4 has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3",
        className,
      )}
    />
}

module Legend = {
  @react.component
  let make = (
    ~className=?,
    ~children=?,
    ~id=?,
    ~style=?,
    ~onClick=?,
    ~onKeyDown=?,
    ~variant=Variant.Legend,
  ) => {
    <legend
      ?id
      ?children
      ?style
      ?onClick
      ?onKeyDown
      dataSlot="field-legend"
      dataVariant={(variant :> string)}
      className={cn(
        "mb-1.5 font-medium data-[variant=label]:text-sm data-[variant=legend]:text-base",
        className,
      )}
    />
  }
}

module Group = {
  @react.componentWithProps(BaseUi.Types.DomProps.t)
  let make = (props: BaseUi.Types.DomProps.t) =>
    <div
      {...props}
      dataSlot="field-group"
      className={cn(
        "group/field-group @container/field-group flex w-full flex-col gap-5 data-[slot=checkbox-group]:gap-3 *:data-[slot=field-group]:gap-4",
        props.className,
      )}
    />
}

@react.component
let make = (
  ~className=?,
  ~children=?,
  ~id=?,
  ~style=?,
  ~onClick=?,
  ~onKeyDown=?,
  ~orientation=Orientation.Vertical,
  ~dataDisabled=?,
  ~dataInvalid=?,
  ~dir=?,
) => {
  <div
    ?id
    ?children
    ?style
    ?onClick
    ?onKeyDown
    ?dataDisabled
    ?dataInvalid
    ?dir
    role="group"
    dataSlot="field"
    dataOrientation={(orientation :> string)}
    className={cn(fieldVariants(~orientation), className)}
  />
}

module Content = {
  @react.component
  let make = (~className=?, ~children=?, ~id=?, ~style=?, ~onClick=?, ~onKeyDown=?) =>
    <div
      ?id
      ?children
      ?style
      ?onClick
      ?onKeyDown
      dataSlot="field-content"
      className={cn("group/field-content flex flex-1 flex-col gap-0.5 leading-snug", className)}
    />
}

module Label = {
  @react.component
  let make = (
    ~className=?,
    ~children=?,
    ~id=?,
    ~htmlFor=?,
    ~dir=?,
    ~onClick=?,
    ~onKeyDown=?,
    ~style=?,
  ) =>
    <label
      ?id
      ?htmlFor
      ?dir
      ?onClick
      ?onKeyDown
      ?style
      dataSlot="field-label"
      className={cn(
        "flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50 has-data-checked:bg-primary/5 has-data-checked:border-primary/30 dark:has-data-checked:border-primary/20 dark:has-data-checked:bg-primary/10 group/field-label peer/field-label w-fit leading-snug has-[>[data-slot=field]]:rounded-lg has-[>[data-slot=field]]:border *:data-[slot=field]:p-2.5 has-[>[data-slot=field]]:w-full has-[>[data-slot=field]]:flex-col",
        className,
      )}
      ?children
    />
}

module Title = {
  @react.component
  let make = (~className=?, ~children=?, ~id=?, ~style=?, ~onClick=?, ~onKeyDown=?) =>
    <div
      ?id
      ?children
      ?style
      ?onClick
      ?onKeyDown
      dataSlot="field-label"
      className={cn(
        "flex w-fit items-center gap-2 text-sm leading-snug font-medium group-data-[disabled=true]/field:opacity-50",
        className,
      )}
    />
}

module Description = {
  @react.component
  let make = (~className=?, ~children=?, ~id=?, ~style=?, ~dir=?, ~onClick=?, ~onKeyDown=?) =>
    <p
      ?id
      ?children
      ?style
      ?dir
      ?onClick
      ?onKeyDown
      dataSlot="field-description"
      className={cn(
        "text-muted-foreground text-left text-sm leading-normal font-normal group-has-data-horizontal/field:text-balance [[data-variant=legend]+&]:-mt-1.5 last:mt-0 nth-last-2:-mt-1 [&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4",
        className,
      )}
    />
}

module Separator = {
  @react.component
  let make = (~className=?, ~children=?, ~id=?, ~style=?, ~onClick=?, ~onKeyDown=?) => {
    let hasContent = children->Option.isSome
    <div
      ?id
      ?style
      ?onClick
      ?onKeyDown
      dataSlot="field-separator"
      dataContent={hasContent}
      className={cn(
        "relative -my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2",
        className,
      )}
    >
      <BaseUi.Separator
        orientation=Horizontal
        dataSlot="separator"
        className="absolute inset-0 top-1/2 bg-border shrink-0 data-horizontal:h-px data-horizontal:w-full data-vertical:w-px data-vertical:self-stretch"
      />
      {switch children {
      | Some(value) =>
        <span
          className="text-muted-foreground bg-background relative mx-auto block w-fit px-2"
          dataSlot="field-separator-content"
        >
          {value}
        </span>
      | None => React.null
      }}
    </div>
  }
}

module Error = {
  type t = {
    message: string,
  }
  @react.component
  let make = (~className=?, ~children=?, ~errors=?, ~id=?, ~style=?, ~onClick=?, ~onKeyDown=?) => {
    let content = React.useMemo(() => {
      children->Option.getOr(
        switch errors {
        | None | Some([]) => React.null
        | Some(errors) =>
          let uniqueErrors =
            Map.fromArray(errors->Array.map(error => (error.message, error)))
            ->Map.values
            ->Iterator.toArray
          switch uniqueErrors {
          | [{message}] => message->React.string
          | errors =>
            <ul className="ml-4 flex list-disc flex-col gap-1">
              {errors
              ->Array.mapWithIndex(({message}, index) =>
                <li key={index->Int.toString}> {message->React.string} </li>
              )
              ->React.array}
            </ul>
          }
        },
      )
    }, (children, errors))

    <div
      ?id
      ?style
      ?onClick
      ?onKeyDown
      role="alert"
      dataSlot="field-error"
      className={cn("text-sm font-normal text-destructive", className)}
    >
      {content}
    </div>
  }
}
