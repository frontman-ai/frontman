// Full-height drawer overlay for the question tool.
// Renders inside the chatbox panel as an absolute overlay, covering
// the message list and input but allowing task-tab switching.

module Icons = Bindings__RadixUI__Icons

// Individual option button with checkbox/radio indicator
module OptionButton = {
  @react.component
  let make = (~option: Client__Question__Types.questionOption, ~selected: bool, ~multiple: bool, ~onToggle: string => unit) => {
    let optionClass = switch selected {
    | true =>
      "rounded-lg border border-[#8051CD]/60 bg-[#8051CD]/15 px-3 py-2.5 cursor-pointer text-left transition-all duration-100"
    | false =>
      "rounded-lg border border-zinc-700/50 bg-zinc-900/50 px-3 py-2.5 cursor-pointer text-left transition-all duration-100 hover:border-zinc-600 hover:bg-zinc-800/50"
    }
    <button
      className={optionClass}
      onClick={_ => onToggle(option.label)}>
      <div className="flex items-start gap-2.5">
        // Checkbox/radio indicator
        <div
          className={[
            "mt-0.5 flex size-4 shrink-0 items-center justify-center rounded",
            switch multiple {
            | true => "rounded-sm"
            | false => "rounded-full"
            },
            switch selected {
            | true => "bg-[#8051CD] text-white"
            | false => "border border-zinc-600"
            },
          ]->Array.join(" ")}>
          {switch selected {
          | true => <Icons.CheckIcon className="size-3" />
          | false => React.null
          }}
        </div>
        <div className="flex flex-col gap-0.5">
          <span
            className={[
              "text-[12px] font-medium",
              switch selected {
              | true => "text-zinc-100"
              | false => "text-zinc-300"
              },
            ]->Array.join(" ")}>
            {React.string(option.label)}
          </span>
          <span className="text-[11px] leading-snug text-zinc-500">
            {React.string(option.description)}
          </span>
        </div>
      </div>
    </button>
  }
}

// Custom text textarea with local draft buffering.
// Owns the localDraft useState so keystroke re-renders stay isolated here.
module CustomTextInput = {
  @react.component
  let make = (~customText: string, ~isCustomMode: bool, ~onTextChange: string => unit) => {
    // Local draft buffer — prevents keystroke lag from reducer round-trip.
    let (localDraft, setLocalDraft) = React.useState(() => customText)

    // Sync local draft from store whenever the store answer changes
    // (e.g. user clicks an option -> store switches to Answered -> customText becomes "")
    React.useEffect(() => {
      setLocalDraft(_ => customText)
      None
    }, [customText])

    <div className="flex flex-col gap-2">
      <div className="flex items-center gap-2">
        <div className="h-px flex-1 bg-zinc-700/50" />
        <span className="text-[11px] text-zinc-500">
          {React.string("or type your own")}
        </span>
        <div className="h-px flex-1 bg-zinc-700/50" />
      </div>
      <textarea
        className={[
          "w-full resize-none rounded-lg border px-3 py-2 text-[12px] text-zinc-200 placeholder:text-zinc-600 focus:outline-none focus:ring-1 transition-all duration-100",
          switch isCustomMode {
          | true =>
            "border-[#8051CD]/60 bg-[#8051CD]/10 focus:ring-[#8051CD]/40"
          | false =>
            "border-zinc-700/50 bg-zinc-900/50 focus:ring-zinc-600"
          },
        ]->Array.join(" ")}
        rows=2
        placeholder="Type your answer..."
        value=localDraft
        onChange={e => {
          let value = ReactEvent.Form.target(e)["value"]
          setLocalDraft(_ => value)
          onTextChange(value)
        }}
      />
    </div>
  }
}

