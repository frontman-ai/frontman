/**
 * ToolIcons - SVG icon components for the UI
 * 
 * Icons are 14x14 by default and use currentColor for theming.
 */
let // Default size
defaultSize = 14

// ============================================================================
// Icon Components
// ============================================================================

module FileIcon = {
  @react.component
  let make = (~size: int=defaultSize, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 16 16"
      fill="currentColor"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={className}
    >
      <path
        d="M4 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H4zm0 1h8a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1z"
      />
    </svg>
  }
}

module LoaderIcon = {
  @react.component
  let make = (~size: int=defaultSize, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 16 16"
      fill="currentColor"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={`animate-spin ${className}`}
    >
      <path d="M8 0a8 8 0 1 0 8 8 .5.5 0 0 1 1 0 9 9 0 1 1-9-9 .5.5 0 0 1 0 1z" />
    </svg>
  }
}

module CheckIcon = {
  @react.component
  let make = (~size: int=defaultSize, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 16 16"
      fill="currentColor"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={className}
    >
      <path
        d="M12.736 3.97a.733.733 0 0 1 1.047 0c.286.289.29.756.01 1.05L7.88 12.01a.733.733 0 0 1-1.065.02L3.217 8.384a.757.757 0 0 1 0-1.06.733.733 0 0 1 1.047 0l3.052 3.093 5.4-6.425a.247.247 0 0 1 .02-.022z"
      />
    </svg>
  }
}

module XIcon = {
  @react.component
  let make = (~size: int=defaultSize, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 16 16"
      fill="currentColor"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={className}
    >
      <path
        d="M4.646 4.646a.5.5 0 0 1 .708 0L8 7.293l2.646-2.647a.5.5 0 0 1 .708.708L8.707 8l2.647 2.646a.5.5 0 0 1-.708.708L8 8.707l-2.646 2.647a.5.5 0 0 1-.708-.708L7.293 8 4.646 5.354a.5.5 0 0 1 0-.708z"
      />
    </svg>
  }
}

module CopyIcon = {
  @react.component
  let make = (~size: int=defaultSize, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 16 16"
      fill="currentColor"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={className}
    >
      <path
        d="M4 2a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V2Zm2-1a1 1 0 0 0-1 1v8a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V2a1 1 0 0 0-1-1H6ZM2 5a1 1 0 0 0-1 1v8a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1v-1h1v1a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h1v1H2Z"
      />
    </svg>
  }
}

module ChevronDownIcon = {
  @react.component
  let make = (~size: int=12, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 16 16"
      fill="currentColor"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={className}
    >
      <path
        fillRule="evenodd"
        d="M1.646 4.646a.5.5 0 0 1 .708 0L8 10.293l5.646-5.647a.5.5 0 0 1 .708.708l-6 6a.5.5 0 0 1-.708 0l-6-6a.5.5 0 0 1 0-.708z"
      />
    </svg>
  }
}

// Send arrow icon for submit button
module SendArrowIcon = {
  @react.component
  let make = (~size: int=20, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 20 20"
      fill="none"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={className}
    >
      <path
        d="M17 10H7"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M17 10L5 18L7 10L5 2L17 10Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  }
}

module PlusIcon = {
  @react.component
  let make = (~size: int=defaultSize, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 16 16"
      fill="currentColor"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={className}
    >
      <path
        d="M8 2a.5.5 0 0 1 .5.5v5h5a.5.5 0 0 1 0 1h-5v5a.5.5 0 0 1-1 0v-5h-5a.5.5 0 0 1 0-1h5v-5A.5.5 0 0 1 8 2z"
      />
    </svg>
  }
}

module CursorClickIcon = {
  @react.component
  let make = (~size: int=defaultSize, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 22 22"
      fill="none"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={className}
    >
      <path
        d="M15.3685 15.3693L19.8107 19.8116M6.06973 0.887451L6.88319 3.92055M3.92144 6.88246L0.887451 6.06895M13.149 2.78353L10.9275 5.00522M5.00501 10.9269L2.78553 13.1486M7.96646 7.96581L13.2011 20.5296L15.0583 15.058L20.5296 13.2007L7.96646 7.96581Z"
        stroke="currentColor"
        strokeWidth="1.7744"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  }
}

module UploadIcon = {
  @react.component
  let make = (~size: int=defaultSize, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 16 16"
      fill="currentColor"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={className}
    >
      <path
        d="M.5 9.9a.5.5 0 0 1 .5.5v2.5a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-2.5a.5.5 0 0 1 1 0v2.5a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2v-2.5a.5.5 0 0 1 .5-.5z"
      />
      <path
        d="M7.646 1.146a.5.5 0 0 1 .708 0l3 3a.5.5 0 0 1-.708.708L8.5 2.707V11.5a.5.5 0 0 1-1 0V2.707L5.354 4.854a.5.5 0 1 1-.708-.708l3-3z"
      />
    </svg>
  }
}
