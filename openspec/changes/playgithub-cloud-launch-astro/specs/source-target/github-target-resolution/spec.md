# GitHub Target Resolution

## Requirement: Parse Source Target

A raw PlayGithub URL can be translated into a canonical `Source Target`.

### Scenario: Repository target parsed

Given a raw PlayGithub URL for a GitHub repository
When source target parsing runs
Then a canonical `SourceTarget` is created
And publish `SourceTargetParsed`.

### Scenario: Pull request target parsed

Given a raw PlayGithub URL for a pull request
When source target parsing runs
Then a canonical `SourceTarget` is created with PR target
And publish `SourceTargetParsed`.

### Scenario: Requested path target parsed

Given a raw PlayGithub URL with a requested path
When source target parsing runs
Then a canonical `SourceTarget` is created with the requested path
And publish `SourceTargetParsed`.

### Scenario: Invalid target rejected

Given a raw PlayGithub URL that cannot identify a repository
When source target parsing runs
Then the source target is rejected
And publish `SourceTargetRejected`.

## Requirement: Resolve Ref

A `Source Target` resolves to an immutable commit before launch continues.

### Scenario: Ref resolved

Given a valid `Source Target`
When ref resolution runs
Then a `Resolved Commit` is recorded
And publish `RefResolved`.

### Scenario: Ref cannot be resolved

Given a valid `Source Target`
And the requested ref cannot be found
When ref resolution runs
Then the source target resolution fails
And publish `SourceTargetRejected`.
