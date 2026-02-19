/**
 * Client__WebPreview__Nav - Navigation components for the web preview
 *
 * Pure ReScript replacements for AIElements WebPreview navigation components.
 */
module RadixUI__Icons = Bindings__RadixUI__Icons

// Decorative traffic lights (macOS-style window controls)
module TrafficLights = {
  @react.component
  let make = () => {
    <div className="flex items-center gap-2 px-3">
      <div className="w-3 h-3 rounded-full bg-red-500" />
      <div className="w-3 h-3 rounded-full bg-yellow-500" />
      <div className="w-3 h-3 rounded-full bg-green-500" />
    </div>
  }
}

// Navigation button with tooltip
module NavButton = {
  @react.component
  let make = (
    ~onClick: option<unit => unit>=?,
    ~disabled: bool=false,
    ~tooltip: option<string>=?,
    ~children: React.element,
  ) => {
    let buttonClasses =
      [
        "flex items-center justify-center w-8 h-8 rounded-lg",
        "text-gray-500 hover:text-gray-700 hover:bg-gray-200",
        "transition-colors disabled:opacity-50 disabled:cursor-not-allowed",
      ]->Array.join(" ")

    <button
      type_="button"
      onClick={e => {
        ReactEvent.Mouse.preventDefault(e)
        onClick->Option.forEach(fn => fn())
      }}
      disabled
      className={buttonClasses}
      title=?{tooltip}
    >
      {children}
    </button>
  }
}

// URL input field
module UrlInput = {
  @react.component
  let make = (
    ~value: option<string>=?,
    ~onChange: option<ReactEvent.Form.t => unit>=?,
    ~onKeyDown: option<ReactEvent.Keyboard.t => unit>=?,
    ~onFocus: option<ReactEvent.Focus.t => unit>=?,
    ~onBlur: option<ReactEvent.Focus.t => unit>=?,
  ) => {
    <input
      type_="text"
      value={value->Option.getOr("")}
      onChange={onChange->Option.getOr(_ => ())}
      onKeyDown=?{onKeyDown}
      onFocus=?{onFocus}
      onBlur=?{onBlur}
      className="flex-1 h-8 px-3 text-xs bg-gray-100 border border-gray-200 rounded
                 text-gray-700 placeholder-gray-400
                 focus:outline-none focus:ring-1 focus:ring-blue-500/50 focus:border-blue-500/50"
      placeholder="Enter URL..."
    />
  }
}

// Navigation bar container
module Navigation = {
  @react.component
  let make = (~className: option<string>=?, ~children: React.element) => {
    <div
      className={[
        "flex items-center gap-1 px-2 py-2 bg-gray-50 border-b border-gray-200",
        className->Option.getOr(""),
      ]
      ->Array.filter(s => s != "")
      ->Array.join(" ")}
    >
      {children}
    </div>
  }
}

// Main preview container
module Container = {
  @react.component
  let make = (~className: option<string>=?, ~children: React.element) => {
    <div
      className={["flex flex-col h-full bg-white", className->Option.getOr("")]
      ->Array.filter(s => s != "")
      ->Array.join(" ")}
    >
      {children}
    </div>
  }
}
