# Launch Target

## Requirement: Build Launch Target

A `Source Target` can be translated into a `Launch Target` for an authenticated user.

### Scenario: Launch target is created from source target

Given an authenticated user
And a canonical `Source Target`
When the launch target is built
Then a `Launch Target` is created
And it includes the user and target identity.

### Scenario: Launch target preserves requested path

Given an authenticated user
And a canonical `Source Target` with a requested path
When the launch target is built
Then the `Launch Target` includes the requested path.

### Scenario: Launch target identity is stable

Given the same authenticated user
And the same canonical `Source Target`
When the launch target is built more than once
Then the same `Launch Target` identity is produced.
