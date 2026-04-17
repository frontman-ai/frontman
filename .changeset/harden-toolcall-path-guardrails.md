---
"@frontman-ai/frontman-core": patch
---

Harden tool-call path handling for discovery workflows by adding a per-source-root path hints cache, a zero-result guardrail between `search_files` and `read_file`, nearest-parent recovery for missing paths, and structured `search_files` backend error payloads (command, cwd, exit code, stderr, target path). Add T1-T4 taxonomy regression tests plus a replay test modeled on the 3addabc6 failure sequence.
