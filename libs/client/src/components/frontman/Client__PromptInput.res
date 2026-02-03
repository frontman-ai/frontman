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


// Generate unique ID
let generateId: unit => string = %raw(`
  function() {
    return 'att_' + Math.random().toString(36).substr(2, 9);
  }
`)

// Re-export model types from state for external use
module StateTypes = Client__State__Types

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

// Model selector dropdown - supports grouped providers
// Uses Radix UI Select for consistent dark theme styling across all platforms (including Linux)
module ModelSelector = {
  module Select = Bindings__RadixUI__Select

  // Get the display name for the currently selected model
  let getSelectedModelDisplay = (
    providers: array<StateTypes.providerConfig>,
    selectedValue: string,
  ): option<string> => {
    // selectedValue is "provider:modelValue"
    switch selectedValue->String.split(":")->Array.get(0) {
    | Some(providerId) =>
      let modelValue =
        selectedValue->String.slice(~start=String.length(providerId) + 1, ~end=String.length(selectedValue))
      providers
      ->Array.findMap(provider => {
        if provider.id == providerId {
          provider.models->Array.findMap(model => {
            if model.value == modelValue {
              Some(model.displayName)
            } else {
              None
            }
          })
        } else {
          None
        }
      })
    | None => None
    }
  }

  @react.component
  let make = (
    ~providers: array<StateTypes.providerConfig>,
    ~selectedValue: string,
    ~onModelChange: (~provider: string, ~value: string) => unit,
  ) => {
    let selectedDisplay = React.useMemo2(
      () => getSelectedModelDisplay(providers, selectedValue),
      (providers, selectedValue),
    )

    <Select.Root
      value={selectedValue}
      onValueChange={value => {
        // Parse the combined value "provider:model_value"
        switch value->String.split(":")->Array.get(0) {
        | Some(provider) =>
          // Value is everything after "provider:"
          let modelValue =
            value->String.slice(~start=String.length(provider) + 1, ~end=String.length(value))
          onModelChange(~provider, ~value=modelValue)
        | None => ()
        }
      }}>
      <Select.Trigger
        className="inline-flex items-center justify-between gap-1 h-7 pl-2 pr-1 text-xs
                   bg-transparent text-zinc-400 
                   border-none rounded cursor-pointer
                   hover:text-zinc-200 hover:bg-zinc-700/30
                   focus:outline-none focus:ring-0
                   data-[placeholder]:text-zinc-500">
        <span className="truncate max-w-[140px]">
          {React.string(selectedDisplay->Option.getOr("Select model..."))}
        </span>
        <Select.Icon className="text-zinc-400">
          <Icons.ChevronDownIcon size=12 />
        </Select.Icon>
      </Select.Trigger>
      <Select.Portal>
        <Select.Content
          position=#popper
          sideOffset=4
          className="z-50 min-w-[180px] max-h-[300px] overflow-hidden
                     bg-zinc-800 border border-zinc-700 rounded-lg shadow-xl
                     animate-in fade-in-0 zoom-in-95">
          <Select.Viewport className="p-1">
            {providers
            ->Array.map(provider => {
              <Select.Group key={provider.id}>
                <Select.Label
                  className="px-2 py-1.5 text-xs font-medium text-zinc-400">
                  {React.string(provider.name)}
                </Select.Label>
                {provider.models
                ->Array.map(model => {
                  // Combine provider:value for unique identification
                  let combinedValue = `${provider.id}:${model.value}`
                  <Select.Item
                    key={combinedValue}
                    value={combinedValue}
                    className="relative flex items-center px-2 py-1.5 text-xs text-zinc-200 rounded
                               cursor-pointer select-none outline-none
                               data-[highlighted]:bg-zinc-700 data-[highlighted]:text-white
                               data-[disabled]:opacity-50 data-[disabled]:pointer-events-none">
                    <Select.ItemText> {React.string(model.displayName)} </Select.ItemText>
                  </Select.Item>
                })
                ->React.array}
              </Select.Group>
            })
            ->React.array}
          </Select.Viewport>
        </Select.Content>
      </Select.Portal>
    </Select.Root>
  }
}

// Submit button
module SubmitButton = {
  @react.component
  let make = (~disabled: bool, ~onClick: unit => unit) => {
    <button
      type_="submit"
      disabled
      onClick={e => {
        ReactEvent.Mouse.preventDefault(e)
        onClick()
      }}
      className="flex items-center justify-center w-8 h-8 rounded-md
                 text-white transition-colors
                 bg-blue-600 hover:bg-blue-500 disabled:bg-zinc-700
                 disabled:opacity-50 disabled:cursor-not-allowed"
    >
      <Icons.SendIcon size=16 />
    </button>
  }
}

