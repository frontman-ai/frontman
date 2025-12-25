/**
 * Client__PromptInput - Main chat input component
 * 
 * Pure ReScript replacement for AIElements PromptInput.
 * Features:
 * - Text input with auto-resize
 * - File attachments with drag-drop
 * - Model selector
 * - Submit button with status
 */

module Icons = Client__ToolIcons

// Attachment type
type attachment = {
  id: string,
  name: string,
  mediaType: string,
  url: string,
}

// Submit status
type submitStatus = Idle | Streaming | Submitted | Error

// Generate unique ID
let generateId: unit => string = %raw(`
  function() {
    return 'att_' + Math.random().toString(36).substr(2, 9);
  }
`)

// Model type
type model = {
  name: string,
  value: string,
}

// Attachment preview chip
module AttachmentChip = {
  @react.component
  let make = (~attachment: attachment, ~onRemove: string => unit) => {
    let isImage = attachment.mediaType->String.startsWith("image/")
    
    <div
      className="group flex items-center gap-1.5 h-7 px-2 
                 bg-zinc-800 border border-zinc-700 rounded-md
                 text-xs text-zinc-200 hover:bg-zinc-700/50"
    >
      {isImage
        ? <img
            src={attachment.url}
            alt={attachment.name}
            className="w-4 h-4 object-cover rounded"
          />
        : <Icons.FileIcon size=14 />}
      <span className="truncate max-w-[100px]">
        {React.string(attachment.name)}
      </span>
      <button
        type_="button"
        onClick={e => {
          ReactEvent.Mouse.stopPropagation(e)
          onRemove(attachment.id)
        }}
        className="opacity-0 group-hover:opacity-100 p-0.5 rounded hover:bg-zinc-600 transition-opacity"
      >
        <Icons.XIcon size=12 />
      </button>
    </div>
  }
}

// Model selector dropdown
module ModelSelector = {
  @react.component
  let make = (~models: array<model>, ~value: string, ~onChange: string => unit) => {
    <div className="relative">
      <select
        value
        onChange={e => {
          let target = ReactEvent.Form.target(e)
          onChange(target["value"])
        }}
        className="appearance-none h-7 pl-2 pr-6 text-xs
                   bg-transparent text-zinc-400 
                   border-none rounded cursor-pointer
                   hover:text-zinc-200 hover:bg-zinc-700/30
                   focus:outline-none focus:ring-0"
      >
        {models->Array.map(m => {
          <option key={m.value} value={m.value}>
            {React.string(m.name)}
          </option>
        })->React.array}
      </select>
      <Icons.ChevronDownIcon 
        size=12 
        className="absolute right-1 top-1/2 -translate-y-1/2 pointer-events-none text-zinc-400"
      />
    </div>
  }
}

// Submit button
module SubmitButton = {
  @react.component
  let make = (~disabled: bool, ~status: submitStatus, ~onClick: unit => unit) => {
    let icon = switch status {
    | Streaming => <Icons.StopIcon size=16 />
    | Submitted => <Icons.LoaderIcon size=16 />
    | Error => <Icons.XIcon size=16 />
    | Idle => <Icons.SendIcon size=16 />
    }
    
    let bgClass = switch status {
    | Streaming => "bg-amber-600 hover:bg-amber-500"
    | _ => "bg-blue-600 hover:bg-blue-500 disabled:bg-zinc-700"
    }
    
    <button
      type_="submit"
      disabled={disabled && status != Streaming}
      onClick={e => {
        ReactEvent.Mouse.preventDefault(e)
        onClick()
      }}
      className={`flex items-center justify-center w-8 h-8 rounded-md
                  text-white transition-colors
                  disabled:opacity-50 disabled:cursor-not-allowed ${bgClass}`}
    >
      {icon}
    </button>
  }
}

