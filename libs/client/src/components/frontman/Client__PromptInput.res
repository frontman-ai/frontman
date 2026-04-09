/**
 * Client__PromptInput - Main chat input component
 * 
 * Features:
 * - Text input with auto-resize
 * - File/image attachments with drag-drop, paste, file picker
 * - Multi-line paste collapse (3+ lines or >150 chars) as inline chips
 * - Chips inserted at cursor position (opencode-style inline UX)
 * - Inline thumbnail previews with lightbox
 * - 10MB file size limit
 * - Model selector
 * - Submit button with status
 */
module Icons = Client__ToolIcons

// ============================================================================
// Types
// ============================================================================

// Accepted file types
let acceptedImageTypes = ["image/png", "image/jpeg", "image/gif", "image/webp"]
let acceptedFileTypes = Array.concat(acceptedImageTypes, ["application/pdf"])
let acceptedTypesString = acceptedFileTypes->Array.join(",")
let maxFileSizeBytes = 10 * 1024 * 1024 // 10MB

// Unified input item type
type inputItem =
  | FileAttachment({id: string, name: string, mediaType: string, dataUrl: string})
  | PastedText({id: string, text: string, lineCount: int})

let getItemId = (item: inputItem): string =>
  switch item {
  | FileAttachment({id}) | PastedText({id}) => id
  }

// Generate unique ID
let generateId: unit => string = %raw(`
  function() {
    return 'att_' + Math.random().toString(36).substr(2, 9);
  }
`)

// Read a File as a dataURL (base64), resolves the promise with the dataURL string
let readFileAsDataURL: WebAPI.FileAPI.file => promise<string> = %raw(`
  function(file) {
    return new Promise(function(resolve, reject) {
      var reader = new FileReader();
      reader.onload = function() { resolve(reader.result); };
      reader.onerror = function() { reject(new Error('Failed to read file')); };
      reader.readAsDataURL(file);
    });
  }
`)

// Get files from a DataTransfer (drop event)
let getDataTransferFiles: {..} => array<WebAPI.FileAPI.file> = %raw(`
  function(dataTransfer) {
    return Array.from(dataTransfer.files || []);
  }
`)

// Get clipboard items as files
let getClipboardFiles: {..} => array<WebAPI.FileAPI.file> = %raw(`
  function(clipboardData) {
    var files = [];
    var items = clipboardData.items;
    if (!items) return files;
    for (var i = 0; i < items.length; i++) {
      if (items[i].kind === 'file') {
        var file = items[i].getAsFile();
        if (file) files.push(file);
      }
    }
    return files;
  }
`)

// Get clipboard plain text
let getClipboardText: {..} => string = %raw(`
  function(clipboardData) {
    return clipboardData.getData('text/plain') || '';
  }
`)

// Count lines in text
let countLines = (text: string): int => {
  let lines = text->String.split("\n")
  Array.length(lines)
}

// ============================================================================
// ContentEditable helpers (raw JS for DOM manipulation)
// ============================================================================

// Insert a DOM node at the current cursor position in a contentEditable
let insertNodeAtCursor: WebAPI.DOMAPI.node => unit = %raw(`
  function(node) {
    var sel = window.getSelection();
    if (!sel || sel.rangeCount === 0) return;
    var range = sel.getRangeAt(0);
    range.deleteContents();
    range.insertNode(node);
    // Move cursor after the inserted node
    range.setStartAfter(node);
    range.setEndAfter(node);
    sel.removeAllRanges();
    sel.addRange(range);
  }
`)

// Create an inline chip DOM element for a file attachment
let createFileChipElement: (string, string, string, bool) => WebAPI.DOMAPI.node = %raw(`
  function(id, name, mediaType, isImage) {
    var chip = document.createElement('span');
    chip.setAttribute('contenteditable', 'false');
    chip.setAttribute('data-chip-id', id);
    chip.setAttribute('data-chip-type', 'file');
    chip.className = 'inline-flex items-center gap-1 mx-0.5 px-2 py-0.5 rounded-md bg-violet-900/60 border border-violet-600/50 text-violet-200 text-xs align-middle cursor-default select-none';
    
    if (isImage) {
      var icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      icon.setAttribute('width', '12');
      icon.setAttribute('height', '12');
      icon.setAttribute('viewBox', '0 0 24 24');
      icon.setAttribute('fill', 'none');
      icon.setAttribute('stroke', 'currentColor');
      icon.setAttribute('stroke-width', '2');
      icon.setAttribute('class', 'flex-shrink-0');
      var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', 'M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z');
      icon.appendChild(path);
      chip.appendChild(icon);
    }
    
    var label = document.createElement('span');
    // Truncate long filenames
    var displayName = name.length > 20 ? name.substring(0, 17) + '...' : name;
    label.textContent = displayName;
    chip.appendChild(label);
    
    // Remove button (x)
    var removeBtn = document.createElement('span');
    removeBtn.className = 'ml-0.5 cursor-pointer hover:text-red-300 text-violet-400';
    removeBtn.textContent = '×';
    removeBtn.setAttribute('data-remove-chip', id);
    chip.appendChild(removeBtn);
    
    return chip;
  }
`)

