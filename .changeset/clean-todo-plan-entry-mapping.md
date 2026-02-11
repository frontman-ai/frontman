---
---

Refactor: clean up todo-to-plan-entry mapping in TaskChannel — remove redundant sort (already handled by `Tasks.list_todos/2`), add explicit struct pattern match, and inline the mapping call.
