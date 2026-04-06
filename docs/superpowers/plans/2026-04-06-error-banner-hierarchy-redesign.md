# Error Banner Hierarchy Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the ErrorBanner component to establish a clear information hierarchy: error message → action → help link, using typography alone (no box chrome).

**Architecture:** Strip the current bordered/backgrounded card down to a typography-only vertical stack. The component keeps the same props and behavior — only the markup and styling change.

**Tech Stack:** ReScript, React, Tailwind CSS

**Spec:** `docs/superpowers/specs/2026-04-06-error-banner-hierarchy-redesign.md`

---

### Task 1: Rewrite ErrorBanner markup

**Files:**
- Modify: `libs/client/src/components/frontman/Client__ErrorBanner.res`

- [ ] **Step 1: Replace the component markup**

Replace the entire contents of `Client__ErrorBanner.res` with:

```rescript
// ErrorBanner - Displays LLM/agent errors.
// Always shows a retry button. Permanent errors show category-specific guidance.

@react.component
let make = (~error: string, ~category: string, ~onRetry: unit => unit) => {
  let cta = switch category {
  | "auth" => Some(("Your API key may be invalid — check Settings", Some("/settings")))
  | "billing" => Some(("There may be a billing issue — check Settings", Some("/settings")))
  | "rate_limit" =>
    Some(("The provider is rate-limiting you — wait a moment before retrying", None))
  | "payload_too_large" => Some(("Try with a shorter message or smaller files", None))
  | "output_truncated" => Some(("Try asking for a shorter response", None))
  | _ => None
  }

  <div className="mx-4 my-3 animate-in fade-in slide-in-from-top-2 duration-200">
    <p className="text-sm font-medium text-red-400 break-words"> {React.string(error)} </p>
    {switch cta {
    | Some((text, Some(href))) =>
      <a
        href
        className="block text-xs text-red-400/60 mt-1 hover:text-red-300 hover:underline transition-colors"
      >
        {React.string(text)}
      </a>
    | Some((text, None)) =>
      <p className="text-xs text-red-400/60 mt-1"> {React.string(text)} </p>
    | None => React.null
    }}
    <button
      onClick={_ => onRetry()}
      className="text-xs text-red-300 border border-red-700/60 hover:border-red-500 hover:text-red-200 px-3 py-1 rounded transition-colors mt-2"
    >
      {React.string("Retry")}
    </button>
    <a
      href="https://discord.gg/xk8uXJSvhC"
      target="_blank"
      rel="noopener noreferrer"
      className="block text-[11px] text-red-400/30 hover:text-red-400/50 transition-colors mt-1.5"
    >
      {React.string("Need help? Join our Discord")}
    </a>
  </div>
}
```

Key changes from the current implementation:
- Removed the outer `flex items-start gap-3 p-4 bg-red-950/50 border border-red-800/50 rounded-lg` container — no background, no border, no padding box
- Removed the warning triangle SVG icon entirely
- Removed the "Error" title — the error message itself is the primary element
- Error message: `text-sm font-medium text-red-400` (was split across a title + body)
- Guidance text: `text-xs text-red-400/60 mt-1` (was `text-red-300/80 mt-2` — more muted now, tighter spacing)
- Guidance links: added `hover:underline` for discoverability
- Retry button: same styling, now a direct child (`mt-2`) instead of inside a flex row
- Discord link: `text-[11px] text-red-400/30` (was `text-xs text-red-400/50` with an SVG icon — smaller, more muted, icon removed)

- [ ] **Step 2: Build and verify compilation**

Run: `cd libs/client && make build`
Expected: Clean compilation, no errors.

- [ ] **Step 3: Visual check in Storybook**

Run: `cd libs/client && make storybook`

Check these stories in the browser:
- **Auth Error** — error message + "check Settings" link + retry + discord
- **Generic Error** — error message + retry + discord (no guidance)
- **Long Error Message** — text wraps cleanly at ~250px
- **Rate Limit Error** — guidance text (no link) renders between error and retry

Verify the visual hierarchy: error text is most prominent, guidance is secondary, retry button is clear, discord link is barely visible.

- [ ] **Step 4: Commit**

```bash
git add libs/client/src/components/frontman/Client__ErrorBanner.res
git commit -m "refactor: strip ErrorBanner to typography-only hierarchy"
```

---

### Task 2: Update Storybook stories

**Files:**
- Modify: `libs/client/src/components/frontman/Client__ErrorBanner.story.res`

- [ ] **Step 1: Add a width-constrained decorator**

The stories should render at ~250px to match real widget width. Update the story file:

```rescript
open Bindings__Storybook

type args = {message: string, category: string}

let default: Meta.t<args> = {
  title: "Components/Frontman/ErrorBanner",
  tags: ["autodocs"],
  decorators: [
    Decorators.darkBackground,
    story => <div className="max-w-[250px]"> {story()} </div>,
  ],
  render: args =>
    <Client__ErrorBanner error={args.message} category={args.category} onRetry={() => ()} />,
}

let rateLimitError: Story.t<args> = {
  name: "Rate Limit Error",
  args: {
    message: "Free requests exhausted. Add your API key in Settings to continue.",
    category: "rate_limit",
  },
}

let authError: Story.t<args> = {
  name: "Auth Error",
  args: {
    message: "Invalid API key provided.",
    category: "auth",
  },
}

let billingError: Story.t<args> = {
  name: "Billing Error",
  args: {
    message: "Your account has exceeded its billing limit.",
    category: "billing",
  },
}

let payloadTooLarge: Story.t<args> = {
  name: "Payload Too Large",
  args: {
    message: "The request payload was too large.",
    category: "payload_too_large",
  },
}

let outputTruncated: Story.t<args> = {
  name: "Output Truncated",
  args: {
    message: "The response was truncated due to length.",
    category: "output_truncated",
  },
}

let genericError: Story.t<args> = {
  name: "Generic Error",
  args: {
    message: "An unexpected error occurred. Please try again.",
    category: "unknown",
  },
}

let connectionError: Story.t<args> = {
  name: "Connection Error",
  args: {
    message: "Failed to connect to the server. Please check your internet connection.",
    category: "unknown",
  },
}

let longErrorMessage: Story.t<args> = {
  name: "Long Error Message",
  args: {
    message: "This is a very long error message that might wrap to multiple lines. It tests how the component handles longer text content and ensures the layout remains readable and visually appealing even with extended error descriptions that go on and on explaining exactly what went wrong.",
    category: "unknown",
  },
}
```

The only change is adding the `max-w-[250px]` wrapper decorator so all stories render at the real widget width.

- [ ] **Step 2: Build and verify compilation**

Run: `cd libs/client && make build`
Expected: Clean compilation, no errors.

- [ ] **Step 3: Visual check in Storybook**

Run: `cd libs/client && make storybook`

Verify all stories render correctly within the 250px constraint. Pay attention to:
- Long error messages wrapping cleanly
- Guidance text not overflowing
- Retry button and Discord link not being clipped

- [ ] **Step 4: Commit**

```bash
git add libs/client/src/components/frontman/Client__ErrorBanner.story.res
git commit -m "chore: add 250px width constraint to ErrorBanner stories"
```