// Main component
@react.component
let make = (
  ~value: string,
  ~onChange: string => unit,
  ~onSubmit: unit => unit,
  ~models: array<model>,
  ~selectedModel: string,
  ~onModelChange: string => unit,
  ~isStreaming: bool,
  ~isConnected: bool,
  ~placeholder: string="What would you like to change?",
) => {
  let (attachments, setAttachments) = React.useState(() => [])
  let (isDragging, setIsDragging) = React.useState(() => false)
  let fileInputRef = React.useRef(Nullable.null)
  let textareaRef = React.useRef(Nullable.null)
  
  // Raw JS helpers for URL object handling
  let createObjectURL: WebAPI.FileAPI.file => string = %raw(`
    function(file) {
      return URL.createObjectURL(file);
    }
  `)
  
  let revokeObjectURL: string => unit = %raw(`
    function(url) {
      URL.revokeObjectURL(url);
    }
  `)
  
  // Handle file addition
  let addFiles = (files: array<WebAPI.FileAPI.file>) => {
    let newAttachments = files->Array.map(file => {
      {
        id: generateId(),
        name: file.name,
        mediaType: file.type_,
        url: createObjectURL(file),
      }
    })
    setAttachments(prev => Array.concat(prev, newAttachments))
  }
  
  // Handle file removal
  let removeAttachment = (id: string) => {
    setAttachments(prev => {
      let toRemove = prev->Array.find(a => a.id == id)
      toRemove->Option.forEach(a => revokeObjectURL(a.url))
      prev->Array.filter(a => a.id != id)
    })
  }
  
  // Handle drag events
  let handleDragOver = (e: ReactEvent.Mouse.t) => {
    ReactEvent.Mouse.preventDefault(e)
    setIsDragging(_ => true)
  }
  
  let handleDragLeave = (e: ReactEvent.Mouse.t) => {
    ReactEvent.Mouse.preventDefault(e)
    setIsDragging(_ => false)
  }
  
  // Handle file input change
  let handleFileInputChange = (e: ReactEvent.Form.t) => {
    let target = ReactEvent.Form.target(e)
    let files: option<array<WebAPI.FileAPI.file>> = target["files"]
    files->Option.forEach(f => addFiles(f))
  }
  
  // Handle key down for submit
  let handleKeyDown = (e: ReactEvent.Keyboard.t) => {
    let key = e->ReactEvent.Keyboard.key
    let shiftKey = e->ReactEvent.Keyboard.shiftKey
    
    if key == "Enter" && !shiftKey {
      ReactEvent.Keyboard.preventDefault(e)
      if value != "" || Array.length(attachments) > 0 {
        onSubmit()
        setAttachments(_ => [])
      }
    }
  }
  
  // Handle form submit
  let handleSubmit = () => {
    if value != "" || Array.length(attachments) > 0 {
      onSubmit()
      setAttachments(_ => [])
    }
  }
  
  let status = if isStreaming { Streaming } else { Idle }
  let isDisabled = !isConnected || (value == "" && Array.length(attachments) == 0)
  
  <div 
    className={`bg-zinc-900 border-t border-zinc-800 ${isDragging ? "ring-2 ring-blue-500/50" : ""}`}
    onDragOver={handleDragOver}
    onDragLeave={handleDragLeave}
  >
    // Attachments row
    {Array.length(attachments) > 0
      ? <div className="flex flex-wrap gap-1.5 px-3 pt-2">
          {attachments->Array.map(att => {
            <AttachmentChip key={att.id} attachment={att} onRemove={removeAttachment} />
          })->React.array}
        </div>
      : React.null}
    
    // Input area
    <div className="p-2">
      <textarea
        ref={ReactDOM.Ref.domRef(textareaRef)}
        value
        onChange={e => {
          let target = ReactEvent.Form.target(e)
          onChange(target["value"])
        }}
        onKeyDown={handleKeyDown}
        placeholder
        rows=1
        className="w-full min-h-[40px] max-h-[200px] px-3 py-2 
                   bg-zinc-800 border border-zinc-700 rounded-lg
                   text-sm text-zinc-200 placeholder-zinc-500
                   resize-none overflow-y-auto
                   focus:outline-none focus:ring-1 focus:ring-blue-500/50 focus:border-blue-500/50
                   field-sizing-content"
      />
    </div>
    
    // Footer with tools and submit
    <div className="flex items-center justify-between px-3 pb-2">
      <div className="flex items-center gap-1">
        // Add attachment button
        <button
          type_="button"
          onClick={_ => {
            fileInputRef.current
            ->Nullable.toOption
            ->Option.forEach(input => {
              let clickElement: Dom.element => unit = %raw(`function(el) { el.click(); }`)
              clickElement(input->Obj.magic)
            })
          }}
          className="flex items-center justify-center w-7 h-7 rounded
                     text-zinc-400 hover:text-zinc-200 hover:bg-zinc-700/50
                     transition-colors"
        >
          <Icons.PlusIcon size=16 />
        </button>
        <input
          ref={ReactDOM.Ref.domRef(fileInputRef)}
          type_="file"
          multiple=true
          onChange={handleFileInputChange}
          className="hidden"
        />
        
        // Model selector
        <ModelSelector models value={selectedModel} onChange={onModelChange} />
      </div>
      
      <SubmitButton disabled={isDisabled} status onClick={handleSubmit} />
    </div>
  </div>
}

