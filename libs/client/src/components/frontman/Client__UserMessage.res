/**
 * UserMessage - Renders user messages (text, images, files)
 * 
 * Displays user messages in a purple/violet bubble style.
 * Sticky at top when scrolling for context.
 */

module UserContentPart = Client__State__Types.UserContentPart

@react.component
let make = (~content: array<UserContentPart.t>, ~messageId: string, ~isNew: bool=false) => {
  let animationClass = isNew ? "animate-in fade-in duration-100" : ""
  
  // Sticky container with dark background for proper stacking
  <div className={`sticky top-0 z-10 bg-[#180C2D] py-2 px-3 ${animationClass}`}>
    <div className="inline-block max-w-[85%] bg-violet-600/80 rounded-2xl px-4 py-3">
      <div className="text-[14px] leading-relaxed text-white font-semibold">
        {content->Array.mapWithIndex((part, i) => {
          let key = `${messageId}-${Int.toString(i)}`
          switch part {
          | UserContentPart.Text({text}) =>
            <div key className="whitespace-pre-wrap">{React.string(text)}</div>
          | UserContentPart.Image({image, mediaType: _}) =>
            <div key className="text-violet-200 text-sm italic">
              {React.string(`[Image: ${image->String.slice(~start=0, ~end=50)}...]`)}
            </div>
          | UserContentPart.File({file}) =>
            <div key className="text-violet-200 text-sm italic">{React.string(`[File: ${file}]`)}</div>
          }
        })->React.array}
      </div>
    </div>
  </div>
}
