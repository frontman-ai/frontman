# @frontman/client

## 0.2.0

### Minor Changes

- [#295](https://github.com/frontman-ai/frontman/pull/295) [`8d22db6`](https://github.com/frontman-ai/frontman/commit/8d22db6f06f84204add1581fe62a2773b73401e4) Thanks [@itayadler](https://github.com/itayadler)! - Add cancel/stop generation support. Users can now stop an in-progress AI agent response by clicking a stop button in the prompt input. Implements the ACP `session/cancel` notification protocol for clean cancellation across client, protocol, and server layers.

### Patch Changes

- [#296](https://github.com/frontman-ai/frontman/pull/296) [`1b95e12`](https://github.com/frontman-ai/frontman/commit/1b95e127a40b203a847a5f1e64be127280e7f40b) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fixed click-through on interactive elements (links, buttons) during element selection mode by using event capture with preventDefault/stopPropagation instead of disabling pointer events on anchors

- [#299](https://github.com/frontman-ai/frontman/pull/299) [`d32368b`](https://github.com/frontman-ai/frontman/commit/d32368b172c9fd052a2f2b4ed4fea8f55766e5e5) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix stale closure bug in initialization timeout that caused `sessionInitialized` to always read as `false` even after being set to `true`
