# @frontman/bindings

## 0.1.1

### Patch Changes

- [#393](https://github.com/frontman-ai/frontman/pull/393) [`d4cd503`](https://github.com/frontman-ai/frontman/commit/d4cd503c97e14edc4d4f8f7a2d5b9226a1956347) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix Astro integration defaulting to dev host instead of production when FRONTMAN_HOST is not set, which broke production deployments. Also add stderr maxBuffer enforcement to spawnPromise to prevent unbounded memory growth from misbehaving child processes.
