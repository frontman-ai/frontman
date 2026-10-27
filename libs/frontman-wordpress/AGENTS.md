# WordPress testing

- Extend the existing unified runtime suite with new integration coverage.
- Run the suite with `make test-wordpress-runtime` from the repository root.
- Use the shared runtime runner, inert assertion helpers, failure reporting, and fixture lifecycle. A shared Make command alone is not a unified suite.
- Keep case files free of custom bootstraps and assertion frameworks.
- Use the shared fresh-process mechanism only when plugin loading or immutable WordPress constants require isolation.
- Keep bootstrap aliases valid through PHP shutdown. The parent process owns cleanup after the child exits.
- Do not add feature-specific Make targets or opt-in test suites.
- Select dependency coverage automatically from the supported runtime and installed test dependencies.
- Use real WordPress and plugin dependencies. Do not replace them with mocks, stubs, or fakes.
