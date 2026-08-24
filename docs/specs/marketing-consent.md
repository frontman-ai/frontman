# Spec: Local Marketing Consent

## Objective

Replace unsupported `astro-consent` dependency with a local Astro 7 integration that preserves Frontman's cookie banner, consent storage, and analytics gating.

## Behavior

- Store consent under `frontman-cookie-consent` for 180 days.
- Expose `window.astroConsent.get()`, `set()`, and `reset()`.
- Support essential and analytics categories only; essential is always enabled.
- Show accessible accept, reject, and manage-preferences controls on every marketing and docs page.
- Keep a cookie-preferences control available after the initial choice so consent can be changed.
- Dispatch `consentchange` after consent changes so analytics can react immediately.
- Respect Global Privacy Control by leaving analytics disabled unless explicitly accepted.

## Structure

- `apps/marketing/src/integrations/consent.mjs`: Astro integration and injected browser runtime.
- `apps/marketing/src/integrations/analytics-consent.mjs`: Google Analytics consent-mode runtime.
- `apps/marketing/src/integrations/*.test.mjs`: storage, UI, and analytics regression tests.
- `apps/marketing/src/cookiebanner/styles.css`: existing project-owned presentation.

## Verification

- `make -C apps/marketing test`
- `make -C apps/marketing build`
- Browser checks for keyboard navigation, accept/reject/manage flows, persistence, and zero console errors.

## Boundaries

- Never load analytics before explicit analytics consent.
- Never persist categories other than essential and analytics.
- Never render user-controlled HTML.
- Preserve upstream MIT attribution for adapted code.
