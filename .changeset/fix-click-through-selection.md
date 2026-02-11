---
"@frontman/client": patch
---

Fixed click-through on interactive elements (links, buttons) during element selection mode by using event capture with preventDefault/stopPropagation instead of disabling pointer events on anchors