// Isolated textarea - owns value state to prevent parent re-renders on keystrokes
module TextInput = {
  @react.component
  let make = (
    ~onSubmit: string => unit,
    ~onHasContentChange: bool => unit,
    ~submitRef: React.ref<option<unit => unit>>,
    ~disabled: bool,
    ~canSubmit: bool,
    ~hasAttachments: bool,
    ~placeholder: string,
  ) => {
    let (value, setValue) = React.useState(() => "")
    let textareaRef = React.useRef(Nullable.null)

    // Keep submitRef updated so the external submit button can trigger submit
    let doSubmit = () => {
      if canSubmit && (value != "" || hasAttachments) {
        onSubmit(value)
        setValue(_ => "")
        onHasContentChange(false)
      }
    }
    submitRef.current = Some(doSubmit)

    let handleChange = (e: ReactEvent.Form.t) => {
      let target = ReactEvent.Form.target(e)
      let newValue: string = target["value"]
      let wasEmpty = value == ""
      let isEmpty = newValue == ""
      setValue(_ => newValue)
      // Only notify parent on empty↔non-empty transitions
      if wasEmpty && !isEmpty {
        onHasContentChange(true)
      } else if !wasEmpty && isEmpty {
        onHasContentChange(false)
      }
    }

    let handleKeyDown = (e: ReactEvent.Keyboard.t) => {
      let key = e->ReactEvent.Keyboard.key
      let shiftKey = e->ReactEvent.Keyboard.shiftKey
      if key == "Enter" && !shiftKey {
        ReactEvent.Keyboard.preventDefault(e)
        doSubmit()
      }
    }

    <div className="p-2">
      <textarea
        ref={ReactDOM.Ref.domRef(textareaRef)}
        value
        disabled
        onChange={handleChange}
        onKeyDown={handleKeyDown}
        placeholder
        rows=1
        className={[
          "w-full min-h-[40px] max-h-[200px] px-3 py-2",
          "bg-zinc-800 border border-zinc-700 rounded-lg",
          "text-sm text-zinc-200 placeholder-zinc-500",
          "resize-none overflow-y-auto",
          "focus:outline-none focus:ring-1 focus:ring-blue-500/50 focus:border-blue-500/50",
          "field-sizing-content",
          if disabled { "opacity-60 cursor-not-allowed" } else { "" },
        ]->Array.filter(c => c != "")->Array.join(" ")}
      />
    </div>
  }
}

// Main component
@react.component
let make = (
  ~onSubmit: string => unit,
  ~providers: array<StateTypes.providerConfig>,
  ~selectedModel: option<StateTypes.selectedModel>,
  ~onModelChange: (~provider: string, ~value: string) => unit,
  ~isAgentRunning: bool,
  ~hasActiveACPSession: bool,
  ~placeholder: string="What would you like to change?",
  ~disabled: bool=false,
  ~disabledPlaceholder: option<string>=?,
) => {
  let (hasTextContent, setHasTextContent) = React.useState(() => false)
  let (attachments, setAttachments) = React.useState(() => [])
  let (isDragging, setIsDragging) = React.useState(() => false)
  let fileInputRef = React.useRef(Nullable.null)
  let submitRef: React.ref<option<unit => unit>> = React.useRef(None)
  
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
  
  // Submit handler passed to TextInput - also clears attachments
  let handleTextSubmit = (text: string) => {
    onSubmit(text)
    setAttachments(_ => [])
  }

  // Button submit triggers TextInput's submit via ref
  let handleButtonSubmit = () => {
    submitRef.current->Option.forEach(fn => fn())
  }

  let hasContent = hasTextContent || Array.length(attachments) > 0
  let isInputDisabled = !hasActiveACPSession || isAgentRunning || disabled
  let isSubmitDisabled = isInputDisabled || !hasContent
  
  // Determine placeholder text based on state
  let currentPlaceholder = if disabled {
    disabledPlaceholder->Option.getOr("Input disabled")
  } else if isAgentRunning {
    "Waiting for response..."
  } else {
    placeholder
  }
  
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
    
    // Input area - isolated component to prevent parent re-renders on keystrokes
    <TextInput
      onSubmit={handleTextSubmit}
      onHasContentChange={v => setHasTextContent(_ => v)}
      submitRef
      disabled={isInputDisabled}
      canSubmit={!isAgentRunning && hasActiveACPSession}
      hasAttachments={Array.length(attachments) > 0}
      placeholder={currentPlaceholder}
    />
    
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
        
        // Model selector - only show if we have providers
        {Array.length(providers) > 0
          ? <ModelSelector
              providers
              selectedValue={selectedModel
                ->Option.map(m => `${m.provider}:${m.value}`)
                ->Option.getOr("")}
              onModelChange
            />
          : React.null}
      </div>
      
      <SubmitButton disabled={isSubmitDisabled} onClick={handleButtonSubmit} />
    </div>
  </div>
}