// Create an inline chip DOM element for pasted text
let createPastedTextChipElement: (string, int) => WebAPI.DOMAPI.node = %raw(`
  function(id, lineCount) {
    var chip = document.createElement('span');
    chip.setAttribute('contenteditable', 'false');
    chip.setAttribute('data-chip-id', id);
    chip.setAttribute('data-chip-type', 'paste');
    chip.className = 'inline-flex items-center gap-1 mx-0.5 px-2 py-0.5 rounded-md bg-violet-900/60 border border-violet-600/50 text-violet-200 text-xs align-middle cursor-default select-none';
    
    // Clipboard icon
    var icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    icon.setAttribute('width', '12');
    icon.setAttribute('height', '12');
    icon.setAttribute('viewBox', '0 0 24 24');
    icon.setAttribute('fill', 'none');
    icon.setAttribute('stroke', 'currentColor');
    icon.setAttribute('stroke-width', '2');
    icon.setAttribute('class', 'flex-shrink-0');
    var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', 'M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2');
    icon.appendChild(path);
    chip.appendChild(icon);
    
    var label = document.createElement('span');
    label.textContent = 'Pasted ~' + lineCount + ' lines';
    chip.appendChild(label);
    
    // Remove button (x)
    var removeBtn = document.createElement('span');
    removeBtn.className = 'ml-0.5 cursor-pointer hover:text-red-300 text-violet-400';
    removeBtn.textContent = '×';
    removeBtn.setAttribute('data-remove-chip', id);
    chip.appendChild(removeBtn);
    
    return chip;
  }
`)

// Extract text content (without chips) from contentEditable
// Properly recurses into block elements while skipping chip nodes
let getTextFromEditable: Dom.element => string = %raw(`
  function getTextFromEditable(el) {
    var text = '';
    var nodes = el.childNodes;
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (node.nodeType === 3) {
        text += node.textContent;
      } else if (node.nodeType === 1) {
        if (node.getAttribute && node.getAttribute('data-chip-id')) {
          continue;
        } else if (node.tagName === 'BR') {
          text += '\n';
        } else {
          if (i > 0 && (node.tagName === 'DIV' || node.tagName === 'P')) {
            text += '\n';
          }
          // Recurse into child nodes to skip nested chips
          text += getTextFromEditable(node);
        }
      }
    }
    return text;
  }
`)

// Extract text from contentEditable with pasted-text chips expanded inline
// Walks DOM nodes in order: text nodes become text, pasted-text chips are replaced
// with their full content from the provided Map, file chips are skipped.
// This preserves the user's intended ordering of typed text and pasted content.
let getExpandedTextFromEditable: (Dom.element, Map.t<string, string>) => string = %raw(`
  function getExpandedTextFromEditable(el, itemsMap) {
    var text = '';
    var nodes = el.childNodes;
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (node.nodeType === 3) {
        text += node.textContent;
      } else if (node.nodeType === 1) {
        var chipId = node.getAttribute && node.getAttribute('data-chip-id');
        if (chipId) {
          var chipType = node.getAttribute('data-chip-type');
          if (chipType === 'paste' && itemsMap.has(chipId)) {
            text += itemsMap.get(chipId);
          }
          // file chips are skipped — handled separately as fileParts
        } else if (node.tagName === 'BR') {
          text += '\n';
        } else {
          if (i > 0 && (node.tagName === 'DIV' || node.tagName === 'P')) {
            text += '\n';
          }
          text += getExpandedTextFromEditable(node, itemsMap);
        }
      }
    }
    return text;
  }
`)

// Get all chip IDs from contentEditable
let getChipIdsFromEditable: Dom.element => array<string> = %raw(`
  function(el) {
    var chips = el.querySelectorAll('[data-chip-id]');
    return Array.from(chips).map(function(c) { return c.getAttribute('data-chip-id'); });
  }
`)

// Clear contentEditable content
let clearEditable: Dom.element => unit = %raw(`
  function(el) {
    el.innerHTML = '';
  }
`)

// Check if contentEditable is visually empty (no text, no chips)
let isEditableEmpty: Dom.element => bool = %raw(`
  function(el) {
    // Check if there are any chip elements
    if (el.querySelector('[data-chip-id]')) return false;
    // Check text content
    var text = el.textContent || '';
    return text.trim() === '';
  }
`)

