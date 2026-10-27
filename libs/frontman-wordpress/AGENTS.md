# WordPress testing

- Extend the existing unified runtime suite with new integration coverage.
- Run the suite with `make test-wordpress-runtime` from the repository root.
- Do not add feature-specific Make targets or opt-in test suites.
- Select dependency coverage automatically from the supported runtime and installed test dependencies.
- Use real WordPress and plugin dependencies. Do not replace them with mocks, stubs, or fakes.
