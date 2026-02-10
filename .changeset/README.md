# Changesets

This folder is managed by [@changesets/cli](https://github.com/changesets/changesets).

When making a change that should appear in the changelog, run:

```
yarn changeset
```

This will prompt you to select which packages are affected, the semver bump type, and a summary of the change. A markdown file will be created in this directory describing the change.

At release time, `yarn changeset version` compiles all pending changesets into `CHANGELOG.md` updates and version bumps.
