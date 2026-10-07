---
"@frontman-ai/frontman-wordpress": patch
---

Support creating and updating block and Custom HTML widgets, and preserve clickable links in text widgets. Widget removal retains settings for recovery with the existing move tool, including recovery from WordPress's inactive widgets. Reject noncanonical widget IDs before reading or mutating instances. Validate settings and permissions, preserve plugin metadata, and report failed saves with recovery instructions.
