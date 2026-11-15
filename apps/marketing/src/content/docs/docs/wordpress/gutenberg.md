---
title: Edit Nested WordPress Gutenberg Blocks with AI
description: Inspect Gutenberg block paths with Frontman, update one nested block, preserve surrounding content, and check saved markup and the rendered WordPress page.
---

Use Frontman to edit one Gutenberg paragraph or heading without rebuilding its parent group, columns, or complete page.
This procedure keeps the edit small and makes the surrounding structure part of the review.
Use clear headings and descriptive link text for readers. A block edit alone does not establish SEO improvement.

## Before you start

1. [Choose your editing interface](/docs/wordpress/choose-interface/) and complete its setup.
2. For an external assistant, read [WordPress MCP permissions](/docs/wordpress/permissions/).
3. Select the intended site and a staging post or page.
4. Keep a current backup.

For hosted MCP, the assistant supplies the selected `site_id` for site-specific tools.
The embedded editor uses the current installation instead; MCP setup is not a prerequisite.
The WordPress arguments here use `post_id` for block tools and `id` for `wp_read_post`.

**CAUTION: Use staging before edits to a published page.**
Block writes save immediately. They do not create an unsaved editor proposal.
`wp_update_block` does not require `confirm`. Block deletion requires separate approval and `confirm=true`.

## Inspect the complete block tree

The prompts here are illustrative, code-backed procedures, not a tested live demonstration.

> On https://your-site.example, read page 417 without changes.
> List its Gutenberg blocks, including nested blocks and their paths.
> Find the paragraph under “Annual boiler servicing” inside the service columns.
> Show its complete markup and its parent structure. If more than one paragraph matches, stop.

1. Read the page with `wp_read_post`, using its observed `id`.
2. Record the original content and publication status.
3. Call `wp_list_blocks` with `post_id`.
4. Find the intended block in `all_blocks`.
5. Read that block with `wp_read_block`, using `post_id` and its returned `path`.

`blocks` lists named top-level blocks with their visible `index`.
`all_blocks` includes named blocks at every depth, with raw tree paths.
For example, `[0, 1, 0]` identifies a child inside a nested parent.
That path is illustrative. Never calculate a path from the position of a result in `all_blocks`.

Freeform content can occupy raw positions without a named block.
The top-level `index` and a raw `path` are not interchangeable.
Use the exact returned `path` for nested edits.

`wp_read_block` returns `name`, `attributes`, `innerHTML`, `innerContent`, and complete `markup`.
A parent block's text summary does not replace inspection of its children.

## Replace one leaf block

> Replace only the inspected paragraph with “Book an annual boiler service before winter.”
> Preserve its block attributes and inline links unless I explicitly change them.
> Preserve all parent groups, columns, sibling blocks, and publication status.
> Do not call wp_update_post with complete replacement content.

For a plain paragraph with no additional attributes or links, `wp_update_block` accepts:

```json
{
  "post_id": 417,
  "path": [0, 1, 0],
  "block_markup": "<!-- wp:paragraph --><p>Book an annual boiler service before winter.</p><!-- /wp:paragraph -->"
}
```

Use this markup only after inspection establishes that the target is that plain paragraph.
For a styled block, retain its attributes and required markup in the replacement.
`block_markup` must contain Gutenberg block comments, not only a visible text fragment.
The tool uses the first named block from the supplied markup.

The replacement includes the complete target block, including its descendants.
Replacing a group with a paragraph deletes that group's children.
For a text-only task, select the leaf paragraph instead of its parent container.

The tool replaces the target within the parsed tree, then serializes the complete post.
Surrounding nesting remains in the tree, but serialization can change whitespace.
This is not a byte-for-byte patch to the stored document.

## Check the saved and rendered result

1. Inspect the mutation result's `before` and `after` content and block data.
2. Read the target again with `wp_read_block`.
3. List blocks again with `wp_list_blocks`.
4. Check the parent paths, sibling order, and block counts.
5. Read the post again to check its saved content and unchanged status.
6. Open the page or signed-in draft preview in your browser.
7. Check the rendered text, heading levels, links, and desktop and mobile layout.
8. Open the WordPress block editor to check for invalid-block notices.

The hosted assistant has no Frontman browser preview, screenshot tools, or DOM tools.
Human browser review is separate from stored markup inspection.
In the [embedded editor](/docs/integrations/wordpress/#use-the-frontman-editor), use its preview alongside the saved-markup checks.

## Recovery and boundaries

If a response disappears or a write reports an error, read the post and block tree before any retry.
The write can already exist. Reusing an old path after an insertion or move can target a different block.
Block updates have no content-hash argument. Coordinate with other editors and inspect again before a write.

Use native WordPress revisions where available, or your backup, for recovery.
The returned before state is not a plugin-managed rollback.
Use [review and recovery](/docs/wordpress/recovery/) for the shared result checks and recovery rules.

`wp_update_post` with `content` in replacement mode replaces the complete post, not one block.
For an exact stored-text edit with a dry run, use [posts and pages](/docs/wordpress/posts-and-pages/).
Block tools do not edit Elementor's data tree. Use [Elementor editing](/docs/wordpress/elementor/) for those pages.
Shared patterns and dynamic blocks can depend on content outside this post. Inspect that source before a separate task.
For tool access errors, use [WordPress troubleshooting](/docs/wordpress/troubleshooting/).
