module Icons = Client__UI__Icons
module Button = Client__UI__Button
module Tooltip = Client__UI__Tooltip

@react.component
let make = (~chatOpen: bool, ~onToggle: unit => unit, ~isAgentRunning: bool=false) => {
  let (label, className, ariaControls) = switch chatOpen {
  | true => ("Close chat", "ml-auto cursor-w-resize", Some("chat-panel"))
  | false => ("Open chat", "group cursor-e-resize", None)
  }
  let logoClassName = switch isAgentRunning {
  | true => "frontman-logo-pulse"
  | false => ""
  }

  <Tooltip>
    <Tooltip.Trigger
      onClick={_ => onToggle()}
      render={<Button
        variant=Button.Variant.Ghost
        size=Button.Size.IconSm
        className
        ariaLabel=label
        ariaExpanded=chatOpen
        ?ariaControls
      />}
    >
      {switch chatOpen {
      | true => <Icons.PanelLeftCloseIcon dataIcon="panel-left-close" />
      | false =>
        <>
          <span
            className="flex items-center justify-center group-hover:hidden group-focus-visible:hidden"
          >
            <Client__FrontmanLogo size=18 className=logoClassName />
          </span>
          <Icons.PanelLeftOpenIcon
            dataIcon="panel-left-open"
            className="hidden group-hover:block group-focus-visible:block"
          />
        </>
      }}
    </Tooltip.Trigger>
    <Tooltip.Content sideOffset=4.> {React.string(label)} </Tooltip.Content>
  </Tooltip>
}
