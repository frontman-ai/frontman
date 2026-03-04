# @frontman/logs

## 0.1.1

### Patch Changes

- [#472](https://github.com/frontman-ai/frontman/pull/472) [`0e02a6a`](https://github.com/frontman-ai/frontman/commit/0e02a6ab637979e8f1276390e8608d998ec6edc1) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Migrate direct Console.\* calls to structured @frontman/logs logging in client-side packages. Replaces ~40 Console.log/error/warn calls across 11 files with component-tagged, level-filtered Log.info/error/warning/debug calls. Extends LogComponent.t with 10 new component variants for the migrated modules.
