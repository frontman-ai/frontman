---
"@frontman/frontman-server-assets": patch
---

Block new usage as soon as Stripe reports a past-due subscription after a failed payment, rather than allowing access during payment retries. Restore access when the subscription becomes active again.
