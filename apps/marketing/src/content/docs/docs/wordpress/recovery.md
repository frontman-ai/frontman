---
title: Review and Recover WordPress AI Changes
description: Review WordPress changes made by an AI agent, handle uncertain write results, and choose Elementor rollback, CSS revisions, native recovery or backups.
---

WordPress changes can persist before you review them. Frontman does not provide a universal preview gate or one-click undo.
This guide explains how to review a result and choose a recovery path.
The procedures describe the tool contracts, not a live recovery demonstration.
They apply to either [editing interface](/docs/wordpress/choose-interface/), with the appropriate site and browser context.

## Before an edit

1. Use a staging copy for broad or higher-risk changes.
2. Keep a current backup with a known restore procedure.
3. Identify the site and object before the assistant changes anything.
4. Read the current state and record the fields that the edit will affect.
5. Define what must stay unchanged.

An external assistant does not receive Frontman's embedded preview or browser tools.
Open the affected page yourself for visual review.
For multiple hosted connections, use the [site-selection procedure](/docs/wordpress/multiple-sites/) before any mutation.

## Review the saved result

1. Read the same object again after the tool returns.
2. Compare the saved values with the requested change.
3. Check fields outside the requested scope for unexpected changes.
4. Open the public page in a separate browser.
5. Check the relevant layout, links, forms and mobile widths.

A saved database value does not prove that a public page, cache or third-party system reflects the change.
A screenshot does not prove that a field persisted.
For SEO changes, check [stored metadata and rendered tags separately](/docs/wordpress/seo-metadata/).

## Choose the recovery path

| Changed surface | Available path | Important limit |
| --- | --- | --- |
| Elementor page data or elements | Frontman rollback snapshots | Snapshot scope and current structure determine whether restoration can proceed |
| Additional CSS | Frontman CSS revision tools | Plain CSS only, with fresh scope and fingerprint checks |
| Standard posts or pages | WordPress revisions, trash where applicable, or a supported corrective edit | Revisions depend on WordPress settings and available history |
| Gutenberg blocks | A supported corrective edit or available post revision | No plugin-wide block rollback |
| SEO values and site settings | Restore recorded prior values through supported tools or native controls | No universal rollback transaction |
| WooCommerce products | A supported corrective edit or a backup procedure | Does not reverse orders, emails, stock or payment effects automatically |
| Permanent deletion or external effects | A site-specific recovery process | Recreating a record is not necessarily a reversal |

Do not apply an old value over someone else's newer change without review.
For recurring backup and access responsibilities, use the [WordPress maintenance checklist](/blog/wordpress-maintenance-checklist/#before-you-change-production).

## Restore an Elementor snapshot

First ask:

> On the selected site, read the current Elementor data for this post and list its rollback snapshots. Do not restore anything. Show the snapshot IDs and explain which change each snapshot can reverse.

The assistant uses `wp_elementor_list_rollbacks` with the real `post_id`.
Choose the relevant `rollback_id` from that result, not from a guessed timestamp or another post.
Restoration uses `wp_elementor_restore_rollback` with `post_id`, `rollback_id` and `confirm=true` after your approval.
Hosted calls also require the selected connection's `site_id`.

Approve one restoration at a time. Then ask:

> Read the Elementor data again and compare it with the selected snapshot's intended scope. Report any failure or uncertainty. Do not restore another snapshot automatically.

Open the page yourself after restoration.
A restore can fail when an element moved, disappeared or has a duplicate ID.
Use [Elementor editing and recovery guidance](/docs/wordpress/elementor/) for the surrounding workflow.

## Restore Additional CSS

Use the [Additional CSS revision procedure](/docs/integrations/wordpress/#restore-an-additional-css-revision).
It requires the active stylesheet, current parent post ID, chosen revision and a fresh current-content fingerprint.
These checks reject known stale state, but they do not provide an atomic lock.
WordPress revision retention and save filters still affect the result.

## If a response is lost

Do not repeat the mutation or restoration blindly.
Ask the assistant to read the current object and compare the prior, requested and observed states.
A timeout does not prove that the write failed.
Creating the same draft, product or refund again can cause an additional effect.

If the outcome remains uncertain, stop and choose the next action with the site owner.
For a damaged site or an unavailable restore path, use the backup owner or technical support process.
Revoking access does not reverse completed changes; see [permissions and revocation](/docs/wordpress/permissions/).
