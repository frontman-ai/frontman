/**
 * ToolIcons - Icon mapping system for tool calls
 * 
 * Maps tool names to appropriate SVG icons based on the tool's purpose.
 * Icons are 14x14 by default and use currentColor for theming.
 */

// Icon component type
type iconProps = {
  size?: int,
  className?: string,
}

// Default size
let defaultSize = 14

// ============================================================================
// Icon Components
// ============================================================================

module EyeIcon = {
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
      <path d="M16 8s-3-5.5-8-5.5S0 8 0 8s3 5.5 8 5.5S16 8 16 8zM1.173 8a13.133 13.133 0 0 1 1.66-2.043C4.12 4.668 5.88 3.5 8 3.5c2.12 0 3.879 1.168 5.168 2.457A13.133 13.133 0 0 1 14.828 8c-.058.087-.122.183-.195.288-.335.48-.83 1.12-1.465 1.755C11.879 11.332 10.119 12.5 8 12.5c-2.12 0-3.879-1.168-5.168-2.457A13.134 13.134 0 0 1 1.172 8z"/>
      <path d="M8 5.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5zM4.5 8a3.5 3.5 0 1 1 7 0 3.5 3.5 0 0 1-7 0z"/>
    </svg>
  }
}

module PencilIcon = {
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
      <path d="M12.854.146a.5.5 0 0 0-.707 0L10.5 1.793 14.207 5.5l1.647-1.646a.5.5 0 0 0 0-.708l-3-3zm.646 6.061L9.793 2.5 3.293 9H3.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.207l6.5-6.5zm-7.468 7.468A.5.5 0 0 1 6 13.5V13h-.5a.5.5 0 0 1-.5-.5V12h-.5a.5.5 0 0 1-.5-.5V11h-.5a.5.5 0 0 1-.5-.5V10h-.5a.499.499 0 0 1-.175-.032l-.179.178a.5.5 0 0 0-.11.168l-2 5a.5.5 0 0 0 .65.65l5-2a.5.5 0 0 0 .168-.11l.178-.178z"/>
    </svg>
  }
}

module SearchIcon = {
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
      <path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001c.03.04.062.078.098.115l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.1zM12 6.5a5.5 5.5 0 1 1-11 0 5.5 5.5 0 0 1 11 0z"/>
    </svg>
  }
}

module TerminalIcon = {
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
      <path d="M6 9a.5.5 0 0 1 .5-.5h3a.5.5 0 0 1 0 1h-3A.5.5 0 0 1 6 9zM3.854 4.146a.5.5 0 1 0-.708.708L4.793 6.5 3.146 8.146a.5.5 0 1 0 .708.708l2-2a.5.5 0 0 0 0-.708l-2-2z"/>
      <path d="M2 1a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V3a2 2 0 0 0-2-2H2zm12 1a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1h12z"/>
    </svg>
  }
}

module GlobeIcon = {
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
      <path d="M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8zm7.5-6.923c-.67.204-1.335.82-1.887 1.855A7.97 7.97 0 0 0 5.145 4H7.5V1.077zM4.09 4a9.267 9.267 0 0 1 .64-1.539 6.7 6.7 0 0 1 .597-.933A7.025 7.025 0 0 0 2.255 4H4.09zm-.582 3.5c.03-.877.138-1.718.312-2.5H1.674a6.958 6.958 0 0 0-.656 2.5h2.49zM4.847 5a12.5 12.5 0 0 0-.338 2.5H7.5V5H4.847zM8.5 5v2.5h2.99a12.495 12.495 0 0 0-.337-2.5H8.5zM4.51 8.5a12.5 12.5 0 0 0 .337 2.5H7.5V8.5H4.51zm3.99 0V11h2.653c.187-.765.306-1.608.338-2.5H8.5zM5.145 12c.138.386.295.744.468 1.068.552 1.035 1.218 1.65 1.887 1.855V12H5.145zm.182 2.472a6.696 6.696 0 0 1-.597-.933A9.268 9.268 0 0 1 4.09 12H2.255a7.024 7.024 0 0 0 3.072 2.472zM3.82 11a13.652 13.652 0 0 1-.312-2.5h-2.49c.062.89.291 1.733.656 2.5H3.82zm6.853 3.472A7.024 7.024 0 0 0 13.745 12H11.91a9.27 9.27 0 0 1-.64 1.539 6.688 6.688 0 0 1-.597.933zM8.5 12v2.923c.67-.204 1.335-.82 1.887-1.855.173-.324.33-.682.468-1.068H8.5zm3.68-1h2.146c.365-.767.594-1.61.656-2.5h-2.49a13.65 13.65 0 0 1-.312 2.5zm2.802-3.5a6.959 6.959 0 0 0-.656-2.5H12.18c.174.782.282 1.623.312 2.5h2.49zM11.27 2.461c.247.464.462.98.64 1.539h1.835a7.024 7.024 0 0 0-3.072-2.472c.218.284.418.598.597.933zM10.855 4a7.966 7.966 0 0 0-.468-1.068C9.835 1.897 9.17 1.282 8.5 1.077V4h2.355z"/>
    </svg>
  }
}

