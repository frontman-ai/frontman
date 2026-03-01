---
"@frontman-ai/client": patch
---

Fix selection mode cursor reverting to pointer/hand on interactive elements inside iframe. Replaced body-level inline cursor style with an injected `<style>` tag using `* { cursor: crosshair !important; }` so that buttons, links, and inputs can't override the crosshair during selection mode.
