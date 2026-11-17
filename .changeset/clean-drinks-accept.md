---
"@frontman-ai/frontman-wordpress": patch
---

Support per-page Yoast indexing preferences in the existing SEO tools.
Omitted indexing stays unchanged. `default` deletes the object override and
inherits policy. `noindex` and `index` store explicit preferences.

Indexing updates require native permissions and sanitizers. The tools invoke
Yoast's native refresh. They report verified indexable persistence, disabled
persistence, or an error with the observed stored preference.
The returned preference is not effective indexing or a search-engine guarantee.

Verify public rendered robots directives and sitemap output independently.
Draft and private pages stay private.
