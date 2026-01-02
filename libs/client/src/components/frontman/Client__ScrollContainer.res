/**
 * Client__ScrollContainer - Scrollable container with stick-to-bottom behavior
 * 
 * Direct binding to use-stick-to-bottom library for chat-like scrolling.
 * Replaces AIElements.Conversation with a direct binding.
 */

// Context hook for accessing scroll state
type scrollContext = {
  isAtBottom: bool,
  scrollToBottom: unit => unit,
}

@module("use-stick-to-bottom")
external useStickToBottomContext: unit => scrollContext = "useStickToBottomContext"

// Main scroll container
module StickToBottom = {
  @module("use-stick-to-bottom") @react.component
  external make: (
    ~className: string=?,
    ~initial: string=?,
    ~resize: string=?,
    ~role: string=?,
    ~children: React.element,
  ) => React.element = "StickToBottom"
}

// Content wrapper inside the scroll container
module Content = {
  @module("use-stick-to-bottom") @scope("StickToBottom") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element,
  ) => React.element = "Content"
}

// Cached className for scroll button
let scrollButtonBaseClassName = "absolute bottom-4 left-[50%] translate-x-[-50%] rounded-full w-8 h-8 flex items-center justify-center bg-zinc-800 border border-zinc-600 text-zinc-200 hover:bg-zinc-700 transition-colors"

// Scroll to bottom button
module ScrollButton = {
  @react.component
  let make = (~className: option<string>=?) => {
    let {isAtBottom, scrollToBottom} = useStickToBottomContext()
    
    let buttonClassName = React.useMemo1(() => {
      switch className {
      | None => scrollButtonBaseClassName
      | Some(extra) => `${scrollButtonBaseClassName} ${extra}`
      }
    }, [className])
    
    if isAtBottom {
      React.null
    } else {
      <button
        type_="button"
        onClick={_ => scrollToBottom()}
        className={buttonClassName}
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="w-4 h-4"
        >
          <path d="M12 5v14" />
          <path d="m19 12-7 7-7-7" />
        </svg>
      </button>
    }
  }
}

// Cached base className for main container
let containerBaseClassName = "relative flex-1 overflow-y-auto"

// Main component wrapper for convenient usage
@react.component
let make = (~className: option<string>=?, ~children: React.element) => {
  let containerClassName = React.useMemo1(() => {
    switch className {
    | None => containerBaseClassName
    | Some(extra) => `${containerBaseClassName} ${extra}`
    }
  }, [className])
  
  <StickToBottom
    className={containerClassName}
    initial="smooth"
    resize="smooth"
    role="log"
  >
    {children}
  </StickToBottom>
}

// Cached base className for content wrapper
let contentBaseClassName = "p-4"

// Content subcomponent
module ContentWrapper = {
  @react.component
  let make = (~className: option<string>=?, ~children: React.element) => {
    let contentClassName = React.useMemo1(() => {
      switch className {
      | None => contentBaseClassName
      | Some(extra) => `${contentBaseClassName} ${extra}`
      }
    }, [className])
    
    <Content className={contentClassName}>
      {children}
    </Content>
  }
}

