---
title: Manage Multiple WordPress Sites with AI
description: Select the correct WordPress connection before an AI edit, distinguish sites with matching hostnames, and check one staging SEO change safely.
---

Use Frontman to select the correct WordPress installation before a content or SEO change. This procedure updates one staging page's SEO description while the production site remains outside the write scope.
The same page ID can exist on several sites, so the connection matters as much as the content ID.

The example prompts are code-backed illustrative procedures, not a record of a live multi-site test.

## Before you start

- Use [the shared setup guide](/docs/wordpress/connect-agent/) for each intended installation.
- Connect each installation under the same Frontman account that your assistant uses.
- Read [permissions and revocation](/docs/wordpress/permissions/) before you authorize site access.
- Keep a current backup of the staging site before the change.
- Choose one staging page with a supported Yoast SEO writer for this exercise.

Several saved connections do not establish WordPress Multisite support. This guide does not describe network-wide administration, subsite discovery, or automatic access to every network site.

## 1. List account-scoped connections

Ask your assistant:

> Call list_sites. Do not change anything.
> Show each connection ID and hostname label.
> Do not select a site for edits until we identify the staging installation.

`list_sites({})` takes no arguments.

The `sites` result contains an `id` and a hostname-only `label` for each accessible saved connection.
It does not include a full URL, scheme, port, or path. Two installations on the same host can therefore have identical labels.
The list is scoped to the signed-in Frontman account, not every installation on that host. A saved connection does not prove that its credentials still work.

If the list is empty or incomplete, use [connection troubleshooting](/docs/wordpress/troubleshooting/) before any edit. Do not guess a connection ID from a URL or another account.

## 2. Read each candidate's site information

> Read wp_get_site_info for each candidate connection with the repeated hostname.
> Compare site_name, site_url, and home_url with my intended staging installation.
> Show the selected connection ID and full URLs. Do not change anything.
> If the installation remains ambiguous, ask me which one to use.

For each candidate, use its own returned ID:

```text
wp_get_site_info({"site_id": "<candidate-site-id>"})
```

`site_url` identifies the configured WordPress URL. `home_url` identifies the configured public home URL.
These values can distinguish installations under different paths or ports. Compare the returned URLs with your known staging URL before approval.
Site names, themes, and plugins are useful context, but cloned sites can share those values.

The optional `include_installation_paths: true` argument is for an explicit installation-location request.
It exposes private hosting details. It does not prove unique site identity or the public document root. Keep it omitted for this procedure.

## 3. Inspect the page on the selected site

`site_id` is the Frontman connection ID from `list_sites`.
The separate `id` argument is the WordPress post or page ID within that installation. Do not use a URL or a post ID as `site_id`.

> On the selected staging connection only, find the “Delivery” page with wp_list_posts.
> Read the candidate with wp_read_post. Show its ID and permalink.
> Read the site's SEO capabilities and the page's stored SEO values.
> Save the before-state. Propose one accurate description. Wait for approval.

Use `wp_list_posts` with `post_type: "page"`, `search: "Delivery"`, `per_page: 5`, and `page: 1`.
Pass the selected `site_id` to that call and every subsequent site tool.
Read the selected page with `wp_read_post` and its returned numeric `id`.
If `seo_capabilities.write` is false, stop this exercise before the write. See [supported SEO providers and targets](/docs/wordpress/seo-metadata/) for the capability limits.

## 4. Approve one site and one field

Before approval, compare the displayed site URL, page permalink, and proposed description with your intended target.
Do not approve a request that identifies the site only by its hostname label.

> On the selected staging connection only, update page 123's SEO description to the approved text.
> Leave all other fields unchanged. Do not write to production or any other site.
> Read the saved SEO values again. Stop after this one page.

The supported call shape is:

```text
wp_update_seo({
  "site_id": "<selected-staging-site-id>",
  "id": 123,
  "description": "The approved factual delivery summary."
})
wp_read_seo({"site_id": "<selected-staging-site-id>", "id": 123})
```

Replace both example IDs with the values from the selected installation.
The SEO writer has no `confirm` argument. Your explicit approval still defines the task boundary. Metadata changes do not guarantee search rankings or search-engine snippets.

## 5. Check saved values and public output separately

Compare the fresh `wp_read_seo` result with the approved description and recorded unchanged fields. Then open the selected staging permalink yourself.
Inspect its public HTML title and meta description separately from the saved-value result.
Hosted external assistants do not receive the embedded Frontman preview, screenshots, or DOM tools.

## Recovery and cross-site limits

If a response disappears, read the same target on the same connection before any retry.
If the wrong site changed, stop all further writes and record the affected `site_id` and page ID.
After separate approval, restore the recorded fields manually only through a supported writer.
Then read that target again and inspect its public HTML separately.

Cross-site edits are not a transaction. One site's success does not reverse another site's failure.
Do not request an unreviewed bulk write across all connected sites. For each additional site, establish its identity, capabilities, before-state, and approval separately.
Use [review and recovery](/docs/wordpress/recovery/) before any corrective edit or restoration.
