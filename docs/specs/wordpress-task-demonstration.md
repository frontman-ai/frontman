# Spec: WordPress Task Demonstration

## Objective

Turn Frontman's existing WordPress FAQ-title recording into one accurate, discoverable, and measurable task demonstration for people maintaining existing sites.

## Behavior

- Describe the task shown in the recording: select an FAQ card title, request one bounded copy change, and review the result beside the conversation.
- Link the header-and-footer tutorial to the demonstration while stating that it shows the workflow, not proof of universal header or footer compatibility.
- Track one demonstration-completed event per page load when the video reaches its end.
- Track tutorial-to-demonstration and final install actions with existing privacy-safe acquisition dimensions.
- Emit analytics only after explicit analytics consent.

## Commands

- Test: `make -C apps/marketing test`
- Build: `make -C apps/marketing build`
- Diff validation: `git diff --check`
- Development: `make -C apps/marketing dev PORT=4321`

## Project Structure

- `apps/marketing/src/content/blog/`: acquisition articles and embedded demonstration.
- `apps/marketing/public/blog/`: existing local poster and video.
- `apps/marketing/src/integrations/analytics-consent.mjs`: consent-gated browser analytics.
- `apps/marketing/src/integrations/analytics-consent.test.mjs`: analytics behavior tests.

## Code Style

Preserve existing Markdown, semantic HTML, Tailwind classes, and analytics attributes.

```html
<video data-ga-event="wordpress_task_demo_completed" data-ga-trigger="ended" data-ga-task-family="copy_update">
```

## Testing Strategy

- Add a failing integration test for consent-gated media completion before changing analytics runtime.
- Run existing marketing tests for metadata, structured data, consent, and acquisition regressions.
- Build static site and check internal links.
- Verify demonstration, links, video controls, mobile layout, and console in a real browser.

## Boundaries

- Always: identify task and staging environment accurately.
- Always: retain explicit setup, backup, compatibility, and review limits.
- Ask first: add new media, dependencies, routes, or analytics providers.
- Never: claim the recording proves header or footer compatibility.
- Never: emit analytics without explicit consent.
- Never: autoplay the demonstration.

## Success Criteria

- Demonstration copy matches visible FAQ-title task.
- Header-and-footer tutorial provides a tracked path to the demonstration and a tracked install action.
- Video completion emits `wordpress_task_demo_completed` once per page load with page, placement, and task-family dimensions after consent.
- Existing marketing tests and production build pass.
- Demonstration works at mobile and desktop widths without console errors.

## Open Questions

- None. Existing media and acquisition conventions define bounded implementation.
