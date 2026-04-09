# Chatbox Input Redesign

**Date:** 2026-04-09  
**Scope:** `Client__PromptInput` — the composition surface at the bottom of the chat panel

---

## Context

Frontman is a hybrid agentic editor and design tool. Designers and PMs use the chat panel to give instructions to an AI agent that operates on a web preview. The interaction flow is usually: **target an element → add reference material → describe the change → send.**

The chat panel sits to the left of a live web preview. The chatbox occupies the bottom of the panel. The composition surface must work well in a constrained width.

---

## Problems With the Current Design

1. **Everything is the same priority.** File attachment, model selection, element selection, and message submission all sit in one undifferentiated footer row. There is no hierarchy.

2. **Purple has no meaning.** The input border, submit button, chips, and hover states all use violet/purple. When everything is purple, nothing is.

3. **Button sizes are inconsistent.** Attachment is 28px, Select Element is 36px, submit is 40px. No baseline alignment.

4. **Select Element is treated as a peer action to Attach.** It is not — it is a cross-panel mode toggle with persistent state. It needs different visual treatment.

5. **The input border contradicts the flush context.** A card-within-a-flat-surface is the worst of both worlds.

6. **Layout shifts.** When Select Element appears or disappears, the right side of the footer jumps.

7. **Stop button is visually identical to Send.** When the agent is running, the user is in an anxious waiting state. The interrupt affordance needs to feel different from the compose affordance.

---

## Design Decisions

### Layout: flush/divided

The composition area shares the `#130d20` panel background. A single `1px border-t white/8` line separates message history from the composition surface. No card, no shadow, no elevated background. The input field has no border and no background tint — editability is communicated by placeholder text and cursor, not containment.

If a bottom border on the editable area is needed for discoverability, use `border-b border-white/10` only — never a full enclosing box.

### Structure: toolbar anchored at bottom, context grows upward

```
╔════════════════════════════════════╗
║ message history                    ║
╠════════════════════════════════════╣  ← 1px white/8 divider
║  [chips if any — grows upward]     ║
║  Describe what to change...        ║  ← input
╠════════════════════════════════════╣
║  [⊡ Select] [⊕ Attach] ⋯  [Send→] ║  ← toolbar, always here
╚════════════════════════════════════╝
```

The toolbar row is always at the bottom. It never moves. Muscle memory for the primary actions (Select, Attach, Send) is stable regardless of how much context has been added above.

Context chips sit inside the input area at the top, above the typed text. They are part of the composition, not a separate tray.

### Color: one purple, one purpose

**Submit/Stop button = the only element with a purple fill.**  
Everything else — toolbar buttons, chips, borders, hover states — uses zinc neutrals. This makes the send button the single visual anchor of the composition surface. When you look at the chatbox, your eye goes straight to it.

### Toolbar buttons

- Height: 32px, consistent across all toolbar items
- Resting state: `text-zinc-400`, no background
- Hover state: `text-zinc-200 bg-white/6`
- Font size: `text-xs`
- Gap between buttons: `8px`

**Attach** — icon only (`PaperclipIcon` or similar). The result (a chip) appears immediately, so no label is needed.

**Overflow (`⋯`)** — hides model selector and any future tools. Designers and PMs rarely change the model per message; it does not belong in the primary toolbar.

### Select Element: dual-role button

Select Element is categorically different from Attach. It initiates a cross-panel mode and has persistent state. It gets two visual states beyond the standard resting/hover:

**Resting (no element selected):**  
`[⊡ Select element]` — icon + label, `text-zinc-400`

**Selection mode active (waiting for click in preview):**  
`[● Selecting… click to cancel]` — transforms in place, `text-violet-300`, subtle animated dot. The input dims. No layout shift.

**Element selected (mode resolved):**  
`[⊡ .nav-bar ×]` — the button becomes the status indicator. It shows the selected element's identifier inline and gains a dismiss handle. No separate chip is rendered for the element — the button *is* the chip. Color: `text-zinc-200 bg-white/8`.

This means a designer can glance at the toolbar and immediately see whether they have a target set, without scanning the input area for chips.

### Context chips (images, pasted text)

Chips sit inside the input area above the text. They use neutral styling:  
`bg-white/8 border border-white/12 text-zinc-300 text-xs rounded-md`

No purple. The chips are containers for attached content — they carry no emotional signal. Image chips show a small thumbnail. Pasted text chips show a clipboard icon and line count.

### Stop button

When the agent is running, the submit button becomes a pill rather than a circle:  
`[■ Stop]` — same purple fill, but wider. Text label included. This signals a different register: not "compose and send" but "interrupt." The toolbar buttons (Select, Attach) dim to `opacity-40` during agent runs — they are not available, and they should not compete for attention with Stop.

### Spacing and rhythm

- Toolbar row: `px-3 py-2`, 12px total vertical padding
- Input area: `px-4 py-3` (unchanged)
- Chips inside input: `pt-2 pb-1 px-0`, `gap-1.5`, wrap naturally
- Divider: `border-t border-white/8`
- No padding between divider and toolbar — the toolbar row sits flush against it

---

## States

### Default
No chips, no text. Placeholder visible. Send button disabled (grey). Toolbar buttons at full opacity.

### Composing
Text entered or chips present. Send button activates (purple). Select Element shows selected element if one is set.

### Selection mode
Select Element button transforms to "Selecting…" indicator. Input dims. Send disabled. User clicks element in web preview → mode resolves, button shows element name.

### Agent running
Toolbar dims to `opacity-40`. Input disabled with "Waiting for response…" placeholder. Submit transforms to `[■ Stop]` pill.

### Enriching annotations
Send button dims (disabled). No other visual change. A subtle loading indicator on the relevant chip or annotation would be ideal (future work).

---

## Out of Scope

- Design tools panel (manual CSS/HTML editing) — separate feature
- Model selector UI redesign — hidden behind `⋯`, no changes to the selector component itself
- Message history rendering — untouched
- QuestionDrawer — untouched
