# Launch Progress

## Requirement: Show Launch Progress

Launch progress reflects the `Launch` projection.

### Scenario: Progress step shown

Given a `Launch` projection with current step
When launch progress is shown
Then the progress step matches the `Launch` projection.

### Scenario: Ready session shown

Given a `Launch` projection with `Ready Session`
When launch progress is shown
Then the ready preview URL is shown.

## Requirement: Show Launch Error And Retry

Launch errors map from `FailureCategory` and valid retry actions.

### Scenario: Retryable failure shown

Given a `Launch` projection with retryable failure
When launch error is shown
Then the error message maps from `FailureCategory`
And a retry action is shown.

### Scenario: Non-retryable failure shown

Given a `Launch` projection with non-retryable failure
When launch error is shown
Then the error message maps from `FailureCategory`
And no retry action is shown.

### Scenario: Retry requested

Given a `Launch` projection with a valid retry action
When the user requests retry
Then publish `LaunchRetryRequested`.
