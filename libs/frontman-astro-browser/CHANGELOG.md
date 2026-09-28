# @frontman-ai/astro-browser

## 0.3.0

### Minor Changes

- [#1677](https://github.com/frontman-ai/frontman/pull/1677) [`20c6c34`](https://github.com/frontman-ai/frontman/commit/20c6c342bb4199d5cc88cc865e072449da5f861f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Include Astro client-routing status in automatic page context. Detect enabled, disabled, and unavailable states from the preview document, and preserve the status in server storage and conversation history. Add conditional lifecycle guidance to agent prompts.

- [#1679](https://github.com/frontman-ai/frontman/pull/1679) [`1a93c75`](https://github.com/frontman-ai/frontman/commit/1a93c753949c6c4ee39336c7f552eeb4d455581e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Include the current preview URL in `get_dom` results and fresh client-routing status for Astro only. Keep Astro-specific metadata in the `astro-browser` package, with shared DOM input and output types in the protocol package.

  Report unavailable previews and failed queries as MCP errors (`isError: true`), retaining narrowing guidance for size-limit errors. Remove payload-level `success` and `error` fields; successful results always contain the URL, DOM content, node count, and byte size.

- [#1689](https://github.com/frontman-ai/frontman/pull/1689) [`5a40cf1`](https://github.com/frontman-ai/frontman/commit/5a40cf1de9e15f5612d729093bf575e5621aacf9) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show Astro persistence keys in DOM inspection and element annotations. Astro `get_dom` also describes marked DOM ancestors outside the selected subtree in both output modes.

  Ancestor inspection stops at 50 parent steps, 10 marked ancestors, or 4 KB of context, with explicit truncation. It does not cross shadow roots. These markers do not prove that elements or state survived navigation. Inspection for other frameworks remains unchanged.

## 0.2.0

### Minor Changes

- [#796](https://github.com/frontman-ai/frontman/pull/796) [`9ef1ae0`](https://github.com/frontman-ai/frontman/commit/9ef1ae0f5d284d916c8963e5d5edf14ca19d291e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add get_astro_audit browser tool that reads Astro dev toolbar accessibility and performance audit results
