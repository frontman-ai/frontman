module Button = Client__UI__Button
module Dialog = Client__UI__Dialog
module Icons = Client__UI__Icons

@react.component
let make = () => {
  let open_ = Client__State.useSelector(Client__State.Selectors.showFirstTaskFeedbackDialog)
  let linkCopied = Client__State.useSelector(Client__State.Selectors.firstTaskFeedbackLinkCopied)
  let shareFailed = Client__State.useSelector(Client__State.Selectors.firstTaskFeedbackShareFailed)
  let (ratingUrl, ratingLabel) = switch Client__RuntimeConfig.read().framework {
  | Nextjs | Vite | Astro => ("https://github.com/frontman-ai/frontman", "Star us on GitHub")
  | Wordpress => ("https://wordpress.org/plugins/frontman-agentic-ai-editor/", "Leave a review")
  }

  <Dialog
    open_
    onOpenChange={(isOpen, _) =>
      switch isOpen {
      | true => ()
      | false => Client__State.Actions.dismissFirstTaskFeedbackDialog()
      }}
  >
    <Dialog.Content className="sm:max-w-md">
      <Dialog.Header className="items-center pt-2 text-center">
        <div
          className="mb-1 flex size-14 items-center justify-center rounded-full bg-emerald-500/15 ring-1 ring-emerald-400/30"
        >
          <Icons.Check size=28 className="text-emerald-300" ariaHidden=true />
        </div>
        <span className="text-[11px] font-semibold tracking-[0.14em] text-emerald-400 uppercase">
          {React.string("First task complete")}
        </span>
        <Dialog.Title className="text-lg"> {React.string("You did it!")} </Dialog.Title>
        <Dialog.Description className="max-w-sm leading-relaxed">
          {React.string(
            "Frontman is up and running, and you've completed your first task. If you enjoyed the experience, support the project and share it with someone who'd love it too.",
          )}
        </Dialog.Description>
      </Dialog.Header>
      <Dialog.Footer>
        <Button
          variant=Button.Variant.Secondary
          disabled={linkCopied}
          onClick={_ => Client__State.Actions.shareFrontman()}
        >
          {switch (linkCopied, shareFailed) {
          | (true, _) => React.string("Link copied")
          | (false, true) => React.string("Share failed. Try again")
          | (false, false) => React.string("Share Frontman")
          }}
        </Button>
        <a
          href=ratingUrl
          target="_blank"
          rel="noopener noreferrer"
          className={Button.buttonVariants()}
          onClick={_ => Client__State.Actions.dismissFirstTaskFeedbackDialog()}
        >
          {React.string(ratingLabel)}
        </a>
      </Dialog.Footer>
    </Dialog.Content>
  </Dialog>
}
