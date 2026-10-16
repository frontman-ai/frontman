---
"@frontman/frontman-server-assets": patch
"@frontman-ai/client": patch
---

Block new usage as soon as Stripe reports a past-due subscription after a failed payment, rather than allowing access during payment retries. Restore access when the subscription becomes active again. Prevent duplicate subscription checkout for past-due users and direct them to manage payment in Stripe.
