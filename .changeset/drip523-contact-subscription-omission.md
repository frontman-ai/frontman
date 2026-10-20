---
"@frontman/frontman-server-assets": patch
---

Stop explicitly subscribing contacts during Resend contact sync. Repeated requests omit subscription preferences; provider preservation on duplicate creation remains unverified. Old workers and rollback versions can still write subscription preferences until drained.