// Step indicator dots for multi-question navigation
module StepperDots = {
  @react.component
  let make = (
    ~questions: array<Client__Question__Types.questionItem>,
    ~answers: Dict.t<Client__Question__Types.questionAnswer>,
    ~currentStep: int,
    ~taskId: string,
  ) => {
    switch Array.length(questions) > 1 {
    | true =>
      <div
        className="absolute left-1/2 top-1/2 flex -translate-x-1/2 -translate-y-1/2 items-center gap-1.5">
        {questions
        ->Array.mapWithIndex((q, i) => {
          let isActive = i === currentStep
          let answer = answers->Dict.get(i->Int.toString)
          let isSkipped = switch answer {
          | Some(Client__Question__Types.Skipped) => true
          | _ => false
          }
          let isAnswered = switch answer {
          | Some(Client__Question__Types.Answered(_))
          | Some(Client__Question__Types.CustomText(_)) => true
          | _ => false
          }
          let dotClass = switch (isActive, isAnswered, isSkipped) {
          | (true, _, _) => "size-2 rounded-full bg-[#8051CD] ring-2 ring-[#8051CD]/30"
          | (false, true, _) => "size-2 rounded-full bg-[#8051CD]"
          | (false, _, true) => "size-2 rounded-full border-2 border-[#8051CD]"
          | (false, false, false) => "size-2 rounded-full bg-zinc-700"
          }
          <button
            key={i->Int.toString}
            title={q.header}
            className={`${dotClass} transition-all duration-150 cursor-pointer`}
            onClick={_ =>
              Client__State.Actions.questionStepChanged(~taskId, ~step=i)}
          />
        })
        ->React.array}
      </div>
    | false => React.null
    }
  }
}

// Bottom action row: skip all / cancel
module FooterActions = {
  @react.component
  let make = (~onSkipAll: unit => unit, ~onCancel: unit => unit) => {
    <div className="flex items-center justify-center gap-3">
      <button
        className="cursor-pointer text-[11px] text-zinc-500 transition-colors hover:text-zinc-300"
        onClick={_ => onSkipAll()}>
        {React.string("Skip all (decide for me)")}
      </button>
      <span className="text-zinc-700"> {React.string("|")} </span>
      <button
        className="cursor-pointer text-[11px] text-red-400/70 transition-colors hover:text-red-400"
        onClick={_ => onCancel()}>
        {React.string("Cancel (stop agent)")}
      </button>
    </div>
  }
}

