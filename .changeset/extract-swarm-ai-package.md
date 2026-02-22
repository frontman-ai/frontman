---
"@frontman/frontman-core": patch
---

Extract Swarm agent execution framework from frontman_server into standalone swarm_ai Hex package. Rename all Swarm.* modules to SwarmAi.* and update telemetry atoms accordingly. frontman_server now depends on swarm_ai via path dep for monorepo development.
