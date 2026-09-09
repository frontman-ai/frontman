---
"@frontman-ai/client": minor
"@frontman-ai/astro-browser": minor
---

Show Astro persistence keys in DOM inspection and element annotations. Astro `get_dom` also describes marked DOM ancestors outside the selected subtree in both output modes.

Ancestor inspection stops at 50 parent steps, 10 marked ancestors, or 4 KB of context, with explicit truncation. It does not cross shadow roots. These markers do not prove that elements or state survived navigation. Inspection for other frameworks remains unchanged.
