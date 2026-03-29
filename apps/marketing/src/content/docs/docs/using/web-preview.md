---
title: The Web Preview
description: Navigate, switch device modes, and understand what the Frontman agent sees in the built-in web preview.
---

The web preview is a live, embedded view of your running app that sits alongside the chat panel. It's where the agent looks when it takes screenshots, inspects the DOM, and verifies changes — and it's where you navigate, annotate elements, and test responsive layouts.

Everything the agent can see, you can see. The preview is the shared visual context between you and the agent.

## The toolbar

The toolbar sits at the top of the preview panel and gives you quick access to navigation, device emulation, annotations, and external viewing.

From left to right:

| Control | What it does |
|---------|-------------|
| **← →** | Navigate back and forward through the iframe's history |
| **↻** | Reload the current page |
| **URL bar** | Shows the current preview URL — click to edit, press Enter to navigate |
| **Device mode toggle** | Switch between responsive (full-width) and device emulation modes |
| **Annotation cursor** | Enter [annotation mode](/docs/using/annotations/) to select elements |
| **Freeze animations** | Pause all CSS animations, transitions, and videos (visible when annotation mode is active) |
| **Open in new tab** | Open the current preview URL in a separate browser tab |

## Navigating your app

### Using the URL bar

Click the URL bar to edit the current address. Type a new path or full URL and press **Enter** to navigate. Press **Escape** to cancel and revert to the current URL.

The URL bar only allows same-origin navigation — you can't navigate the preview to a different domain. This matches the iframe security model.

:::tip
The browser URL stays in sync with the preview. If your preview shows `http://localhost:4321/about`, your browser URL will reflect that path. This means you can bookmark or share specific preview states, and refreshing the page returns you to the same preview location.
:::

### Back and forward

The **← →** buttons work just like browser navigation. They step through the iframe's own history stack, so you can move between pages you've visited in the preview without affecting your browser's history.

### Reloading

The **↻** button reloads the preview iframe. This is useful after the agent makes changes — though in most cases your dev server's hot module replacement (HMR) will update the preview automatically.

:::note
Navigating or reloading clears any active [annotations](/docs/using/annotations/). This is intentional — annotations reference specific DOM elements, which are destroyed when the page reloads.
:::

## Device emulation

Device mode lets you test how your app looks at different screen sizes without resizing your browser window. The preview iframe is constrained to the selected device's dimensions and scaled to fit the available space.

### Toggling device mode

Click the **device mode toggle** (mobile phone icon) in the toolbar. When active, the button turns blue and a secondary device bar appears below the toolbar with additional controls.

Click it again to return to responsive mode, where the preview fills all available space.

### Choosing a device preset

When device mode is active, the device bar shows a dropdown with the current device name. Click it to choose from a list of presets organized by category:

**Phones**
| Preset | Dimensions | DPR |
|--------|-----------|-----|
| iPhone SE | 375 × 667 | 2.0 |
| iPhone 15 Pro | 393 × 852 | 3.0 |
| iPhone 15 Pro Max | 430 × 932 | 3.0 |
| Pixel 8 | 412 × 924 | 2.625 |
| Samsung Galaxy S24 | 360 × 780 | 3.0 |

**Tablets**
| Preset | Dimensions | DPR |
|--------|-----------|-----|
| iPad Mini | 768 × 1024 | 2.0 |
| iPad Air | 820 × 1180 | 2.0 |
| iPad Pro 11" | 834 × 1194 | 2.0 |
| iPad Pro 12.9" | 1024 × 1366 | 2.0 |

**Desktop**
| Preset | Dimensions | DPR |
|--------|-----------|-----|
| Laptop | 1024 × 768 | 1.0 |
| Laptop L | 1440 × 900 | 1.0 |
| 4K | 2560 × 1440 | 1.0 |

You can also select **Responsive** from the dropdown to exit device mode.

### Custom dimensions

The width and height inputs in the device bar let you type exact pixel values. Edit either field and press **Enter** or click away to apply. This is useful when targeting a specific breakpoint that doesn't match any preset.

### Rotating orientation

