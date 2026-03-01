---
"@frontman-ai/client": patch
"@frontman/react-statestore": patch
"@frontman/logs": patch
---

Migrate direct Console.* calls to structured @frontman/logs logging in client-side packages. Replaces ~40 Console.log/error/warn calls across 11 files with component-tagged, level-filtered Log.info/error/warning/debug calls. Extends LogComponent.t with 10 new component variants for the migrated modules.
