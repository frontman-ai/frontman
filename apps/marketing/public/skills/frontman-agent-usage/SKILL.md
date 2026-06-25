# Frontman Agent Usage

Use this skill when an agent needs to explain or operate Frontman's browser-aware frontend coding workflow.

## What Frontman Does

Frontman sees the running app, not only source files. It combines live DOM, computed CSS, screenshots, component tree, route metadata, server logs, and source files to make targeted frontend edits.

## Best Use Cases

- Change copy, spacing, colors, layout, and responsive behavior on an existing UI.
- Debug CSS cascade or component rendering issues where live browser state matters.
- Let designers and product managers propose edits while developers retain review control.
- Compare rendered result against requested visual change after hot reload.

## Agent Context

- Browser context: DOM, selected elements, screenshots, viewport, computed styles, console data.
- Server context: framework routes, dev logs, project files, build state, source mappings.
- Account context: authenticated Frontman session and user-managed AI provider keys.

## Limitations

Frontman does not automatically deploy changes. It should not be treated as a production write path. It works best when paired with git review and tests.
