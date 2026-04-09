module Icons = Bindings__RadixUI__Icons
module DropdownMenu = Bindings__UI__DropdownMenu
module FrontmanLogo = Client__FrontmanLogo

@react.component
let make = (~onSettingsClick: unit => unit, ~previewUrl: string, ~isAgentRunning: bool) => {
  let iconSize = {"width": "14px", "height": "14px"}

  <DropdownMenu.DropdownMenu>
    <DropdownMenu.DropdownMenuTrigger asChild=true>
      <button
        type_="button"
        className="flex items-center justify-center w-7 h-7 rounded cursor-pointer hover:bg-white/5"
      >
        <FrontmanLogo size=18 className={isAgentRunning ? "frontman-logo-pulse" : ""} />
      </button>
    </DropdownMenu.DropdownMenuTrigger>
    <DropdownMenu.DropdownMenuContent align="start" sideOffset=4 className="w-48">
      <DropdownMenu.DropdownMenuItem
        onSelect={_ => onSettingsClick()} className="flex items-center gap-2 cursor-pointer"
      >
        <Icons.GearIcon style={iconSize} />
        {React.string("Settings")}
      </DropdownMenu.DropdownMenuItem>
      <DropdownMenu.DropdownMenuItem
        onSelect={_ =>
          WebAPI.Window.open_(
            WebAPI.Global.window,
            ~url="https://discord.gg/xk8uXJSvhC",
            ~target="_blank",
            ~features="noopener,noreferrer",
          )->ignore}
        className="flex items-center gap-2 cursor-pointer"
      >
        <Icons.QuestionMarkCircledIcon style={iconSize} />
        {React.string("Help")}
      </DropdownMenu.DropdownMenuItem>
      <DropdownMenu.DropdownMenuSeparator />
      <DropdownMenu.DropdownMenuItem
        onSelect={_ =>
          WebAPI.Window.open_(
            WebAPI.Global.window,
            ~url=previewUrl,
            ~target="_blank",
            ~features="noopener,noreferrer",
          )->ignore}
        className="flex items-center gap-2 cursor-pointer"
      >
        <Icons.OpenInNewWindowIcon style={iconSize} />
        {React.string("Open in new window")}
      </DropdownMenu.DropdownMenuItem>
    </DropdownMenu.DropdownMenuContent>
  </DropdownMenu.DropdownMenu>
}