// Focus the contentEditable and place cursor at end
let focusAtEnd: Dom.element => unit = %raw(`
  function(el) {
    el.focus();
    var sel = window.getSelection();
    if (sel) {
      var range = document.createRange();
      range.selectNodeContents(el);
      range.collapse(false);
      sel.removeAllRanges();
      sel.addRange(range);
    }
  }
`)

// ============================================================================
// Sub-components
// ============================================================================

// Model selector dropdown - consumes ACP SessionConfigOption (type: "select")
// Uses Radix UI Select for consistent dark theme styling across all platforms (including Linux)
module ModelSelector = {
  module Select = Bindings__RadixUI__Select
  module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

  // Get the display name for the currently selected value from config option
  let _getSelectedDisplay = (configOption: ACP.sessionConfigOption, selectedValue: string): option<
    string,
  > => {
    switch configOption {
    | ACP.SelectConfigOption({options}) =>
      switch options {
      | ACP.Grouped(groups) =>
        groups->Array.findMap(group =>
          group.options->Array.findMap(opt =>
            switch opt.value == selectedValue {
            | true => Some(opt.name)
            | false => None
            }
          )
        )
      | ACP.Ungrouped(opts) =>
        opts->Array.findMap(opt =>
          switch opt.value == selectedValue {
          | true => Some(opt.name)
          | false => None
          }
        )
      }
    }
  }

  @react.component
  let make = (
    ~configOption: ACP.sessionConfigOption,
    ~selectedValue: string,
    ~onModelChange: string => unit,
  ) => {
    let selectedDisplay = React.useMemo2(
      () => _getSelectedDisplay(configOption, selectedValue),
      (configOption, selectedValue),
    )

    <Select.Root value={selectedValue} onValueChange={value => onModelChange(value)}>
      <Select.Trigger
        className="inline-flex items-center gap-1 h-8 pl-2 pr-1.5 text-xs rounded-md
                   bg-transparent text-zinc-400 border-none cursor-pointer
                   hover:text-zinc-200 hover:bg-white/6
                   focus:outline-none focus:ring-0
                   data-[placeholder]:text-zinc-500"
      >
        <span className="truncate max-w-[120px]">
          {React.string(selectedDisplay->Option.getOr("Select model..."))}
        </span>
        <Select.Icon className="text-zinc-400 flex-shrink-0">
          <Icons.ChevronDownIcon size=12 />
        </Select.Icon>
      </Select.Trigger>
      <Select.Portal>
        <Select.Content
          position=#popper
          sideOffset=4
          className="z-50 min-w-[180px] max-h-[300px] overflow-hidden
                     bg-zinc-800 border border-zinc-700 rounded-lg shadow-xl
                     animate-in fade-in-0 zoom-in-95"
        >
          <Select.Viewport className="p-1">
            {switch configOption {
            | ACP.SelectConfigOption({options}) =>
              switch options {
              | ACP.Grouped(groups) =>
                groups
                ->Array.map(group => {
                  <Select.Group key={group.group}>
                    <Select.Label className="px-2 py-1.5 text-xs font-medium text-zinc-400">
                      {React.string(group.name)}
                    </Select.Label>
                    {group.options
                    ->Array.map(opt => {
                      <Select.Item
                        key={opt.value}
                        value={opt.value}
                        className="relative flex items-center px-2 py-1.5 text-xs text-zinc-200 rounded
                                   cursor-pointer select-none outline-none
                                   data-[highlighted]:bg-zinc-700 data-[highlighted]:text-white
                                   data-[disabled]:opacity-50 data-[disabled]:pointer-events-none"
                      >
                        <Select.ItemText> {React.string(opt.name)} </Select.ItemText>
                      </Select.Item>
                    })
                    ->React.array}
                  </Select.Group>
                })
                ->React.array
              | ACP.Ungrouped(opts) =>
                opts
                ->Array.map(opt => {
                  <Select.Item
                    key={opt.value}
                    value={opt.value}
                    className="relative flex items-center px-2 py-1.5 text-xs text-zinc-200 rounded
                               cursor-pointer select-none outline-none
                               data-[highlighted]:bg-zinc-700 data-[highlighted]:text-white
                               data-[disabled]:opacity-50 data-[disabled]:pointer-events-none"
                  >
                    <Select.ItemText> {React.string(opt.name)} </Select.ItemText>
                  </Select.Item>
                })
                ->React.array
              }
            }}
          </Select.Viewport>
        </Select.Content>
      </Select.Portal>
    </Select.Root>
  }
}

module RadixUI__Icons = Bindings__RadixUI__Icons