@react.component
let make = () => {
  let pendingQuestion = Client__State.useSelector(Client__State.Selectors.pendingQuestion)
  let currentTaskId = Client__State.useSelector(Client__State.Selectors.currentTaskId)

  switch (pendingQuestion, currentTaskId) {
  | (Some(pq), Some(taskId)) => {
      let currentStep = pq.currentStep
      let totalSteps = Array.length(pq.questions)
      let currentQuestion = pq.questions->Array.get(currentStep)
      let currentAnswer = pq.answers->Dict.get(currentStep->Int.toString)

      let isOptionSelected = (label: string): bool => {
        switch currentAnswer {
        | Some(Client__Question__Types.Answered(labels)) => labels->Array.includes(label)
        | _ => false
        }
      }

      let isCustomMode = switch currentAnswer {
      | Some(Client__Question__Types.CustomText(_)) => true
      | _ => false
      }

      let customText = switch currentAnswer {
      | Some(Client__Question__Types.CustomText(text)) => text
      | _ => ""
      }

      let handleOptionToggle = (label: string) => {
        Client__State.Actions.questionOptionToggled(~taskId, ~questionIndex=currentStep, ~label)
      }

      let handleCustomTextChange = (text: string) => {
        Client__State.Actions.questionCustomTextChanged(~taskId, ~questionIndex=currentStep, ~text)
      }

      let handleSkipQuestion = () => {
        // The reducer handles step advancement and auto-submit on the last question.
        Client__State.Actions.questionPerQuestionSkipped(~taskId, ~questionIndex=currentStep)
      }

      let handleNextStep = () => {
        switch currentStep < totalSteps - 1 {
        | true => Client__State.Actions.questionStepChanged(~taskId, ~step=currentStep + 1)
        | false => Client__State.Actions.questionSubmitted(~taskId)
        }
      }

      let handlePrevStep = () => {
        switch currentStep > 0 {
        | true => Client__State.Actions.questionStepChanged(~taskId, ~step=currentStep - 1)
        | false => ()
        }
      }

      let hasAnswer = switch currentAnswer {
      | Some(Client__Question__Types.Answered(_)) | Some(Client__Question__Types.CustomText(_)) =>
        true
      | _ => false
      }

      let isLastStep = currentStep === totalSteps - 1
      let canGoBack = currentStep > 0

      <div
        className="flex shrink-0 flex-col border-t border-zinc-700/50 bg-[#180C2D] max-h-[60vh] animate-in fade-in duration-200">
        // Header
        <div className="flex items-center gap-2 border-b border-zinc-700/50 px-4 py-3">
          <div
            className="flex size-6 shrink-0 items-center justify-center rounded-md bg-[#8051CD]/20 text-[#8051CD]">
            <Icons.ChatBubbleIcon className="size-3.5" />
          </div>
          <span className="text-sm font-medium text-zinc-200 truncate">
            {switch currentQuestion {
            | Some(q) => React.string(`Question from agent — ${q.header}`)
            | None => React.string("Question from agent")
            }}
          </span>
        </div>
        // Question content
        <div className="flex flex-1 flex-col overflow-y-auto px-4 py-4">
          {switch currentQuestion {
          | Some(q) =>
            <div className="flex flex-col gap-4">
              <p className="text-[12px] leading-relaxed text-zinc-400">
                {React.string(q.question)}
              </p>
              // Options
              <div className="flex flex-col gap-1.5">
                {q.options
                ->Array.mapWithIndex((opt, i) => {
                  <OptionButton
                    key={i->Int.toString}
                    option=opt
                    selected={isOptionSelected(opt.label)}
                    multiple={q.multiple->Option.getOr(false)}
                    onToggle=handleOptionToggle
                  />
                })
                ->React.array}
              </div>
              // Custom text input
              <CustomTextInput customText isCustomMode onTextChange=handleCustomTextChange />
            </div>
          | None => React.null
          }}
        </div>
        // Footer
        <div
          className="flex flex-col gap-2 border-t border-zinc-700/50 px-4 py-3">
          // Navigation row
          <div className="relative flex items-center justify-between">
            // Left: back + skip
            <div className="flex items-center gap-2">
              <button
                className={[
                  "flex items-center gap-1 rounded-md px-2 py-1 text-[12px] transition-colors",
                  switch canGoBack {
                  | true => "text-zinc-400 hover:text-zinc-200 cursor-pointer"
                  | false => "text-zinc-700 cursor-default pointer-events-none"
                  },
                ]->Array.join(" ")}
                disabled={!canGoBack}
                onClick={_ => handlePrevStep()}>
                <Icons.ArrowLeftIcon className="size-3" />
                {React.string("Back")}
              </button>
              <button
                className="cursor-pointer rounded-md px-2 py-1 text-[12px] text-zinc-500 transition-colors hover:text-zinc-300"
                onClick={_ => handleSkipQuestion()}>
                {React.string("Skip")}
              </button>
            </div>
            // Center: stepper dots
            <StepperDots
              questions={pq.questions}
              answers={pq.answers}
              currentStep
              taskId
            />
            // Right: next/submit
            <button
              className={[
                "rounded-lg px-4 py-1.5 text-[12px] font-medium transition-all duration-100",
                switch hasAnswer {
                | true =>
                  "bg-[#8051CD] text-white hover:bg-[#8051CD]/80 cursor-pointer"
                | false =>
                  "bg-zinc-800 text-zinc-500 cursor-not-allowed"
                },
              ]->Array.join(" ")}
              disabled={!hasAnswer}
              onClick={_ =>
                switch isLastStep {
                | true => Client__State.Actions.questionSubmitted(~taskId)
                | false => handleNextStep()
                }}>
              {switch isLastStep {
              | true => React.string("Submit")
              | false => React.string("Next")
              }}
            </button>
          </div>
          // Bottom row: skip all / cancel
          <FooterActions
            onSkipAll={() => Client__State.Actions.questionAllSkipped(~taskId)}
            onCancel={() => Client__State.Actions.questionCancelled(~taskId)}
          />
        </div>
      </div>
    }
  | _ => React.null
  }
}