Click the **rotate button** (↻) in the device bar to switch between portrait and landscape orientation. This swaps the width and height — a 393 × 852 iPhone in landscape becomes 852 × 393.

### Scaling behavior

When a device viewport is larger than the available preview space, Frontman automatically scales it down to fit. The scaling preserves aspect ratio and is purely visual — CSS media queries still fire at the device's real dimensions, not the scaled size.

The DPR (device pixel ratio) indicator appears next to the rotate button for device presets. While displayed for reference, DPR does not affect CSS rendering in the preview — it's used by the agent when taking screenshots in device emulation mode.

### Persistence

Your device mode selection and orientation are saved to `localStorage` and persist across page reloads and browser sessions. Switching to a different task restores that task's device mode independently.

## What the agent sees

The web preview is the agent's primary visual input. When the agent uses its browser tools, it's looking at — and interacting with — the same preview iframe you see.

| Agent tool | What it does in the preview |
|------------|----------------------------|
| **Take screenshot** | Captures the visible viewport (or full page) of the preview as a JPEG image |
| **Get DOM** | Reads the DOM structure of the preview iframe, including CSS selectors and component names |
| **Get interactive elements** | Discovers all buttons, links, inputs, and other clickable elements |
| **Search text** | Finds visible text content on the page (like Ctrl+F) |
| **Interact with element** | Clicks, hovers, or focuses elements in the preview |
| **Execute JavaScript** | Runs arbitrary JS inside the preview iframe |
| **Set device mode** | Changes the device emulation mode programmatically |

The agent can also navigate the preview by executing JavaScript (e.g., `location.href = '/about'`), which updates the URL bar and browser URL just as if you'd navigated manually.

:::tip
When you're on a specific page of your app, the agent sees that page too. Navigate to the page you want changed before sending your prompt — this gives the agent immediate visual context without needing to find the right route first.
:::

## Task isolation

Each task (conversation) maintains its own preview state independently:

- **Separate URLs** — switching tasks restores the preview URL for that task
- **Separate device modes** — each task can have a different device emulation setting
- **Separate iframe instances** — each task gets its own iframe, so navigating in one task doesn't affect others

When you switch between tasks, the preview seamlessly updates to show the correct page and device mode for the selected task. Inactive task iframes are kept alive off-screen so they don't need to reload when you switch back.

## The annotation overlay

When [annotation mode](/docs/using/annotations/) is active, the preview gains an interactive overlay layer:

- **Crosshair cursor** — all elements show a crosshair cursor to indicate selection mode
- **Hover highlight** — a purple border and label appear over whichever element your cursor is on, showing its tag name, ID, class, and component name
- **Annotation markers** — numbered purple badges on annotated elements with border highlights
- **Comment popups** — small input fields below newly annotated elements for adding optional comments
- **Selection border** — a subtle purple border around the entire preview indicates selection mode is active

Press **Escape** to exit annotation mode at any time. See [Annotations](/docs/using/annotations/) for the full guide.

### Drag selection

Hold **⌘+Shift** (Mac) or **Ctrl+Shift** (Windows/Linux) and drag to draw a rectangle in the preview. All meaningful elements within the rectangle are annotated at once. This is useful for annotating a group of related elements — like a row of cards or a set of navigation links — in a single gesture.

If you **⌘+Shift+click** without dragging, the single element under the cursor is annotated (same as a regular click in annotation mode, but works as a keyboard shortcut).

## Opening in a new tab

Click the **open in new tab** button (box-with-arrow icon) on the right side of the toolbar to open the current preview URL in a separate browser tab. This is useful when you need to:

- Test the page at your browser's full width
- Use browser DevTools on your app
- Compare the preview side-by-side with a reference
- Test interactions that the preview iframe might restrict

The new tab opens with `noopener` and `noreferrer` for security.

## Next steps

- **[Annotations](/docs/using/annotations/)** — select elements to give the agent precise context
- **[Sending Prompts](/docs/using/sending-prompts/)** — how to write effective prompts
- **[Tool Capabilities](/docs/using/tool-capabilities/)** — full reference for every agent tool
- **[How the Agent Works](/docs/using/how-the-agent-works/)** — understand the agent loop and tool routing
