/**
 * UserMessage - Renders user messages (text, images, files)
 */

module MessageContainer = Client__MessageContainer
module UserContentPart = Client__State__Types.UserContentPart

@react.component
let make = (~content: array<UserContentPart.t>, ~messageId: string, ~isNew: bool=false) => {
  <div className="sticky top-0 z-10 bg-zinc-900">
    <MessageContainer isNew>
      <div className="text-[13px] leading-relaxed text-zinc-200 font-semibold">
        {content->Array.mapWithIndex((part, i) => {
          let key = `${messageId}-${Int.toString(i)}`
          switch part {
          | UserContentPart.Text({text}) =>
            <div key className="whitespace-pre-wrap">{React.string(text)}</div>
          | UserContentPart.Image({image, mediaType: _}) =>
            <div key className="text-zinc-400 text-sm italic">
              {React.string(`[Image: ${image->String.slice(~start=0, ~end=50)}...]`)}
            </div>
          | UserContentPart.File({file}) =>
            <div key className="text-zinc-400 text-sm italic">{React.string(`[File: ${file}]`)}</div>
          }
        })->React.array}
      </div>
    </MessageContainer>
  </div>
}