module FolderIcon = {
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
      <path d="M.54 3.87.5 3a2 2 0 0 1 2-2h3.672a2 2 0 0 1 1.414.586l.828.828A2 2 0 0 0 9.828 3H14.5a2 2 0 0 1 2 2v1.172a2 2 0 0 0 0 1.656V13a2 2 0 0 1-2 2H2.5a2 2 0 0 1-2-2V4.172a2 2 0 0 0 .04-.302zM1.5 4v9a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4a1 1 0 0 0-1-1H9.828a1 1 0 0 1-.707-.293l-.828-.828A1 1 0 0 0 7.586 2H3.5a1 1 0 0 0-1 1v1z"/>
    </svg>
  }
}

module TrashIcon = {
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
      <path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6z"/>
      <path fillRule="evenodd" d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1v1zM4.118 4 4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z"/>
    </svg>
  }
}

module ChecklistIcon = {
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
      <path d="M14 1a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z"/>
      <path d="M10.97 4.97a.75.75 0 0 1 1.071 1.05l-3.992 4.99a.75.75 0 0 1-1.08.02L4.324 8.384a.75.75 0 1 1 1.06-1.06l2.094 2.093 3.473-4.425a.235.235 0 0 1 .02-.022z"/>
    </svg>
  }
}

module WrenchIcon = {
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
      <path d="M1 0 0 1l2.2 3.081a1 1 0 0 0 .815.419h.07a1 1 0 0 1 .708.293l2.675 2.675-2.617 2.654A3.003 3.003 0 0 0 0 13a3 3 0 1 0 5.878-.851l2.654-2.617.968.968-.305.914a1 1 0 0 0 .242 1.023l3.356 3.356a1 1 0 0 0 1.414 0l1.586-1.586a1 1 0 0 0 0-1.414l-3.356-3.356a1 1 0 0 0-1.023-.242l-.914.305-.707-.707 4.5-4.5-1.293-1.293L9.207 5.5l-.707-.707-.305-.914a1 1 0 0 0-.242-1.023L4.597.5a1 1 0 0 0-1.414 0L1.597 2.086a1 1 0 0 0 0 1.414L5.22 7.124l-.293.293h-.07a1 1 0 0 0-.815-.419L1 3.5V0zM3 13a2 2 0 1 1 0-4 2 2 0 0 1 0 4z"/>
    </svg>
  }
}

module CircleIcon = {
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
      <circle cx="8" cy="8" r="7" stroke="currentColor" strokeWidth="1" fill="none"/>
    </svg>
  }
}

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
      <path d="M4 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H4zm0 1h8a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1z"/>
    </svg>
  }
}

module PlugIcon = {
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
      <path d="M6 0a.5.5 0 0 1 .5.5V3h3V.5a.5.5 0 0 1 1 0V3h1a.5.5 0 0 1 .5.5v3A3.5 3.5 0 0 1 8.5 10c-.002.434-.01.845-.04 1.22-.041.514-.126 1.003-.317 1.424a2.083 2.083 0 0 1-.97 1.028C6.725 13.9 6.169 14 5.5 14c-.998 0-1.61.33-1.974.718A1.922 1.922 0 0 0 3 16H2c0-.616.232-1.367.797-1.968C3.374 13.42 4.261 13 5.5 13c.581 0 .962-.088 1.218-.219.241-.123.4-.3.514-.55.121-.266.193-.621.23-1.09.027-.34.035-.718.037-1.141A3.5 3.5 0 0 1 4 6.5v-3a.5.5 0 0 1 .5-.5h1V.5A.5.5 0 0 1 6 0zM5 4v2.5A2.5 2.5 0 0 0 7.5 9h1A2.5 2.5 0 0 0 11 6.5V4H5z"/>
    </svg>
  }
}