// Select element button — three visual states:
// resting: zinc, label visible
// selecting: violet pulse dot, shows "Selecting…"
// has-annotations (isSelecting=false but hasAnnotations=true): zinc-200 with active dot
module SelectElementButton = {
  @react.component
  let make = (
    ~onClick: unit => unit,
    ~isSelecting: bool,
    ~hasAnnotations: bool,
    ~showLabel: bool,
  ) => {
    let (extraClass, iconClass) = switch (isSelecting, hasAnnotations) {
    | (true, _) => ("text-violet-300 bg-violet-600/20 hover:bg-violet-600/30", "text-violet-300")
    | (false, true) => ("text-zinc-200 hover:bg-white/6", "text-zinc-200")
    | (false, false) => ("text-zinc-400 hover:text-zinc-200 hover:bg-white/6", "text-zinc-400")
    }

    <button
      type_="button"
      onClick={_ => onClick()}
      className={`inline-flex items-center gap-1.5 h-8 px-2.5 rounded-md text-xs font-medium
                 transition-colors cursor-pointer ${extraClass}`}
      title={isSelecting ? "Cancel selection" : "Select an element in the preview"}
    >
      {switch isSelecting {
      | true =>
        <span className="w-1.5 h-1.5 rounded-full bg-violet-400 animate-pulse flex-shrink-0" />
      | false => <Icons.CursorClickIcon size=13 className={iconClass} />
      }}
      {showLabel
        ? <span className="whitespace-nowrap">
            {React.string(isSelecting ? "Selecting\u{2026}" : "Select")}
          </span>
        : React.null}
      {switch (isSelecting, hasAnnotations) {
      | (false, true) =>
        <span
          className="w-1.5 h-1.5 rounded-full bg-violet-400 flex-shrink-0" title="Element selected"
        />
      | _ => React.null
      }}
    </button>
  }
}

// Overflow button — ··· trigger revealing the model selector in a panel above the toolbar
module OverflowButton = {
  @react.component
  let make = (
    ~modelConfigOption: option<
      FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionConfigOption,
    >,
    ~isModelsConfigLoading: bool,
    ~selectedModelValue: option<
      FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionConfigValueId,
    >,
    ~onModelChange: string => unit,
  ) => {
    let (isOpen, setIsOpen) = React.useState(() => false)

    <div className="relative flex-shrink-0">
      <button
        type_="button"
        onClick={_ => setIsOpen(prev => !prev)}
        className="inline-flex items-center justify-center w-8 h-8 rounded-md
                   text-zinc-400 hover:text-zinc-200 hover:bg-white/6
                   transition-colors cursor-pointer"
        title="More options"
      >
        <span className="flex gap-[3px] items-center">
          <span className="w-1 h-1 rounded-full bg-current" />
          <span className="w-1 h-1 rounded-full bg-current" />
          <span className="w-1 h-1 rounded-full bg-current" />
        </span>
      </button>
      {isOpen
        ? <div
            className="absolute bottom-10 left-0 z-50 min-w-[180px]
                       bg-zinc-900 border border-white/10 rounded-lg shadow-xl p-2"
          >
            <div className="text-[10px] text-zinc-500 px-2 pb-1 uppercase tracking-wide">
              {React.string("Model")}
            </div>
            {switch (isModelsConfigLoading, modelConfigOption) {
            | (true, _) =>
              <div className="px-2 py-1 text-xs text-zinc-500"> {React.string("Loading...")} </div>
            | (false, Some(configOption)) =>
              <div className="w-full">
                <ModelSelector
                  configOption
                  selectedValue={selectedModelValue->Option.getOr("")}
                  onModelChange={v => {
                    onModelChange(v)
                    setIsOpen(_ => false)
                  }}
                />
              </div>
            | (false, None) => React.null
            }}
          </div>
        : React.null}
    </div>
  }
}

// Stop icon - square for cancel button
module StopIcon = {
  @react.component
  let make = (~size: int=16) => {
    <svg
      width={Int.toString(size)}
      height={Int.toString(size)}
      viewBox="0 0 24 24"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
    >
      <rect x="6" y="6" width="12" height="12" rx="2" />
    </svg>
  }
}

