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
      <path
        d="M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8zm7.5-6.923c-.67.204-1.335.82-1.887 1.855A7.97 7.97 0 0 0 5.145 4H7.5V1.077zM4.09 4a9.267 9.267 0 0 1 .64-1.539 6.7 6.7 0 0 1 .597-.933A7.025 7.025 0 0 0 2.255 4H4.09zm-.582 3.5c.03-.877.138-1.718.312-2.5H1.674a6.958 6.958 0 0 0-.656 2.5h2.49zM4.847 5a12.5 12.5 0 0 0-.338 2.5H7.5V5H4.847zM8.5 5v2.5h2.99a12.495 12.495 0 0 0-.337-2.5H8.5zM4.51 8.5a12.5 12.5 0 0 0 .337 2.5H7.5V8.5H4.51zm3.99 0V11h2.653c.187-.765.306-1.608.338-2.5H8.5zM5.145 12c.138.386.295.744.468 1.068.552 1.035 1.218 1.65 1.887 1.855V12H5.145zm.182 2.472a6.696 6.696 0 0 1-.597-.933A9.268 9.268 0 0 1 4.09 12H2.255a7.024 7.024 0 0 0 3.072 2.472zM3.82 11a13.652 13.652 0 0 1-.312-2.5h-2.49c.062.89.291 1.733.656 2.5H3.82zm6.853 3.472A7.024 7.024 0 0 0 13.745 12H11.91a9.27 9.27 0 0 1-.64 1.539 6.688 6.688 0 0 1-.597.933zM8.5 12v2.923c.67-.204 1.335-.82 1.887-1.855.173-.324.33-.682.468-1.068H8.5zm3.68-1h2.146c.365-.767.594-1.61.656-2.5h-2.49a13.65 13.65 0 0 1-.312 2.5zm2.802-3.5a6.959 6.959 0 0 0-.656-2.5H12.18c.174.782.282 1.623.312 2.5h2.49zM11.27 2.461c.247.464.462.98.64 1.539h1.835a7.024 7.024 0 0 0-3.072-2.472c.218.284.418.598.597.933zM10.855 4a7.966 7.966 0 0 0-.468-1.068C9.835 1.897 9.17 1.282 8.5 1.077V4h2.355z"
      />
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

module SparklesIcon = {
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
        d="M7.657 6.247c.11-.33.576-.33.686 0l.645 1.937a2.89 2.89 0 0 0 1.828 1.828l1.937.645c.33.11.33.576 0 .686l-1.937.645a2.89 2.89 0 0 0-1.828 1.828l-.645 1.937c-.11.33-.576.33-.686 0l-.645-1.937a2.89 2.89 0 0 0-1.828-1.828l-1.937-.645c-.33-.11-.33-.576 0-.686l1.937-.645a2.89 2.89 0 0 0 1.828-1.828l.645-1.937zM13.794 1.185c.054-.163.287-.163.341 0l.317.95c.158.476.45.768.926.926l.95.317c.163.054.163.287 0 .341l-.95.317c-.476.158-.768.45-.926.926l-.317.95c-.054.163-.287.163-.341 0l-.317-.95c-.158-.476-.45-.768-.926-.926l-.95-.317c-.163-.054-.163-.287 0-.341l.95-.317c.476-.158.768-.45.926-.926l.317-.95zM2.758 4.435c.054-.163.287-.163.341 0l.317.95c.158.476.45.768.926.926l.95.317c.163.054.163.287 0 .341l-.95.317c-.476.158-.768.45-.926.926l-.317.95c-.054.163-.287.163-.341 0l-.317-.95c-.158-.476-.45-.768-.926-.926l-.95-.317c-.163-.054-.163-.287 0-.341l.95-.317c.476-.158.768-.45.926-.926l.317-.95z"
      />
    </svg>
  }
}

// Image/photo icon for file attachments
module ImageIcon = {
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
      <path d="M6.002 5.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0z" />
      <path
        d="M2.002 1a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V3a2 2 0 0 0-2-2h-12zm12 1a1 1 0 0 1 1 1v6.5l-3.777-1.947a.5.5 0 0 0-.577.093l-3.71 3.71-2.66-1.772a.5.5 0 0 0-.63.062L1.002 12V3a1 1 0 0 1 1-1h12z"
      />
    </svg>
  }
}

// Clipboard/paste icon for pasted text
module ClipboardPasteIcon = {
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
        d="M10 1.5a.5.5 0 0 0-.5-.5h-3a.5.5 0 0 0-.5.5v1a.5.5 0 0 0 .5.5h3a.5.5 0 0 0 .5-.5v-1Zm-5-.5A1.5 1.5 0 0 1 6.5 0h3A1.5 1.5 0 0 1 11 1.5v1A1.5 1.5 0 0 1 9.5 4h-3A1.5 1.5 0 0 1 5 2.5v-1Zm-2 0h1v1A2.5 2.5 0 0 0 6.5 5h3A2.5 2.5 0 0 0 12 2.5v-1h1a2 2 0 0 1 2 2V14a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2Z"
      />
    </svg>
  }
}

// Upload/arrow-up icon for drag-drop overlay
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

module DiscordIcon = {
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
        d="M13.545 2.907a13.227 13.227 0 0 0-3.257-1.011.05.05 0 0 0-.052.025c-.141.25-.297.577-.406.833a12.19 12.19 0 0 0-3.658 0 8.258 8.258 0 0 0-.412-.833.051.051 0 0 0-.052-.025c-1.125.194-2.22.534-3.257 1.011a.041.041 0 0 0-.021.018C.356 6.024-.213 9.047.066 12.032c.001.014.01.028.021.037a13.276 13.276 0 0 0 3.995 2.02.05.05 0 0 0 .056-.019c.308-.42.582-.863.818-1.329a.05.05 0 0 0-.028-.07 8.735 8.735 0 0 1-1.248-.595.05.05 0 0 1-.005-.083c.084-.063.168-.129.248-.195a.05.05 0 0 1 .051-.007c2.619 1.196 5.454 1.196 8.041 0a.052.052 0 0 1 .053.007c.08.066.164.132.248.195a.051.051 0 0 1-.004.085c-.399.232-.813.44-1.249.593a.05.05 0 0 0-.027.07c.24.465.515.909.817 1.329a.05.05 0 0 0 .056.019 13.235 13.235 0 0 0 4.001-2.02.049.049 0 0 0 .021-.037c.334-3.451-.559-6.449-2.366-9.106a.034.034 0 0 0-.02-.019zM5.347 10.2c-.789 0-1.438-.724-1.438-1.612 0-.889.637-1.613 1.438-1.613.807 0 1.45.73 1.438 1.613 0 .888-.637 1.612-1.438 1.612zm5.316 0c-.788 0-1.438-.724-1.438-1.612 0-.889.637-1.613 1.438-1.613.807 0 1.451.73 1.438 1.613 0 .888-.631 1.612-1.438 1.612z"
      />
    </svg>
  }
}
