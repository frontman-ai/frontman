/**
 * UserMessage - Renders user messages (text, images, files, annotations)
 * 
 * Displays user messages in a purple/violet bubble style.
 * Sticky at top when scrolling for context.
 * Images render as thumbnails with lightbox preview.
 * Annotations render as compact chips with numbered badges.
 */

module UserContentPart = Client__State__Types.UserContentPart
module MessageAnnotation = Client__Message.MessageAnnotation

// Circled number characters for annotation badges (1-20)
let _circledNumbers = [
  "\u{2460}", "\u{2461}", "\u{2462}", "\u{2463}", "\u{2464}",
  "\u{2465}", "\u{2466}", "\u{2467}", "\u{2468}", "\u{2469}",
  "\u{246A}", "\u{246B}", "\u{246C}", "\u{246D}", "\u{246E}",
  "\u{246F}", "\u{2470}", "\u{2471}", "\u{2472}", "\u{2473}",
]

let _getBadge = (index: int): string =>
  _circledNumbers->Array.get(index)->Option.getOr(Int.toString(index + 1))

@react.component
let make = (
  ~content: array<UserContentPart.t>,
  ~annotations: array<MessageAnnotation.t>=[],
  ~messageId: string,
  ~isNew: bool=false,
) => {
  let animationClass = isNew ? "animate-in fade-in duration-100" : ""
  let (previewSrc, setPreviewSrc) = React.useState((): option<string> => None)

  // Separate image parts from text parts for layout
  let imageParts = content->Array.filterMap(part =>
    switch part {
    | UserContentPart.Image({image, mediaType, name: _, id: _}) => Some((image, mediaType))
    | _ => None
    }
  )
  let textParts = content->Array.filterMap(part =>
    switch part {
    | UserContentPart.Text({text}) => Some(text)
    | _ => None
    }
  )
  let fileParts = content->Array.filterMap(part =>
    switch part {
    | UserContentPart.File({file}) => Some(file)
    | _ => None
    }
  )

  let hasAnnotations = Array.length(annotations) > 0

  // Sticky container with dark background for proper stacking
  <div className={`sticky top-0 z-10 bg-[#180C2D] py-2 px-3 ${animationClass}`}>
    <div className="inline-block max-w-[85%] bg-violet-600/80 rounded-2xl px-4 py-3">
      // Annotation chips (above images/text)
      {hasAnnotations
        ? <div className="flex flex-wrap gap-1.5 mb-2">
            {annotations->Array.mapWithIndex((annotation, i) => {
              let key = `${messageId}-ann-${Int.toString(i)}`
              let badge = _getBadge(i)
              let label = switch annotation.cssClasses {
              | Some(classes) =>
                let firstClass = classes->String.split(" ")->Array.get(0)->Option.getOr("")
                firstClass->String.length > 0
                  ? `<${annotation.tagName}.${firstClass}>`
                  : `<${annotation.tagName}>`
              | None => `<${annotation.tagName}>`
              }
              <div key className="flex flex-col gap-0.5">
                <div
                  className="flex items-center gap-1 px-2 py-0.5 rounded-md
                             bg-violet-500/60 text-violet-100 text-xs font-mono"
                >
                  <span className="text-violet-200">{React.string(badge)}</span>
                  <span className="truncate max-w-[160px]">{React.string(label)}</span>
                </div>
                {switch annotation.comment {
                | Some(comment) =>
                  <div
                    className="text-[11px] text-violet-200/80 italic pl-1 max-w-[200px] truncate"
                  >
                    {React.string(comment)}
                  </div>
                | None => React.null
                }}
              </div>
            })->React.array}
          </div>
        : React.null}

      // Image thumbnails row (above text)
      {Array.length(imageParts) > 0
        ? <div className="flex flex-wrap gap-2 mb-2">
            {imageParts->Array.mapWithIndex(((src, _mediaType), i) => {
              let key = `${messageId}-img-${Int.toString(i)}`
              let isImage = !(src->String.includes("application/pdf"))
              <div
                key
                className={`w-12 h-12 rounded-lg overflow-hidden border border-white/20
                           transition-colors ${isImage ? "cursor-pointer hover:border-white/50" : ""}`}
                onClick={_ => {
                  if isImage {
                    setPreviewSrc(_ => Some(src))
                  }
                }}
              >
                {isImage
                  ? <img
                      src
                      alt={`Attachment ${Int.toString(i + 1)}`}
                      className="w-full h-full object-cover"
                    />
                  : <div className="w-full h-full flex items-center justify-center bg-violet-700/50 text-violet-200">
                      <Client__ToolIcons.FileIcon size=20 />
                    </div>}
              </div>
            })->React.array}
          </div>
        : React.null}

      // File chips
      {Array.length(fileParts) > 0
        ? <div className="flex flex-wrap gap-1.5 mb-2">
            {fileParts->Array.mapWithIndex((file, i) => {
              let key = `${messageId}-file-${Int.toString(i)}`
              <div
                key
                className="flex items-center gap-1.5 px-2 py-1 rounded-md
                           bg-violet-700/50 text-violet-100 text-xs"
              >
                <Client__ToolIcons.FileIcon size=12 />
                <span className="truncate max-w-[120px]">{React.string(file)}</span>
              </div>
            })->React.array}
          </div>
        : React.null}

      // Text content
      <div className="text-[14px] leading-relaxed text-white font-semibold">
        {textParts->Array.mapWithIndex((text, i) => {
          let key = `${messageId}-text-${Int.toString(i)}`
          <div key className="whitespace-pre-wrap">{React.string(text)}</div>
        })->React.array}
      </div>
    </div>

    // Lightbox preview
    {switch previewSrc {
    | Some(src) =>
      <Client__ImagePreview src onClose={() => setPreviewSrc(_ => None)} />
    | None => React.null
    }}
  </div>
}
