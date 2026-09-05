---
"frontman": patch
---

Keep agent executions registered until terminal events finish so completion checks cannot race persistence. Queued turns wait for the previous worker to exit before they start. Ignore cancellation requests for finishing workers so terminal persistence can complete.
