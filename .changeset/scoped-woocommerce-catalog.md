---
"@frontman-ai/frontman-wordpress": patch
---

Add scoped WooCommerce catalog display read and confirmed write tools for the shop and category archives, using native Customizer validation and save with persisted readback.

Register the native WooCommerce settings without replaying theme Customizer initialization on frontend requests. This prevents a fatal error with Astra.
