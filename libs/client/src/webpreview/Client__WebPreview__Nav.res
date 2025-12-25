/**
 * Client__WebPreview__Nav - Navigation components for the web preview
 * 
 * Pure ReScript replacements for AIElements WebPreview navigation components.
 */

module RadixUI__Icons = Bindings__RadixUI__Icons

// Navigation button with tooltip
module NavButton = {
  @react.component
  let make = (
    ~onClick: option<unit => unit>=?,
    ~disabled: bool=false,
    ~tooltip: option<string>=?,
    ~children: React.element,
  ) => {
    let buttonClasses = [
      "flex items-center justify-center w-8 h-8 rounded",
      "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-700/50",
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
  let make = (~value: option<string>=?, ~onChange: option<ReactEvent.Form.t => unit>=?, ~onKeyDown: option<ReactEvent.Keyboard.t => unit>=?) => {
    <input
      type_="text"
      value={value->Option.getOr("")}
      onChange=?{onChange}
      onKeyDown=?{onKeyDown}
      className="flex-1 h-8 px-3 text-xs bg-zinc-800 border border-zinc-700 rounded
                 text-zinc-200 placeholder-zinc-500
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
        "flex items-center gap-1 px-2 py-1.5 bg-zinc-900 border-b border-zinc-800",
        className->Option.getOr(""),
      ]->Array.filter(s => s != "")->Array.join(" ")}
    >
      {children}
    </div>
  }
}

// Main preview container
module Container = {
  @react.component
  let make = (~className: string=?, ~children: React.element) => {
    <div
      className={[
        "flex flex-col h-full bg-zinc-950",
        className->Option.getOr(""),
      ]->Array.filter(s => s != "")->Array.join(" ")}
    >
      {children}
    </div>
  }
}

