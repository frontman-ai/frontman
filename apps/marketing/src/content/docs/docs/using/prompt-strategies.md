---
title: Prompt Strategies
description: Advanced patterns for getting better results from Frontman — iterating, chaining, course-correcting, and knowing when to re-prompt.
---

[Sending Prompts](/docs/using/sending-prompts/) covers the basics — what you can attach, how to write a clear prompt, and what happens when you hit send. This page goes further: patterns for iterating on results, chaining multi-step work, recovering from wrong turns, and getting the most out of each agent run.

## Iterating on results

The agent remembers your full conversation history within a session. Use that to your advantage — each follow-up prompt builds on everything that came before.

### Refine, don't repeat

After the agent makes a change, you don't need to re-describe the full context. Just say what's different:

```text
// First prompt
"Make the hero heading 48px bold with a gradient text effect"

// Follow-up — the agent already knows which heading
"Actually make it 56px, and use a blue-to-purple gradient instead"
```

The agent sees the previous edit, the screenshot it took to verify, and your new instruction. It knows exactly which element and file to revisit.

### Nudge with specifics

When a result is close but not quite right, be precise about what to adjust rather than re-describing the whole change:

```text
// Vague — forces the agent to re-evaluate everything
"The spacing still doesn't look right"

// Specific — the agent makes one targeted edit
"Reduce the gap between the heading and subheading to 12px"
```

### Use "undo that" or "revert"

If a change went wrong, you can ask the agent to undo it:

```text
"Undo the last change"
"Revert the font change you just made"
```

The agent has the file's previous state in its conversation history and can reverse the edit. For complex multi-file changes, be specific about which file or change to revert.

## Chaining prompts

Complex work is better as a sequence of focused prompts than one mega-request. The agent handles each step more reliably, and you can course-correct between them.

### Break it into stages

Instead of:
```text
// Too much at once — the agent may lose track or make trade-offs you don't want
"Redesign the pricing section with three tiers, add a toggle for
monthly/annual billing, make the popular plan highlighted, and
ensure it's responsive on mobile"
```

Chain it:
```text
// Prompt 1
"Create a three-column pricing card layout in the pricing section
with Basic, Pro, and Enterprise tiers"

// Prompt 2 (after reviewing)
"Add a monthly/annual toggle above the cards that switches the
displayed prices"

// Prompt 3
"Highlight the Pro card as the recommended plan — slightly larger
with a colored border and a 'Most Popular' badge"

// Prompt 4
"Make the pricing cards stack vertically on mobile"
```

Each prompt is a self-contained step. You review the result, and the agent carries forward the full context.

### Layer complexity gradually

Start with structure, then add behavior, then polish:

1. **Layout first** — "Create a two-column layout with a sidebar and main content area"
2. **Content next** — "Add navigation links to the sidebar: Home, Features, Pricing, Blog"
3. **Behavior** — "Make the sidebar collapsible with a hamburger button"
4. **Polish** — "Add a slide animation to the sidebar toggle, 200ms ease-in-out"

This mirrors how you'd build it manually, and gives you a checkpoint after each step.

## Course-correcting

Sometimes the agent interprets your prompt differently than you intended. Here's how to get back on track without starting over.

### Be direct about what's wrong

```text
// Clear correction
"That's not what I meant — I want the border on the outer card
container, not on each individual list item inside it"

// Point at the right target
"You edited the wrong component. The heading I'm referring to
is in the hero section, not the features section"
```

The agent will re-read the page, find the correct element, and apply the change there instead.

### Use annotations to disambiguate

If the agent keeps targeting the wrong element, switch to [annotations](/docs/using/annotations/). Click the element you mean in the preview — the agent gets the exact CSS selector, source file, and line number. No room for misinterpretation.

```text
// Without annotation — the agent has to guess which "button"
"Make the button blue"

// With annotation — the agent knows exactly which one
[click the button in the preview]
"Make this blue"
```

### Stop and redirect

If the agent is mid-run and heading in the wrong direction, click the **stop button** (square icon) in the input bar to cancel the current turn. Then send a new prompt with clearer instructions. The agent picks up from where you stopped it — it doesn't lose the conversation context.

```text
[stop the agent]
"Stop — don't change the layout. I only want you to update the
text color, nothing else"
```

## Providing reference material

The agent can work with more than just text instructions. Use attachments to give it richer context.

### Paste a design spec or mockup

