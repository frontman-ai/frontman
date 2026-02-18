---
"@frontman/client": minor
---

Add Heap Analytics integration with automatic user identification. Heap is initialized in the client bundle with environment-aware env IDs (dev vs production). When a user session connects, the client fetches the user profile and calls `heap.identify()` and `heap.addUserProperties()` with the user's ID, email, and name. The server's `/api/user/me` endpoint now returns `id` and `name` in addition to `email`, and the user profile is stored in global state for reuse across components.