module BrainIcon = {
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
      <path d="M8 0c1.627 0 3.03.976 3.654 2.38A3.544 3.544 0 0 1 14 5.5c0 1.31-.653 2.456-1.654 3.122A3.544 3.544 0 0 1 14 11.5a3.49 3.49 0 0 1-1.667 2.982A3 3 0 0 1 8 16a3 3 0 0 1-4.333-1.518A3.49 3.49 0 0 1 2 11.5a3.544 3.544 0 0 1 1.654-2.878A3.544 3.544 0 0 1 2 5.5c0-1.573 1.04-2.9 2.464-3.33A3.674 3.674 0 0 1 8 0zm0 1a2.676 2.676 0 0 0-2.581 2H5a.5.5 0 0 0 0 1h.419c-.019.168-.019.332 0 .5H5a.5.5 0 0 0 0 1h.419A2.676 2.676 0 0 0 8 7.5a2.676 2.676 0 0 0 2.581-2H11a.5.5 0 0 0 0-1h-.419c.019-.168.019-.332 0-.5H11a.5.5 0 0 0 0-1h-.419A2.676 2.676 0 0 0 8 1z"/>
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
      <path d="M8 0a8 8 0 1 0 8 8 .5.5 0 0 1 1 0 9 9 0 1 1-9-9 .5.5 0 0 1 0 1z"/>
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
      <path d="M12.736 3.97a.733.733 0 0 1 1.047 0c.286.289.29.756.01 1.05L7.88 12.01a.733.733 0 0 1-1.065.02L3.217 8.384a.757.757 0 0 1 0-1.06.733.733 0 0 1 1.047 0l3.052 3.093 5.4-6.425a.247.247 0 0 1 .02-.022z"/>
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
      <path d="M4.646 4.646a.5.5 0 0 1 .708 0L8 7.293l2.646-2.647a.5.5 0 0 1 .708.708L8.707 8l2.647 2.646a.5.5 0 0 1-.708.708L8 8.707l-2.646 2.647a.5.5 0 0 1-.708-.708L7.293 8 4.646 5.354a.5.5 0 0 1 0-.708z"/>
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
      <path d="M4 2a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V2Zm2-1a1 1 0 0 0-1 1v8a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V2a1 1 0 0 0-1-1H6ZM2 5a1 1 0 0 0-1 1v8a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1v-1h1v1a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h1v1H2Z"/>
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
      <path fillRule="evenodd" d="M1.646 4.646a.5.5 0 0 1 .708 0L8 10.293l5.646-5.647a.5.5 0 0 1 .708.708l-6 6a.5.5 0 0 1-.708 0l-6-6a.5.5 0 0 1 0-.708z"/>
    </svg>
  }
}

module SendIcon = {
  @react.component
  let make = (~size: int=defaultSize, ~className: string="") => {
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      width={Int.toString(size)}
      height={Int.toString(size)}
      className={className}
    >
      <path d="M22 2L11 13" />
      <path d="M22 2L15 22L11 13L2 9L22 2Z" />
    </svg>
  }
}

module StopIcon = {
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
      <rect x="3" y="3" width="10" height="10" rx="1" />
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
      <path d="M8 2a.5.5 0 0 1 .5.5v5h5a.5.5 0 0 1 0 1h-5v5a.5.5 0 0 1-1 0v-5h-5a.5.5 0 0 1 0-1h5v-5A.5.5 0 0 1 8 2z"/>
    </svg>
  }
}

// ============================================================================
// Icon Mapping Function
// ============================================================================

type toolCategory =
  | Read
  | Edit
  | Search
  | Terminal
  | Web
  | List
  | Delete
  | Todo
  | Lint
  | Mcp
  | Unknown

let categorizeToolName = (toolName: string): toolCategory => {
  let lowerName = String.toLowerCase(toolName)
  
  if String.includes(lowerName, "read") || String.includes(lowerName, "get") || String.includes(lowerName, "fetch") {
    Read
  } else if String.includes(lowerName, "edit") || String.includes(lowerName, "write") || String.includes(lowerName, "update") || String.includes(lowerName, "create") || String.includes(lowerName, "set") {
    Edit
  } else if String.includes(lowerName, "search") || String.includes(lowerName, "find") || String.includes(lowerName, "grep") || String.includes(lowerName, "query") {
    Search
  } else if String.includes(lowerName, "terminal") || String.includes(lowerName, "run") || String.includes(lowerName, "exec") || String.includes(lowerName, "command") || String.includes(lowerName, "shell") {
    Terminal
  } else if String.includes(lowerName, "web") || String.includes(lowerName, "browser") || String.includes(lowerName, "navigate") || String.includes(lowerName, "url") {
    Web
  } else if String.includes(lowerName, "list") || String.includes(lowerName, "dir") || String.includes(lowerName, "folder") {
    List
  } else if String.includes(lowerName, "delete") || String.includes(lowerName, "remove") {
    Delete
  } else if String.includes(lowerName, "todo") || String.includes(lowerName, "task") || String.includes(lowerName, "plan") {
    Todo
  } else if String.includes(lowerName, "lint") || String.includes(lowerName, "fix") {
    Lint
  } else if String.includes(lowerName, "mcp") {
    Mcp
  } else {
    Unknown
  }
}

/**
 * Get the appropriate icon component for a tool name
 */
let getToolIcon = (toolName: string, ~size: int=defaultSize): React.element => {
  let category = categorizeToolName(toolName)

  switch category {
  | Read => <EyeIcon size />
  | Edit => <PencilIcon size />
  | Search => <SearchIcon size />
  | Terminal => <TerminalIcon size />
  | Web => <GlobeIcon size />
  | List => <FolderIcon size />
  | Delete => <TrashIcon size />
  | Todo => <ChecklistIcon size />
  | Lint => <WrenchIcon size />
  | Mcp => <PlugIcon size />
  | Unknown => <CircleIcon size />
  }
}

