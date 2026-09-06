---
"frontman": patch
---

Interactive tools now wait without a deadline. Finite tool failures return the same result that the server stores.

Supported shutdown preserves dispatched interactive calls and interrupts other unresolved declarations, including tools that did not run. Historical timeout pauses remain terminal.

Execution admission and reconnect behavior remain unchanged. This change does not guarantee cancellation without a worker or prevent synchronous replay after abrupt process loss.
