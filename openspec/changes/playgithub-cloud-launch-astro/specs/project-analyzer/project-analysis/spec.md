# Project Analysis

## Requirement: Analyze Project

The system can analyze a cloned workspace and produce a `ProjectAnalysis`.

### Scenario: Supported Astro project analyzed

Given a cloned workspace
And the requested path contains a supported Astro runnable project
When project analysis runs
Then a `ProjectAnalysis` is created
And it includes framework, project root, package manager, install command, start plan, port, and confidence
And publish `ProjectAnalyzed`.

### Scenario: Unsupported project rejected

Given a cloned workspace
And no supported runnable project is found
When project analysis runs
Then the project is rejected as unsupported
And publish `ProjectUnsupported`.

### Scenario: Low confidence cannot be supported

Given a cloned workspace
And detected signals are insufficient
When project analysis runs
Then no supported `ProjectAnalysis` is created
And publish `ProjectUnsupported`.

## Requirement: Preserve Read-Only Analysis

Project analysis must not mutate repository files.

### Scenario: Analysis completes without mutation

Given a cloned workspace
When project analysis runs
Then repository files remain unchanged
And the analysis result records only observed project signals.
