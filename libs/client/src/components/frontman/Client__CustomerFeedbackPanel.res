@@jsxConfig({version: 4, mode: "automatic", module_: "BaseUi.BaseUiJsxDOM"})

@@live

@react.component
let make = (
  ~score: option<int>,
  ~comment: string,
  ~submitting: bool=false,
  ~error: option<string>=?,
  ~onScoreChanged: int => unit,
  ~onCommentChanged: string => unit,
  ~onSubmit: unit => unit,
  ~onSkip: unit => unit,
) => {
  let id = React.useId()
  let questionId = `${id}-question`
  let scaleId = `${id}-scale`
  let commentId = `${id}-comment`
  let canSubmit =
    !submitting &&
    switch score {
    | Some(value) => value >= 0 && value <= 10
    | None => false
    }

  <Client__UI__Card className="w-full min-w-0">
    <Client__UI__Card.Content>
      <form
        className="flex flex-col gap-5"
        ariaBusy=submitting
        onSubmit={event => {
          JsxEvent.Form.preventDefault(event)
          switch canSubmit {
          | true => onSubmit()
          | false => ()
          }
        }}
      >
        <Client__UI__Field.Set>
          <Client__UI__Field.Legend id=questionId>
            {React.string("How likely are you to recommend Frontman to a friend or colleague?")}
          </Client__UI__Field.Legend>
          <BaseUi.RadioGroup
            value={score->Nullable.fromOption}
            onValueChange={(value, _) => onScoreChanged(value->Nullable.getOrThrow)}
            disabled=submitting
            ariaLabelledby=questionId
            ariaDescribedby=scaleId
            className="flex flex-wrap gap-2"
          >
            {Array.fromInitializer(~length=11, value =>
              <BaseUi.Radio.Root
                key={value->Int.toString}
                value
                ariaLabel={value->Int.toString}
                className="border-input bg-background text-foreground flex size-11 shrink-0 cursor-pointer items-center justify-center rounded-lg border text-sm font-medium tabular-nums outline-none hover:bg-muted focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 data-checked:border-foreground data-checked:bg-foreground data-checked:text-background data-disabled:cursor-not-allowed data-disabled:opacity-50"
              >
                {React.string(value->Int.toString)}
              </BaseUi.Radio.Root>
            )->React.array}
          </BaseUi.RadioGroup>
          <Client__UI__Field.Description id=scaleId>
            {React.string("0 — Not at all likely · 10 — Extremely likely")}
          </Client__UI__Field.Description>
        </Client__UI__Field.Set>
        <Client__UI__Field>
          <Client__UI__Field.Label htmlFor=commentId>
            {React.string("What's the main reason for your score?")}
            <span className="text-muted-foreground font-normal">
              {React.string("(optional)")}
            </span>
          </Client__UI__Field.Label>
          <Client__UI__Textarea
            id=commentId
            value=comment
            maxLength=2000
            disabled=submitting
            onChange={event => onCommentChanged(JsxEvent.Form.target(event)["value"])}
          />
        </Client__UI__Field>
        {switch error {
        | Some(message) =>
          <Client__UI__Field.Error> {React.string(message)} </Client__UI__Field.Error>
        | None => React.null
        }}
        <div className="flex flex-wrap items-center justify-between gap-2">
          <Client__UI__Button
            type_="button"
            variant=Ghost
            className="min-h-11"
            disabled=submitting
            onClick={_ => onSkip()}
          >
            {React.string("Skip")}
          </Client__UI__Button>
          <Client__UI__Button type_="submit" className="min-h-11" disabled={!canSubmit}>
            {React.string(submitting ? "Sending feedback…" : "Send feedback")}
          </Client__UI__Button>
        </div>
      </form>
      <div role="status" className="sr-only">
        {React.string(submitting ? "Sending feedback…" : "")}
      </div>
    </Client__UI__Card.Content>
  </Client__UI__Card>
}
