---
---

Fix Dialyzer error in ChatGPT OAuth: pattern match required token fields in `exchange_device_code/2` response instead of silently accepting nil, and align `extract_account_id_from_tokens/1` spec with the actual map shape.
