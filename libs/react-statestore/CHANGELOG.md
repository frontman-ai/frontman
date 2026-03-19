# @frontman-ai/react-statestore

## 0.2.0

### Minor Changes

- [#511](https://github.com/frontman-ai/frontman/pull/511) [`3ba5208`](https://github.com/frontman-ai/frontman/commit/3ba5208f0ef332653a199a7b78e210c5a6ee0190) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Open-source `@frontman-ai/react-statestore` as an independent npm package. Remove internal logging dependency, disable ReScript namespace for cleaner module imports, rename package from `@frontman/react-statestore` to `@frontman-ai/react-statestore`, and migrate all consumer references in `libs/client/`.

## 0.1.0

### Initial Release

- **StateReducer**: Local component state with pure reducers and managed side effects
- **StateStore**: Global state store with concurrent-safe selectors via `useSyncExternalStoreWithSelector`
- Efficient custom equality comparison for selectors
- First-class ReScript support with module functor interface
