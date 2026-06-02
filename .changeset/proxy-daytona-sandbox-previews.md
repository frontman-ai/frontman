---
---

Add a temporary Daytona sandbox proxy so preview pages, Frontman tools, iframe assets, and Vite HMR websockets can load through the Frontman API origin. Cache Daytona preview links during host-scoped proxy requests so asset bursts do not repeatedly hit Daytona preview URL lookup.
