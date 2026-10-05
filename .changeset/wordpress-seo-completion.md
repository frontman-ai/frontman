---
"@frontman-ai/frontman-wordpress": patch
---

Explain unavailable SEO tools through `wp_get_site_info` and use the same compatibility reason for registration and direct calls. Match the tool schemas to the existing positive-ID and update-field requirements.

Support Yoast SEO Free 19.9 on the tested WordPress 6.9.9 / PHP 8.2 combination through the existing adapter. Retain Yoast 28.4 coverage, edit permissions, sanitizers, and stored readbacks. Extend runtime checks to cover later rendered titles, descriptions, Open Graph tags, and WebPage schema. Preserve explicit social overrides. Mutation results confirm stored overrides, not complete rendered output or success on other pages.
