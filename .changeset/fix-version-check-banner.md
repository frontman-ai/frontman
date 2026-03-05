---
"@frontman-ai/client": patch
"marketing": patch
---

Fix version check banner always showing in monorepo dev. Remove hardcoded serverVersion from marketing config and replace string equality with semver comparison so the banner only appears when the installed version is strictly behind the latest.
