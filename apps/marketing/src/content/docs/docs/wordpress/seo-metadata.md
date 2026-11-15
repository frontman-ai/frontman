---
title: Edit WordPress SEO Metadata with AI
description: Inspect supported WordPress SEO integrations, update one title or description, and check saved overrides separately from rendered public metadata.
---

Use Frontman to inspect SEO overrides and update one supported target. The result is a saved title or description that you can compare with the page's public HTML.
Metadata changes do not guarantee search rankings or the snippet that a search engine chooses.

The example prompts are code-backed illustrative procedures, not a record of a live SEO test.

## Before you start

- [Choose your editing interface](/docs/wordpress/choose-interface/) and complete its setup.
- For an external assistant, read [MCP permissions](/docs/wordpress/permissions/) before you authorize changes.
- Use a staging site, a current backup, and one known page.
- Save the current SEO values before any write.

For hosted MCP, ask the assistant to call `list_sites`, then `wp_get_site_info` with the selected `site_id`.
In the embedded editor, read `wp_get_site_info` for the current installation without the hosted-only `site_id`.
Inspect `seo_capabilities.provider`, `read`, `write`, and the separate unavailable reasons.
For terms and archives, also inspect `seo_capabilities.targets.term` and `seo_capabilities.targets.post_type_archive`.
The advertised tools and current capability result determine what the assistant can do. `seo_unavailable_reason` describes update availability, not necessarily read availability.

## Supported SEO integrations

| Integration | Current scope |
| --- | --- |
| Yoast SEO Free | Reads and writes for eligible individual items, taxonomy terms, and custom post type archives, subject to runtime support. |
| SureRank | Reads stored title, description, and focus keyphrase for eligible individual items. No writes or archive SEO tools. |
| Conflicting SEO plugins | The dedicated route stops rather than choose an owner. Yoast plus SureRank also disables the route. |
| Other providers | No generic SEO metadata write route. Use the provider's authorized WordPress admin forms. |

The dedicated tools require WordPress 6.9 or later and the provider's loaded runtime methods. Missing sanitizers can disable writes while reads remain available.
Yoast SEO Premium and detected competing SEO plugins block this route. Do not bypass these limits with arbitrary metadata or option writes.

## Choose the correct target

Every hosted call requires `site_id` from `list_sites`, in addition to the arguments in this table.
The call examples use that hosted shape. In the embedded editor, omit `site_id` and use the advertised WordPress arguments.
The names and IDs in the examples are placeholders for values from your site.

| Target | Read tool and target arguments | Update tool and editable fields |
| --- | --- | --- |
| Post, page, or eligible individual CPT item | `wp_read_seo` with `id: 123` | `wp_update_seo`: `title`, `description`, `focus_keyphrase` |
| Public editable taxonomy term | `wp_read_term_seo` with `taxonomy: "category"` and exactly one of `slug: "guides"` or `term_id: 45` | `wp_update_term_seo` with `taxonomy`, resolved `term_id`, and `title` or `description` |
| Public custom post type archive | `wp_read_post_type_archive_seo` with `post_type: "product"` | `wp_update_post_type_archive_seo` with `post_type` and `title` or `description` |

Discover actual taxonomy names, post types, and archive URLs with `wp_get_site_info`.
An archive is a generated route, not a backing post or page. Do not pass a term ID or an archive page ID to `wp_update_seo`.
Archive tools require administrator access on the current site. Terms also require term edit permission. CPT archives require Yoast settings permission.

## 1. Inspect one page before the change

> Read the selected staging site's SEO capabilities. Do not change anything.
> Find the intended page with wp_list_posts. Read the page with wp_read_post.
> Read its stored SEO values with wp_read_seo. Record its ID, permalink, and all three SEO fields.
> Propose one factual meta description based on the page content. Wait for approval.

For page discovery, use `post_type: "page"`, `search`, `per_page`, and `page` with `wp_list_posts`.
Read the selected result before approval. Similar titles do not establish the intended page. The stored SEO values are overrides, not computed tags or expanded provider templates.

## 2. Update only the approved description

Before approval, make sure that the description accurately summarizes the page.
Keep its title, content, focus keyphrase, URL, and publication status unchanged.

> Update only the approved SEO description for page 123 on the selected staging site.
> Leave all other fields unchanged. Read the saved SEO values again. Stop after this page.

For a supported Yoast writer, the call has this shape:

```text
wp_update_seo({
  "site_id": "<staging-site-id>",
  "id": 123,
  "description": "The approved factual summary of this page."
})
wp_read_seo({"site_id": "<staging-site-id>", "id": 123})
```

These SEO tools do not have a `confirm` argument. Ask for approval before the write anyway. Omitted fields remain unchanged. An update must include at least one supported field.

### Empty strings restore inheritance or defaults

- For individual items, `""` deletes the Yoast override and restores provider defaults.
- For terms, `""` clears the override and restores inheritance from taxonomy templates.
- For CPT archives, `""` restores Yoast defaults, including a potentially nonempty title template.

An empty string does not mean “hide this tag.”
Archive tools do not edit focus keyphrases, canonical URLs, social tags, or arbitrary Yoast settings.

## 3. Check persistence, then inspect public HTML

1. Read the same target again with its matching SEO reader.
2. Compare the saved values with the approved description and recorded unchanged fields.
3. Open the public staging URL yourself.
4. Inspect its HTML `<title>` and `<meta name="description">` tags separately.

Hosted external assistants do not receive the embedded Frontman preview, screenshots, or DOM tools.
Provider templates, sanitization, caches, and indexable state can make public tags differ from stored values.
Lighthouse scores do not establish that the intended SEO metadata persisted or appears in public HTML.

## Recovery and unavailable tools

If a write fails or its response disappears, read the same target before any retry.
An error can report `failed`, `partial`, or `uncertain` state. Some fields can persist despite an error.
Archive errors can also leave the indexable refresh incomplete. Do not retry automatically or assume that a before/after result supplies an undo command.

If restoration is necessary and the writer remains supported, request approval to restore the recorded fields manually.
Then read the target again and inspect its public tags separately. For read-only or unsupported targets, use the provider's authorized admin forms instead.
See [review and recovery](/docs/wordpress/recovery/) and [connection troubleshooting](/docs/wordpress/troubleshooting/).
