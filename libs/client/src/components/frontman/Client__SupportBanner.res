let ratingTarget = (framework: Client__RuntimeConfig.frameworkId) =>
  switch framework {
  | Nextjs | Vite | Astro => ("https://github.com/frontman-ai/frontman", "Star us on GitHub")
  | Wordpress => ("https://wordpress.org/plugins/frontman-agentic-ai-editor/", "Leave a review")
  }

@react.component
let make = (~framework: Client__RuntimeConfig.frameworkId) => {
  let (href, label) = ratingTarget(framework)

  <div
    className="shrink-0 flex flex-wrap items-center justify-between gap-x-3 gap-y-1 border-b border-emerald-400/15 bg-emerald-400/5 px-4 py-2 text-xs"
  >
    <span className="text-zinc-300"> {React.string("Enjoying Frontman?")} </span>
    <a
      href
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex min-h-6 items-center gap-1.5 rounded-sm font-medium text-emerald-300 underline decoration-emerald-300/40 underline-offset-4 hover:text-emerald-200 hover:decoration-current focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-emerald-300"
    >
      {React.string(label)}
      <Client__UI__Icons.ExternalLink size=12 ariaHidden=true />
    </a>
  </div>
}
