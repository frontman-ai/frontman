---
"@frontman/client": patch
---

Fix chatbox rendering jank during streaming by adding React.memo to leaf components, buffering text deltas with requestAnimationFrame, removing unnecessary CSS transitions, and switching scroll resize mode to instant.
