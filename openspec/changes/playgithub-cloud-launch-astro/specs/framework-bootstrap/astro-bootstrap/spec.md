# Astro Bootstrap

## Requirement: Install Framework Adapter

A supported Astro project can be bootstrapped with the Frontman framework adapter.

### Scenario: Adapter installed for matching Astro project

Given a supported `ProjectAnalysis` with Astro framework
And no existing matching framework adapter is installed
When Astro Bootstrap runs
Then the framework adapter is installed
And publish `FrameworkAdapterInstalled`.

### Scenario: Existing adapter is not duplicated

Given a supported `ProjectAnalysis` with Astro framework
And a matching framework adapter is already installed
When Astro Bootstrap runs
Then no duplicate adapter configuration is created
And publish `FrameworkAdapterInstalled`.

### Scenario: Framework mismatch rejected

Given a `ProjectAnalysis` for a non-Astro framework
When Astro Bootstrap runs
Then bootstrap is rejected
And publish `FrameworkAdapterInstallFailed`.

### Scenario: Adapter install fails

Given a supported `ProjectAnalysis` with Astro framework
And the framework adapter cannot be installed
When Astro Bootstrap runs
Then bootstrap fails with a `FailureCategory`
And publish `FrameworkAdapterInstallFailed`.