// Submit/Stop button — Send is the sole purple element at rest; Stop becomes a pill with label
module SubmitButton = {
  @react.component
  let make = (
    ~disabled: bool,
    ~isAgentRunning: bool,
    ~onClick: unit => unit,
    ~onCancel: unit => unit,
  ) => {
    if isAgentRunning {
      // Stop — pill with text label, feels different from compose mode
      <button
        type_="button"
        onClick={e => {
          ReactEvent.Mouse.preventDefault(e)
          onCancel()
        }}
        className="inline-flex items-center gap-2 h-8 px-4 rounded-full
                   bg-[#985DF7] hover:bg-[#8247E5] text-white text-xs font-medium
                   transition-all hover:scale-105 cursor-pointer"
        title="Stop generation"
      >
        <StopIcon size=12 />
        <span> {React.string("Stop")} </span>
      </button>
    } else {
      // Send — circle, the only purple element in the composition surface
      <button
        type_="submit"
        disabled
        onClick={e => {
          ReactEvent.Mouse.preventDefault(e)
          onClick()
        }}
        className="flex items-center justify-center w-8 h-8 rounded-full
                   transition-all text-white cursor-pointer
                   bg-[#985DF7] hover:bg-[#8247E5] hover:scale-105
                   disabled:bg-zinc-700/50 disabled:text-zinc-500 disabled:cursor-not-allowed disabled:scale-100"
        title="Send (Enter)"
      >
        <Icons.SendArrowIcon size=14 />
      </button>
    }
  }
}

// ============================================================================
// Main component
// ============================================================================
@react.component
let make = (
  ~onSubmit: (~text: string, ~inputItems: array<inputItem>) => unit,
  ~onCancel: unit => unit,
  ~modelConfigOption: option<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionConfigOption>,
  ~isModelsConfigLoading: bool,
  ~selectedModelValue: option<
    FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionConfigValueId,
  >,
  ~onModelChange: string => unit,
  ~isAgentRunning: bool,
  ~hasActiveACPSession: bool,
  ~placeholder: string="What would you like to change?",
  ~disabled: bool=false,
  ~disabledPlaceholder: option<string>=?,
  ~onSelectElement: option<unit => unit>=?,
  ~isSelecting: bool=false,
  ~hasAnnotations: bool=false,
  ~isEnrichingAnnotations: bool=false,
) => {
  let (hasContent, setHasContent) = React.useState(() => false)
  let (inputItems, setInputItems) = React.useState((): array<inputItem> => [])
  let (isDragging, setIsDragging) = React.useState(() => false)
  let (previewSrc, setPreviewSrc) = React.useState((): option<string> => None)
  let (fileSizeError, setFileSizeError) = React.useState((): option<string> => None)
  // showSelectLabel: true when toolbar is wide enough to show the "Select" text label
  let (showSelectLabel, setShowSelectLabel) = React.useState(() => true)
  let fileInputRef = React.useRef(Nullable.null)
  let editableRef = React.useRef(Nullable.null)
  let formRef = React.useRef(Nullable.null)
  // Ref to hold the latest inputItems so callbacks always see current value
  let itemsRef: React.ref<array<inputItem>> = React.useRef([])

  // Keep itemsRef in sync
  React.useEffect1(() => {
    itemsRef.current = inputItems
    None
  }, [inputItems])

  // Update hasContent when inputItems or text changes
  let syncHasContent = () => {
    editableRef.current
    ->Nullable.toOption
    ->Option.forEach(el => {
      let empty = isEditableEmpty(el)
      setHasContent(_ => !empty)
    })
  }

  // Debounced version for the hot input path — avoids triggering a React
  // re-render on every single keystroke just to toggle placeholder/submit state.
  let syncHasContentTimerRef = React.useRef(None)
  let syncHasContentDebounced = () => {
    switch syncHasContentTimerRef.current {
    | Some(id) => clearTimeout(id)
    | None => ()
    }
    syncHasContentTimerRef.current = Some(setTimeout(() => {
        syncHasContentTimerRef.current = None
        syncHasContent()
      }, 100))
  }

  // Cleanup debounce timer on unmount
  React.useEffect0(() => {
    Some(
      () => {
        switch syncHasContentTimerRef.current {
        | Some(id) => clearTimeout(id)
        | None => ()
        }
      },
    )
  })

  // ResizeObserver: hide "Select" label when toolbar is too narrow
  let _setupResizeObserver: (Dom.element, bool => unit) => unit => unit = %raw(`
    function(el, setShowLabel) {
      var LABEL_THRESHOLD = 300;
      var ro = new ResizeObserver(function(entries) {
        var width = entries[0].contentRect.width;
        setShowLabel(width >= LABEL_THRESHOLD);
      });
      ro.observe(el);
      return function() { ro.disconnect(); };
    }
  `)

  React.useEffect0(() => {
    formRef.current
    ->Nullable.toOption
    ->Option.map(el => _setupResizeObserver(el, v => setShowSelectLabel(_ => v)))
  })

  // Clear file size error after 3 seconds
  React.useEffect1(() => {
    switch fileSizeError {
    | Some(_) =>
      let timeoutId = setTimeout(() => setFileSizeError(_ => None), 3000)
      Some(() => clearTimeout(timeoutId))
    | None => None
    }
  }, [fileSizeError])

  // Handle adding files (validates type + size, reads as dataURL)
  let addFiles = (files: array<WebAPI.FileAPI.file>) => {
    files->Array.forEach(file => {
      let isAccepted = acceptedFileTypes->Array.some(t => t == file.type_)
      if !isAccepted {
        () // silently ignore unsupported file types
      } else if file.size > maxFileSizeBytes {
        setFileSizeError(_ => Some(`${file.name} exceeds 10MB limit`))
      } else {
        let _ = readFileAsDataURL(file)->Promise.then(dataUrl => {
          let id = generateId()
          let isImage = acceptedImageTypes->Array.some(t => t == file.type_)
          let newItem = FileAttachment({
            id,
            name: file.name,
            mediaType: file.type_,
            dataUrl,
          })
          setInputItems(prev => Array.concat(prev, [newItem]))

          // Insert chip at cursor position in the editable
          editableRef.current
          ->Nullable.toOption
          ->Option.forEach(
            el => {
              let chipEl = createFileChipElement(id, file.name, file.type_, isImage)
              // Ensure editable is focused before inserting
              focusAtEnd(el)
              insertNodeAtCursor(chipEl)
              syncHasContent()
            },
          )

          Promise.resolve()
        })
      }
    })
  }

  // Remove a chip from DOM and from inputItems state
  let removeChip = (id: string) => {
    setInputItems(prev => prev->Array.filter(item => getItemId(item) != id))
    // Remove chip element from DOM
    editableRef.current
    ->Nullable.toOption
    ->Option.forEach(el => {
      let removeChipFromDom: (Dom.element, string) => unit = %raw(`
        function(el, id) {
          var chip = el.querySelector('[data-chip-id="' + id + '"]');
          if (chip) chip.remove();
        }
      `)
      removeChipFromDom(el, id)
      syncHasContent()
    })
  }

  // Handle clicks inside the editable (for chip remove buttons and image preview)
  let _getRemoveChipId: ({..}, 'a) => Nullable.t<string> = %raw(`
    function(target, _e) {
      return target.getAttribute ? target.getAttribute('data-remove-chip') : null;
    }
  `)

  let _findChipElement: ({..}, ReactEvent.Mouse.t) => Nullable.t<{..}> = %raw(`
    function(target, e) {
      var el = target;
      while (el && el !== e.currentTarget) {
        if (el.getAttribute && el.getAttribute('data-chip-id') && el.getAttribute('data-chip-type') === 'file') {
          return el;
        }
        el = el.parentElement;
      }
      return null;
    }
  `)

  let handleEditableClick = (e: ReactEvent.Mouse.t) => {
    let target: {..} = ReactEvent.Mouse.target(e)->Obj.magic
    // Check for remove button clicks (target may be a text node without getAttribute)
    let removeId: option<string> = _getRemoveChipId(target, e)->Nullable.toOption
    switch removeId {
    | Some(id) =>
      ReactEvent.Mouse.preventDefault(e)
      ReactEvent.Mouse.stopPropagation(e)
      removeChip(id)
    | None =>
      // Check for image chip clicks (for lightbox preview)
      let chipEl: option<{..}> = _findChipElement(target, e)->Nullable.toOption
      chipEl->Option.forEach(chip => {
        let chipId: string = chip["getAttribute"]("data-chip-id")
        // Find the item in inputItems to get the dataUrl
        itemsRef.current->Array.forEach(item => {
          switch item {
          | FileAttachment({id, dataUrl, mediaType}) =>
            if id == chipId && acceptedImageTypes->Array.some(t => t == mediaType) {
              setPreviewSrc(_ => Some(dataUrl))
            }
          | PastedText(_) => ()
          }
        })
      })
    }
  }

  // Handle file input change
  let _getFilesAsArray: {..} => option<array<WebAPI.FileAPI.file>> = %raw(`
    function(target) {
      var fl = target.files;
      return fl ? Array.from(fl) : undefined;
    }
  `)
  let _resetFileInput: {..} => unit = %raw(`function(target) { target.value = ''; }`)

  let handleFileInputChange = (e: ReactEvent.Form.t) => {
    let target = ReactEvent.Form.target(e)
    _getFilesAsArray(target)->Option.forEach(f => addFiles(f))
    _resetFileInput(target)
  }

  // Drag event handlers
  let handleDragOver = (e: ReactEvent.Mouse.t) => {
    ReactEvent.Mouse.preventDefault(e)
    setIsDragging(_ => true)
  }

  let handleDragLeave = (e: ReactEvent.Mouse.t) => {
    ReactEvent.Mouse.preventDefault(e)
    let relatedTarget: option<{..}> = (e->Obj.magic)["relatedTarget"]
    switch relatedTarget {
    | None => setIsDragging(_ => false)
    | Some(target) =>
      formRef.current
      ->Nullable.toOption
      ->Option.forEach(formEl => {
        let contains: (
          Dom.element,
          {..},
        ) => bool = %raw(`function(el, target) { return el.contains(target); }`)
        if !contains(formEl, target) {
          setIsDragging(_ => false)
        }
      })
    }
  }

  let handleDrop = (e: ReactEvent.Mouse.t) => {
    ReactEvent.Mouse.preventDefault(e)
    setIsDragging(_ => false)
    let dataTransfer: {..} = (e->Obj.magic)["dataTransfer"]
    let files = getDataTransferFiles(dataTransfer)
    addFiles(files)
  }

  // Paste handler - handles image paste and multi-line text collapse
  let handlePaste = (e: ReactEvent.Clipboard.t) => {
    let clipboardData: {..} = (e->Obj.magic)["clipboardData"]

    // Check for file items first (images/PDFs)
    let files = getClipboardFiles(clipboardData)
    let acceptedFiles =
      files->Array.filter(file => acceptedFileTypes->Array.some(t => t == file.type_))
    let text = getClipboardText(clipboardData)
    let lineCount = countLines(text)
    let charCount = String.length(text)
    let isLongTextPaste = lineCount >= 3 || charCount > 150

    switch (Array.length(acceptedFiles) > 0, text, isLongTextPaste) {
    | (true, _, _) =>
      ReactEvent.Clipboard.preventDefault(e)
      addFiles(acceptedFiles)
    | (false, "", _) => ()
    | (false, _, true) =>
      ReactEvent.Clipboard.preventDefault(e)
      let id = generateId()
      let newItem = PastedText({
        id,
        text,
        lineCount,
      })
      setInputItems(prev => Array.concat(prev, [newItem]))

      // Insert chip at cursor position
      editableRef.current
      ->Nullable.toOption
      ->Option.forEach(_el => {
        let chipEl = createPastedTextChipElement(id, lineCount)
        insertNodeAtCursor(chipEl)
        syncHasContent()
      })
    | (false, _, false) =>
      ReactEvent.Clipboard.preventDefault(e)
      insertNodeAtCursor(
        WebAPI.Global.document->WebAPI.Document.createTextNode(text)->WebAPI.Text.asNode,
      )
      syncHasContent()
    }
  }

  // Handle input events (contenteditable fires 'input' on text changes)
  let handleInput = (_e: ReactEvent.Form.t) => {
    syncHasContentDebounced()
    // Sync inputItems with DOM - remove items whose chips no longer exist
    editableRef.current
    ->Nullable.toOption
    ->Option.forEach(el => {
      let domChipIds = getChipIdsFromEditable(el)
      setInputItems(prev => {
        let filtered =
          prev->Array.filter(item => domChipIds->Array.some(id => id == getItemId(item)))
        if Array.length(filtered) != Array.length(prev) {
          filtered
        } else {
          prev
        }
      })
    })
  }

  // Submit logic
  let doSubmit = () => {
    editableRef.current
    ->Nullable.toOption
    ->Option.forEach(el => {
      let items = itemsRef.current
      // Build a Map of pasted-text chip id → text for inline expansion
      let pastedTextMap = Map.make()
      items->Array.forEach(item =>
        switch item {
        | PastedText({id, text: pastedText}) => pastedTextMap->Map.set(id, pastedText)
        | FileAttachment(_) => ()
        }
      )
      // Walk the DOM in order, expanding pasted-text chips inline at their position
      let text = getExpandedTextFromEditable(el, pastedTextMap)
      if String.trim(text) != "" || Array.length(items) > 0 || hasAnnotations {
        onSubmit(~text=String.trim(text), ~inputItems=items)
        clearEditable(el)
        setInputItems(_ => [])
        setHasContent(_ => false)
      }
    })
  }

  let isInputDisabled = !hasActiveACPSession || isAgentRunning || disabled
  let isSubmitDisabled = isInputDisabled || !hasContent && !hasAnnotations || isEnrichingAnnotations

  // Handle keydown in contentEditable.
  // Gates on isInputDisabled and isEnrichingAnnotations but NOT on hasContent —
  // hasContent is updated via a 100ms debounce and may be stale when Enter fires
  // immediately after typing. doSubmit() reads the DOM directly to decide whether
  // there's content to send, so the content check is handled there.
  let handleKeyDown = (e: ReactEvent.Keyboard.t) => {
    let key = e->ReactEvent.Keyboard.key
    let shiftKey = e->ReactEvent.Keyboard.shiftKey
    if key == "Enter" && !shiftKey {
      ReactEvent.Keyboard.preventDefault(e)
      if !isInputDisabled && !isEnrichingAnnotations {
        doSubmit()
      }
    }
  }

  // Determine placeholder text based on state
  let currentPlaceholder = if disabled {
    disabledPlaceholder->Option.getOr("Input disabled")
  } else if isAgentRunning {
    "Waiting for response..."
  } else {
    placeholder
  }

  <div
    ref={ReactDOM.Ref.domRef(formRef)}
    className={`bg-[#130d20] relative shrink-0 ${isDragging
        ? "ring-2 ring-white/20 ring-inset"
        : ""}`}
    onDragOver={handleDragOver}
    onDragLeave={handleDragLeave}
    onDrop={handleDrop}
  >
    // Drag overlay
    {isDragging
      ? <div
          className="absolute inset-0 z-20 flex items-center justify-center
                     bg-[#130d20]/90 border-2 border-dashed border-violet-500/60 rounded-lg
                     pointer-events-none"
        >
          <div className="flex flex-col items-center gap-2 text-violet-300">
            <Icons.UploadIcon size=32 />
            <span className="text-sm font-medium"> {React.string("Drop files here")} </span>
            <span className="text-xs text-violet-400">
              {React.string("Images and PDFs up to 10MB")}
            </span>
          </div>
        </div>
      : React.null}

    // File size error toast
    {switch fileSizeError {
    | Some(error) =>
      <div className="px-3 pt-2">
        <div
          className="px-3 py-2 rounded-lg bg-red-900/40 border border-red-700/50 text-xs text-red-300"
        >
          {React.string(error)}
        </div>
      </div>
    | None => React.null
    }}

    // ContentEditable input area with inline chips
    <div className="px-3 py-2">
      <div className="relative">
        <div
          ref={ReactDOM.Ref.domRef(editableRef)}
          contentEditable={!isInputDisabled}
          suppressContentEditableWarning=true
          role="textbox"
          onKeyDown={handleKeyDown}
          onPaste={handlePaste}
          onInput={handleInput}
          onClick={handleEditableClick}
          className={[
            "w-full min-h-[48px] max-h-[200px] px-4 py-3",
            "border-b border-white/10",
            "text-sm text-zinc-100",
            "overflow-y-auto",
            "focus:outline-none",
            "whitespace-pre-wrap break-words",
            if isInputDisabled {
              "opacity-60 cursor-not-allowed"
            } else {
              ""
            },
          ]
          ->Array.filter(c => c != "")
          ->Array.join(" ")}
        />
        // Placeholder overlay (shown when contentEditable is empty)
        {!hasContent
          ? <div
              className="absolute top-0 left-0 px-4 py-3 text-sm text-zinc-500 pointer-events-none select-none"
            >
              {React.string(currentPlaceholder)}
            </div>
          : React.null}
      </div>
    </div>

    // Footer with tools and submit — toolbar anchored at bottom, always stable position
    <div className="flex items-center justify-between px-3 pb-2 pt-1">
      <div
        className={`flex items-center gap-1 min-w-0 transition-opacity ${isAgentRunning
            ? "opacity-40 pointer-events-none"
            : ""}`}
      >
        // Select element button (optional)
        {switch onSelectElement {
        | Some(handler) =>
          <SelectElementButton
            onClick={handler}
            isSelecting={isSelecting}
            hasAnnotations={hasAnnotations}
            showLabel={showSelectLabel}
          />
        | None => React.null
        }}

        // Attach button — icon only
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
          className="inline-flex items-center justify-center w-8 h-8 rounded-md flex-shrink-0
                     text-zinc-400 hover:text-zinc-200 hover:bg-white/6
                     transition-colors cursor-pointer"
          title="Attach files (images, PDFs)"
        >
          <Icons.PlusIcon size=15 />
        </button>
        <input
          ref={ReactDOM.Ref.domRef(fileInputRef)}
          type_="file"
          multiple=true
          accept={acceptedTypesString}
          onChange={handleFileInputChange}
          className="hidden"
        />

        // Model selector — shown inline, shrinks when space is tight
        {switch (isModelsConfigLoading, modelConfigOption) {
        | (true, _) =>
          <div
            className="inline-flex items-center gap-1 h-8 px-2 text-xs text-zinc-500 shrink min-w-0"
          >
            <span className="truncate"> {React.string("Loading...")} </span>
          </div>
        | (false, Some(configOption)) =>
          <div className="shrink min-w-0 max-w-[160px]">
            <ModelSelector
              configOption selectedValue={selectedModelValue->Option.getOr("")} onModelChange
            />
          </div>
        | (false, None) => React.null
        }}
      </div>

      // Submit / Stop
      <SubmitButton disabled={isSubmitDisabled} isAgentRunning onClick={doSubmit} onCancel />
    </div>

    // Image lightbox preview
    {switch previewSrc {
    | Some(src) => <Client__ImagePreview src onClose={() => setPreviewSrc(_ => None)} />
    | None => React.null
    }}
  </div>
}
