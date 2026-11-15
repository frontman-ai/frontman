---
title: Create and Edit WordPress Posts and Pages with AI
description: Create draft WordPress posts and pages with Frontman, edit exact content fragments, preserve publication status, and check saved content before review.
---

Use Frontman to create a draft article or service page, then update one passage without replacing the complete page.
Keep publication as a separate decision.
Clear titles, useful answers, and descriptive links help readers understand your content.

## Before you start

1. [Choose your editing interface](/docs/wordpress/choose-interface/) and complete its setup.
2. Open the intended installation in the embedded editor, or select it through the external assistant.
3. For hosted MCP, read [permissions](/docs/wordpress/permissions/) and select the site from `list_sites`.
4. Prepare a staging copy and a current backup.

For hosted MCP, the assistant passes the selected `site_id` to site-specific tools.
The embedded editor uses the current installation instead; MCP setup is not a prerequisite.
The arguments here describe the WordPress tools within that site.

**CAUTION: Use staging for the first edit.**
Updates to published content take effect immediately, before browser review.
Post creation and updates do not require a plugin `confirm` argument. An assistant can request approval separately.

## Inspect before you create

The prompts here are illustrative, code-backed procedures, not a tested live demonstration.
Replace example URLs and IDs with values from your site.

> On https://your-site.example, inspect posts and pages about boiler servicing. Do not change anything.
> Show matching IDs, titles, types, and publication status. Read the closest match before proposing a new draft.

`wp_list_posts` accepts `post_type`, `status`, `search`, `per_page`, and `page`.
Its default status is `publish`, so request `status="draft"` separately to find existing drafts.
Use `post_type="post"` for articles and `post_type="page"` for pages.
Read a selected result with `wp_read_post`, using `id`.

The read result includes stored `content`, `content_sha256`, `status`, `slug`, `permalink`, categories, and tags.
Stored content includes block markup, not the final rendered page.

## Create one draft

> Create one draft page titled “Boiler servicing in Bristol” on the selected staging site.
> Use only the service facts I supplied. Include a short introduction and a useful booking link.
> Do not publish it. Do not change existing pages, menus, or SEO metadata.

For example, `wp_create_post` accepts:

```json
{
  "title": "Boiler servicing in Bristol",
  "post_type": "page",
  "status": "draft",
  "slug": "boiler-servicing-bristol",
  "content": "<!-- wp:paragraph --><p>Arrange a boiler service in Bristol.</p><!-- /wp:paragraph -->"
}
```

For an article, use `post_type="post"` instead.
The tool defaults to draft, but explicit `status="draft"` makes the request clear.
WordPress sanitizes slugs and applies its uniqueness rules. The returned `after.slug` is the saved value.
The result includes the new `id`, `after` fields, and a permalink. A permalink does not establish public access to a draft.

1. Read the returned ID with `wp_read_post`.
2. Check that `status` is `draft`.
3. Check the saved title, content, and slug.
4. Open the draft through WordPress while signed in.
5. Check the rendered copy and links before your normal publication process.

## Update one passage without publication

> Read draft page 417 again. Replace only its introductory paragraph with my supplied paragraph.
> First use wp_update_post in edit_many mode with dryRun=true.
> Preserve its draft status, title, slug, categories, tags, and template. Do not replace the complete content.
> Stop after the dry run and show the proposed change.

Use the observed ID, not the example `417`.
For `wp_update_post`, the bounded edit uses these arguments:

| Argument | Value |
| --- | --- |
| `id` | The inspected post or page ID |
| `mode` | `"edit_many"` |
| `expected_current_sha256` | The fresh `wp_read_post.content_sha256` |
| `edits` | One pair containing exact `oldText` and replacement `newText` |
| `dryRun` | `true` for inspection, then `false` for the approved save |

Each old fragment must occur exactly once. Multiple fragments must not overlap.
The save must use the same hash and edits as the dry run.
`edit_many` accepts content edits only. Update other fields separately only after an explicit request.
Omitted status preserves the current status. For an already-published page, the saved edit changes public content immediately.

The save receipt includes `edit_count`, `before_sha256`, and `after_sha256`, not complete before/after content.
Read the post again to check the actual text and unchanged status.
Then check the rendered page in your browser, including heading order, links, and mobile readability.

## Recovery and limits

If the response disappears or a save reports an error, read the current post before any retry.
For an uncertain creation, search recent drafts first to avoid duplicate pages.
A save filter can change content after the write. An error does not always mean that nothing changed.
A stale hash requires a fresh read and a new edit proposal. Hash checks are best-effort, not an atomic lock.
Use WordPress revisions where available, or your backup. Before/after data is not a general undo system.
Use [review and recovery](/docs/wordpress/recovery/) for the result checks and surface-specific recovery boundaries.

`content` in the default replacement mode replaces the complete stored content.
For nested blocks, use [Gutenberg editing](/docs/wordpress/gutenberg/). For builder content, use [Elementor editing](/docs/wordpress/elementor/).
An excerpt is not an SEO meta description. Use the separate [SEO metadata guide](/docs/wordpress/seo-metadata/).

The hosted assistant has no Frontman preview, screenshots, or DOM tools. Human browser review is separate.
In the [embedded editor](/docs/integrations/wordpress/#use-the-frontman-editor), use its preview alongside the saved-content checks.
For connection or access errors, use [WordPress troubleshooting](/docs/wordpress/troubleshooting/).
