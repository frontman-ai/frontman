# Error Banner Hierarchy Redesign

## Problem

The current `ErrorBanner` component crams the error message, category guidance, retry button, and Discord link into a single visually heavy block. At the widget's ~250px content width, all four elements compete for attention with roughly equal visual weight. Users can't quickly scan "what happened → what to do → where to get help."

## Design Principle

Information hierarchy follows the user's mental model:

1. **Understand what went wrong** (error message) — primary
2. **Take action** (retry / fix root cause) — secondary
3. **Ask for help** (Discord) — last resort

## Layout

Strip all container chrome: no box border, no background, no warning icon. The hierarchy comes purely from typography (size, weight, opacity). The component sits in the chat flow with `mx-4 my-3` spacing.

### Visual stack (top to bottom)

```
Error message                              ← text-sm font-medium text-red-400
Category guidance (when applicable)        ← text-xs text-red-400/60
[ Retry ]                                  ← text-xs bordered pill, muted red
Need help? Join our Discord                ← text-[11px] text-red-400/30, link
```

### Spacing

- `gap-1` between error message and guidance text
- `mt-2` before the retry button
- `mt-1.5` before the Discord link

When no guidance line is present (e.g. `overload` or `unknown` category), the retry button moves directly below the error message.

## Category Guidance

The guidance line renders only for categories with actionable advice:

| Category | Guidance text | Link target |
|---|---|---|
| `auth` | "Your API key may be invalid — check Settings" | `/settings` |
| `billing` | "There may be a billing issue — check Settings" | `/settings` |
| `rate_limit` | "The provider is rate-limiting you — wait a moment before retrying" | none |
| `payload_too_large` | "Try with a shorter message or smaller files" | none |
| `output_truncated` | "Try asking for a shorter response" | none |
| `overload`, `unknown`, other | *no guidance line* | — |

When the guidance contains a link (auth, billing), the linked phrase uses hover underline styling.

## Retry Button

- Small bordered pill: `text-xs px-3 py-1 rounded`
- Muted red border/text: `text-red-300 border border-red-700/60`
- Hover: `hover:border-red-500 hover:text-red-200`
- Left-aligned, not full-width

## Discord Link

- Plain text only, no Discord icon: "Need help? Join our Discord"
- Smallest type: `text-[11px] text-red-400/30`
- Hover brightens slightly: `hover:text-red-400/50`
- Left-aligned

## Unchanged Behavior

- **RetryBanner priority**: `retryStatus` present → `RetryBanner` (countdown); `turnError` present → `ErrorBanner` (this redesign); neither → nothing.
- **Historical errors**: Errors replayed from message history use the same stripped-down layout.
- **Retry action**: Clicking Retry dispatches `retryTurn` with the error ID, same as current.
- **State flow**: No changes to actions, reducers, selectors, or protocol.

## Scope

This is a client-side-only change to `Client__ErrorBanner.res` and its storybook file. No server, protocol, or state changes needed.

## Files to Change

- `libs/client/src/components/frontman/Client__ErrorBanner.res` — rewrite markup
- `libs/client/src/components/frontman/Client__ErrorBanner.story.res` — update stories to match
