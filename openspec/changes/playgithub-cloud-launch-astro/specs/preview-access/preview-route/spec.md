# Preview Route

## Requirement: Configure Preview Route

A running dev server can be exposed through a policy-approved preview route.

### Scenario: Route configured

Given a started dev server
And the proxy target is allowed
When preview route configuration runs
Then a `PreviewRoute` is configured
And publish `PreviewRouteConfigured`.

### Scenario: Proxy target denied

Given a started dev server
And the proxy target is not allowed
When preview route configuration runs
Then no preview route is configured
And publish `PreviewRouteRejected`.

### Scenario: Preview readiness fails

Given a preview route candidate
And preview readiness does not pass
When preview route validation runs
Then the preview route is not ready
And publish `PreviewRouteRejected`.

## Requirement: Validate Preview Readiness

A preview route is ready only when app, assets, and Frontman route are reachable.

### Scenario: Preview route is ready

Given a configured `PreviewRoute`
And the app is reachable
And assets are reachable
And the Frontman route is reachable
When preview readiness is checked
Then the `PreviewRoute` is ready.

### Scenario: Frontman route is not reachable

Given a configured `PreviewRoute`
And the Frontman route is not reachable
When preview readiness is checked
Then the `PreviewRoute` is not ready.
