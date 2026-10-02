---
"@frontman-ai/client": patch
---

Keep checkout and billing management on the account signed into the editor, regardless of the browser's Frontman login. Replace browser checkout launch pages with bearer-authenticated requests, show billing errors in the editor, and refresh status when returning from Stripe. Deploy the matching server and client updates together; older editors must reload or update before opening billing.
