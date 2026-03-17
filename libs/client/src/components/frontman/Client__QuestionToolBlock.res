/**
 * QuestionToolBlock - Compact summary card for question tool calls
 *
 * Displays the question tool state:
 * - Streaming/awaiting answer: shimmer "Asking a question..."
 * - Answered: per-question summary with check/skip icons
 * - Cancelled/error: red-tinted card
 */

// Display-only types for parsing the tool result JSON.
// The server sends this format in tool_call_update completed notifications.
S.enableJson()

@schema
type questionAnswerDisplay = {
  question: string,
  answer: option<array<string>>,
}

@schema
type toolOutputDisplay = {
  answers: array<questionAnswerDisplay>,
  skippedAll: bool,
  cancelled: bool,
}

module Card = {
  type variant = Normal | Error

  @react.component
  let make = (~compact: bool, ~variant: variant=Normal, ~children: React.element) => {
    let borderClass = switch variant {
    | Normal => "bg-[#8051CD]/15 border border-[#8051CD]/30"
    | Error => "bg-red-500/10 border border-red-500/30"
    }
    <div
      className={[
        "overflow-hidden animate-in fade-in duration-100",
        compact ? "rounded-lg my-1 mx-2 px-3 py-2" : "rounded-xl my-2 mx-3 px-4 py-3",
        borderClass,
      ]->Array.join(" ")}>
      {children}
    </div>
  }
}

module HeaderRow = {
  type color = Purple | Red

  @react.component
  let make = (~color: color=Purple, ~text: string) => {
    let (iconClass, textClass) = switch color {
    | Purple => ("size-3.5 text-[#8051CD]", "text-[13px] text-zinc-200")
    | Red => ("size-3.5 text-red-400", "text-[13px] text-red-400")
    }
    <div className="flex items-center gap-2">
      <Bindings__RadixUI__Icons.ChatBubbleIcon className={iconClass} />
      <span className={textClass}> {React.string(text)} </span>
    </div>
  }
}

// Schema for parsing tool input (the questions the agent is asking)
@schema
type toolInputDisplay = {
  questions: array<Client__Question__Types.questionItem>,
}

// Render question headers from tool input (for pending/unanswered states)
module QuestionList = {
  @react.component
  let make = (~input: option<JSON.t>) => {
    let parsed = switch input {
    | Some(json) =>
      try {
        Some(S.parseOrThrow(json, toolInputDisplaySchema))
      } catch {
      | _ => None
      }
    | None => None
    }
    switch parsed {
    | Some({questions}) =>
      <div className="mt-1.5 flex flex-col gap-0.5">
        {questions
        ->Array.mapWithIndex((q, i) =>
          <div
            key={Int.toString(i)}
            className="flex items-start gap-1.5 ml-5">
            <span className="text-zinc-500 mt-px shrink-0">
              <Bindings__RadixUI__Icons.QuestionMarkCircledIcon className="size-3" />
            </span>
            <span className="text-[12px] leading-snug text-zinc-400">
              {React.string(q.header)}
            </span>
          </div>
        )
        ->React.array}
      </div>
    | None => React.null
    }
  }
}

@react.component
let make = (
  ~state: Client__State__Types.Message.toolCallState,
  ~input: option<JSON.t>,
  ~result: option<JSON.t>,
  ~errorText: option<string>,
  ~compact: bool=false,
) => {
  switch (state, result) {
  | (InputStreaming, _) | (InputAvailable, _) =>
    <Card compact>
      <HeaderRow color=Purple text="Asking a question..." />
      <QuestionList input />
    </Card>

  | (OutputAvailable, Some(resultJson)) => {
      let parsed = try {
        Some(S.parseOrThrow(resultJson, toolOutputDisplaySchema))
      } catch {
      | _ => None
      }
      let (cancelled, skippedAll) = switch parsed {
      | Some(output) => (output.cancelled, output.skippedAll)
      | None => (false, false)
      }

      <Card compact variant={cancelled ? Error : Normal}>
        <HeaderRow
          color={cancelled ? Red : Purple}
          text={switch (cancelled, skippedAll) {
          | (true, _) => "Cancelled by user"
          | (_, true) => "Skipped (decide for me)"
          | _ => "User responded"
          }}
        />
        {switch (cancelled, parsed) {
        | (true, _) | (_, None) => React.null
        | (false, Some(output)) =>
          <div className="mt-1.5 flex flex-col gap-0.5">
            {output.answers
            ->Array.mapWithIndex((a, i) => {
              let isAnswered = Option.isSome(a.answer)
              let fullAnswer = switch a.answer {
              | Some(labels) => labels->Array.join(", ")
              | None => "skipped"
              }
              let answerText = switch fullAnswer->String.length > 50 {
              | true => fullAnswer->String.slice(~start=0, ~end=50) ++ "..."
              | false => fullAnswer
              }
              let tooltip = `${a.question} — ${fullAnswer}`
              <div
                key={Int.toString(i)}
                title={tooltip}
                className="flex items-start gap-1.5 ml-5">
                {switch isAnswered {
                | true =>
                  <span className="text-teal-400 mt-px shrink-0">
                    <Bindings__RadixUI__Icons.CheckIcon className="size-3" />
                  </span>
                | false =>
                  <span className="text-zinc-500 mt-px shrink-0">
                    <Bindings__RadixUI__Icons.Cross2Icon className="size-3" />
                  </span>
                }}
                <div className="flex items-baseline gap-1 min-w-0">
                  <span className="text-[12px] leading-snug text-zinc-400 shrink-0">
                    {React.string(a.question)}
                  </span>
                  <span className="text-[11px] text-zinc-600 shrink-0">
                    {React.string(`—`)}
                  </span>
                  <span
                    className={[
                      "text-[12px] leading-snug truncate",
                      switch isAnswered {
                      | true => "text-zinc-300"
                      | false => "text-zinc-500 italic"
                      },
                    ]->Array.join(" ")}>
                    {React.string(answerText)}
                  </span>
                </div>
              </div>
            })
            ->React.array}
          </div>
        }}
      </Card>
    }

  | (OutputError, _) =>
    <Card compact variant=Error>
      <HeaderRow color=Red text={errorText->Option.getOr("Question failed")} />
    </Card>

  | (OutputAvailable, None) =>
    // Defensive: shouldn't happen but handle gracefully
    <Card compact>
      <HeaderRow color=Purple text="Question completed" />
    </Card>
  }
}