Drag an image into the chat — a screenshot of a Figma design, a competitor's page, or a hand-drawn wireframe. The agent sees the image alongside your prompt:

```text
[attach mockup image]
"Make the hero section match this design. Keep the existing
content but update the layout and spacing to match."
```

### Paste code or specs as text

Long code snippets or spec text automatically collapse into compact chips in the input. The full content is still sent to the agent:

```text
[paste a CSS snippet]
"Apply these styles to the card component"

[paste a JSON schema]
"Create a form that matches this data structure"
```

### Paste a PDF

Drop a PDF into the chat for design specs, brand guidelines, or content documents. The agent extracts and reads the content:

```text
[attach brand-guidelines.pdf]
"Update the color scheme to match the brand colors in this document"
```

## Working with device modes

The agent is aware of the current device emulation mode. Use this for responsive design work.

### Test at a specific viewport

Switch to a device preset in the [web preview](/docs/using/web-preview/) toolbar before sending your prompt. The agent's screenshots will capture that viewport size, and it can reason about breakpoints:

```text
[switch to iPhone 15 Pro in device mode]
"The navigation menu overlaps the content. Fix it for this screen size."
```

### Chain responsive changes

Work through breakpoints one at a time:

```text
[desktop mode]
"The feature grid should be 3 columns on desktop"

[switch to iPad Air]
"Make it 2 columns at this width"

[switch to iPhone 15 Pro]
"Stack them single-column on mobile, with less padding"
```

The agent reads the device dimensions from the [current page context](/docs/using/how-the-agent-works/) that's sent with every prompt, so it knows which breakpoint you're targeting.

## Prompt patterns for common tasks

### "Match this" pattern

Provide a reference and ask the agent to match it:

```text
"Make the footer look like the header — same background color,
same horizontal padding, same font size for the links"

[attach screenshot of another page]
"Match the card style from this screenshot"
```

### "Do the same for X" pattern

After the agent completes one change, extend it to similar elements:

```text
// After the agent styles one card
"Now apply the same styling to all the other cards in this section"

// After fixing one page
"Do the same responsive fix on the /about and /contact pages"
```

### "Before and after" pattern

Describe the current state and desired state:

```text
"Right now the testimonials are in a vertical list. Change them
to a horizontal carousel with 3 visible at a time and
left/right navigation arrows"
```

### "Conditional" pattern

Describe behavior that depends on state or context:

```text
"If the user is on mobile (under 768px), hide the sidebar
completely. On tablet (768-1024px), make it collapsible.
On desktop, keep it always visible."
```

## When to start a new session

Sessions maintain full conversation history, which is useful for context — but that history also consumes the model's context window. Start a new session when:

- **You're switching to unrelated work** — editing the footer after spending 20 prompts on the header. A fresh session avoids confusion from irrelevant context.
- **The agent seems confused** — if responses are getting less accurate or the agent is referencing changes from much earlier in the session, it may be hitting context limits. A clean session resets this.
- **You want a different approach** — if you've iterated many times and want to try a fundamentally different direction, a new session lets the agent start without bias from previous attempts.

You don't need a new session for:
- Follow-ups on recent changes (that's what sessions are for)
- Switching between pages in the same area of your app
- Trying a minor variation on the last prompt

## Tips for better results

- **Navigate first, then prompt** — go to the page you want changed in the preview before sending your prompt. The agent screenshots what it sees, so being on the right page saves a round trip.
- **One concern per prompt** — each prompt should have a single clear goal. "Make the heading bigger" and "also fix the footer alignment" are better as two separate prompts.
- **Name things when you can** — "the `PricingCard` component", "the `.hero-section` div", "the second column". The more specific you are, the fewer exploratory steps the agent needs.
- **Show, don't just tell** — an annotation or an attached mockup is worth a paragraph of description.
- **Let the agent verify** — the agent takes a screenshot after making changes. If you see it skipped this step, ask "take a screenshot and show me the result" to confirm the change looks right.
- **Use the question flow** — when the agent [asks you a question](/docs/using/question-flow/), answer it specifically. Vague answers lead to vague results.

## Next steps

- **[Annotations](/docs/using/annotations/)** — point at elements for precision
- **[The Web Preview](/docs/using/web-preview/)** — navigate and test responsive layouts
- **[Limitations & Workarounds](/docs/using/limitations/)** — what the agent can't do (yet)
- **[How the Agent Works](/docs/using/how-the-agent-works/)** — understand the agent loop
