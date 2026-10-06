---
---

Keep the process registry available during agent shutdown. Serialize terminal outcomes through the task lock so repeated callbacks cannot append errors to a closed turn. Preserve pending interactive questions across restarts.
