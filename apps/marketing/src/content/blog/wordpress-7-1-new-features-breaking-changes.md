---
title: 'WordPress 7.1: New Features, Breaking Changes, and Upgrade Checklist'
seoTitle: 'WordPress 7.1 Features, Breaking Changes, and Upgrade Checklist'
pubDate: 2026-08-12T00:00:00Z
description: 'WordPress 7.1 launches August 19, 2026. See its major features, compatibility risks, deferred changes, and practical upgrade checklist.'
author: 'Danni Friedland'
articleSection: 'Operational Audit'
image: '/blog/wordpress-7-1-new-features-breaking-changes-cover.png'
imageAlt: 'WordPress 7.1 new features, breaking changes, and upgrade checklist cover'
tags: ['wordpress', 'tutorial']
faq:
  - question: 'When is WordPress 7.1 released?'
    answer: 'WordPress 7.1 is scheduled for August 19, 2026. Until the final release is available, test the release candidate only on staging, local, or disposable sites.'
  - question: 'What is new in WordPress 7.1?'
    answer: 'The largest user-facing changes include responsive block styles, configurable breakpoints, client-side media processing, a persistent editor toolbar, improved Notes, and accessibility improvements. Developers also get expanded Abilities, SVG Icon, and editor APIs.'
  - question: 'Does WordPress 7.1 have breaking changes?'
    answer: 'The clearest compatibility risk is the post editor becoming unconditionally iframed. Plugins that reach into the editor through the global document or window may break. The jQuery UI 1.14.2 update also removes several old APIs.'
  - question: 'Should I update to WordPress 7.1 immediately?'
    answer: 'Test the final release with your production theme and plugin stack on staging first. Check editing, media uploads, forms, checkout, login, publishing, custom admin screens, and rollback before updating a business-critical site.'
---

WordPress 7.1 is scheduled for **August 19, 2026**. Its most visible changes are responsive block styles, browser-side media processing, better collaboration notes, and more consistent navigation inside the editor. Its most important compatibility change is less visible: the post editor is now always loaded in an iframe.

The iframe change deserves more attention than the headline features. Most sites will never notice it, but one outdated editor extension can block publishing completely.

**Quick answer:** Do not treat WordPress 7.1 as a routine maintenance update. Back up the site, clone production to staging, and test the editor, media uploads, custom admin interfaces, forms, checkout, login, and publishing before updating production.

This article reflects the [WordPress 7.1 Field Guide](https://make.wordpress.org/core/2026/08/05/wordpress-7-1-field-guide/) and release-candidate documentation checked on **August 12, 2026**. WordPress 7.1 is not final yet. We label compatibility concerns as risks unless official documentation identifies a confirmed behavior change.

## WordPress 7.1 Release Status

| Item | Status on August 12, 2026 |
|---|---|
| Release phase | Release candidate |
| Final release | Scheduled for August 19, 2026 |
| Production use | Wait for the final release |
| Safe testing | Staging, local development, or a disposable test site |
| This article | Pre-release audit; final-release verification pending |

The Field Guide reports more than 310 closed Core tickets, including more than 180 bug fixes. It also points to hundreds of Gutenberg enhancements and fixes. Those totals describe release scope, not reasons to update blindly. Site compatibility still depends on the active theme, plugins, custom blocks, and admin extensions.

## The Biggest WordPress 7.1 Changes for Site Owners

### Responsive Styles Move Into the Block Editor

WordPress 7.1 adds responsive style states for supported blocks. Editors can set Tablet and Mobile overrides for typography, color, backgrounds, borders, dimensions, spacing, and layout. Themes can also define custom breakpoint widths in `theme.json`.

The default breakpoints are:

| State | Default range |
|---|---|
| Mobile | Up to 480px |
| Tablet | Above 480px and up to 782px |
| Base style | All widths unless overridden |

This is useful, but it creates another place where responsive behavior can live. A theme's CSS, page-builder settings, Global Styles, and individual block overrides can all affect the same element. Test existing pages at real viewport widths after upgrading. The official [responsive styles dev note](https://make.wordpress.org/core/2026/08/05/responsive-block-styles-and-configurable-viewports-in-wordpress-7-1/) documents the generated media queries and `theme.json` format.

### Media Processing Can Move Into the Browser

On desktop Chrome and Edge 137 or newer, WordPress 7.1 can process images in the browser with WebAssembly before uploading them. Chrome on Android requires version 146. Firefox and Safari fall back to server-side processing, although Safari can still decode HEIC images in the browser.

Potential benefits include fewer PHP memory failures, lower server CPU use, HEIC conversion, AVIF support without server-side AVIF support, and automatic upload retries. The change affects more than upload speed. Image work now runs in a different environment, which changes assumptions made by some media plugins.

If a site uses image optimization, watermarking, CDN synchronization, custom image sizes, strict Content Security Policy, or remote-media imports, test those workflows directly. The `wp_generate_attachment_metadata` filter still runs, but server-specific hooks such as `wp_image_editors`, `image_memory_limit`, and `image_make_intermediate_size` do not run on the client-side path. See the official [client-side media processing guide](https://make.wordpress.org/core/2026/07/22/client-side-media-processing-in-wordpress-7-1/) for browser gates and fallbacks.

The Media Library grid now uses infinite scrolling by default. Users can restore pagination from their profile. Sites with large libraries or custom Media Library extensions should test browsing, selection, and keyboard behavior.

### Editor Navigation Becomes More Consistent

The WordPress toolbar now remains visible in the Post and Site Editors unless Distraction Free mode is active. The ambiguous site-icon back action is replaced with a dedicated chevron, while the site icon and title stay available in the toolbar.

This should reduce navigation confusion for editors. Plugins that add toolbar nodes should still verify that those nodes behave correctly in the Site Editor. WordPress documents the new behavior in its [persistent toolbar dev note](https://make.wordpress.org/core/2026/07/13/consistent-navigation-in-wordpress-7-1-with-persistent-toolbar/).

### Notes and Visual Review Improve

WordPress 7.1 expands Notes with richer formatting, mentions, multiple conversations on a block, and inline notes on text selections. Revision and editor-navigation changes also make reviewed work easier to locate.

These are collaboration improvements, not real-time co-editing. Real-time collaboration did not make WordPress 7.1.

### Accessibility Improvements Reach Admin and Editor Screens

WordPress 7.1 improves semantics, focus behavior, contrast, keyboard and pointer interaction, list-table structure, setup screens, widgets, navigation, and editor interfaces. It also introduces a shared mechanism for accessible informational tooltips.

Custom admin screens should be tested with keyboard navigation and visible focus after the update. Do not assume a Core accessibility fix automatically repairs custom plugin markup.

## WordPress 7.1 Breaking Changes and Compatibility Risks

| Change | Who may be affected | What to test |
|---|---|---|
| Post editor always uses an iframe | Custom blocks and plugins that access global `document` or `window` | Block controls, canvas events, custom CSS, metaboxes, editor extensions |
| jQuery UI 1.14.2 | Older admin plugins and custom interfaces | Dialogs, date pickers, drag-and-drop, removed APIs |
| Client-side media processing | Media, CDN, optimization, watermark, and upload plugins | Formats, custom sizes, metadata hooks, CSP, fallback browsers |
| Responsive block styles | Themes and builders with their own breakpoint systems | Desktop, tablet, mobile, Global Styles, per-block overrides |
| Persistent toolbar | Plugins adding admin-bar nodes | Post Editor, Site Editor, Distraction Free mode |
| Abilities API changes | Plugins exposing or consuming WordPress abilities | Discovery, schemas, validation, permissions, auditing |

### Confirmed Change: The Post Editor Is Always Iframed

In WordPress 7.0, a lower-version block could cause the post editor to fall back to a non-iframed mode. WordPress 7.1 removes that compatibility behavior. The post editor is always iframed, regardless of theme type or block API version.

Code that reaches for global `document` or `window` may now look at the admin document instead of the editor canvas. WordPress recommends deriving `ownerDocument` and `defaultView` from an element inside the canvas and using `useRefEffect` for listeners tied to canvas elements. The official [WordPress 7.1 iframe note](https://make.wordpress.org/core/2026/08/03/iframed-editor-changes-in-wordpress-7-1/) contains migration guidance.

Most blocks already work. Treat this as a targeted compatibility test, not proof that every block plugin will fail.

### Confirmed Change: jQuery UI Removes Old APIs

WordPress 7.1 updates jQuery UI from 1.13.3 to 1.14.2. WordPress enables the back-compat layer for the jQuery 1.11 API, but jQuery UI removed `$.fn._form`, `$.ui.ie`, `$.ui.safeActiveElement`, and `$.ui.safeBlur`.

Core does not use those functions. Old plugins or custom admin code might. Search the codebase for those names and test interactive admin components. The [jQuery UI update note](https://make.wordpress.org/core/2026/07/29/jquery-ui-updated-to-1-14-2-in-wordpress-7-1/) identifies the removed APIs.

### Test Risk: Media Hooks and Security Headers

Client-side media processing uses a cross-origin-isolated editor on supported Chromium versions. Sites with strict CSP need `blob:` in `worker-src` for the processing worker. External resources and plugins that import media through browser-side cross-origin requests also need testing.

The feature has automatic fallbacks, so one failed capability check should not stop uploads. A transparent fallback can still hide that expected optimization or plugin behavior did not run. Test one upload in a supported Chromium browser and one in Firefox or Safari to exercise both paths.

### Test Risk: Responsive Style Collisions

Responsive block styles are additive. They do not remove theme CSS or builder breakpoints. A page can therefore look correct in the editor preview and still conflict with theme rules on the frontend.

Test representative templates rather than one blank page. Include navigation, columns, groups, buttons, images, and any block with custom spacing or typography.

## What Did Not Make WordPress 7.1

Pre-release coverage can become wrong before launch. These proposed or experimental changes are **not included** in WordPress 7.1 according to the current Field Guide:

- **Real-time collaboration:** Testing continues, but it is not enabled in the release.
- **React 19:** The upgrade was deferred beyond WordPress 7.1.
- **On This Day widget:** The proposed dashboard widget was not included.
- **Classic block removal:** The Classic block remains available in the inserter.
- **Broader merge proposals:** Some foundations landed, but the larger projects remain under development.

If another WordPress 7.1 article still lists these as shipped features, check whether it relies on Beta 1 rather than the release-candidate Field Guide.

## WordPress 7.1 Upgrade Checklist

1. **Back up files and database.** Confirm that the backup can be restored, not merely created.
2. **Clone production to staging.** Use the same theme, plugins, PHP version, configuration, and representative content.
3. **Update themes and plugins on staging first.** Read vendor compatibility notes and keep copies of the versions currently running.
4. **Test the Post and Site Editors.** Open existing posts with custom blocks, metaboxes, and editor extensions. Check browser-console errors.
5. **Test responsive layouts.** Review desktop, tablet, and mobile widths on the frontend, not only in editor previews.
6. **Test media workflows.** Upload JPEG, PNG, WebP, HEIC, AVIF, or animated GIF files that reflect actual use. Verify custom sizes, optimization, CDN, and metadata behavior.
7. **Test critical transactions.** Submit forms, complete checkout, log in, publish, schedule, and edit content.
8. **Test custom admin interfaces.** Check dialogs, date pickers, drag-and-drop controls, toolbar nodes, and plugin settings.
9. **Review server evidence.** Check PHP logs, browser console, failed requests, scheduled actions, and background jobs.
10. **Prove restoration on a separate target.** Restore the backup into a disposable environment, record recovery time, and verify login, media, and critical data.
11. **Define go/no-go criteria.** Do not deploy with new fatal errors, blocked publishing, failed checkout, missing media, broken authentication, or unresolved editor-console errors.
12. **Schedule production deployment.** Freeze content changes where necessary, name the operator and rollback decision-maker, and document cache and CDN purge order.
13. **Set rollback triggers.** Roll back for fatal errors, data corruption, failed payments, inaccessible administration, or critical publishing failures.
14. **Monitor after deployment.** Review errors, scheduled jobs, email delivery, payments, webhooks, cache behavior, and editor activity for an agreed period.

After the upgrade passes, keep the first production change small and reviewable. Frontman's [WordPress workflow](/wordpress/) can help inspect supported site state and review rendered changes, but its current public demonstration pins WordPress 7.0.2 and is not evidence of WordPress 7.1 compatibility.

## Plugin and Theme Developer Checklist

- Test every custom block in the unconditionally iframed post editor.
- Replace global canvas `document` and `window` assumptions with element-derived references.
- Search for removed jQuery UI APIs.
- Test custom image sizes, media metadata hooks, format conversion, and CSP.
- Review responsive Global Styles and custom breakpoint behavior.
- Test toolbar nodes in both Post and Site Editors.
- Review Abilities API schemas, validation, permissions, and invocation logging.
- Update the WordPress.org `Tested up to` value only after completing compatibility tests.

## What WordPress 7.1 Changes for AI Integrations

WordPress 7.1 expands the Abilities API introduced in WordPress 6.9. Changes include custom input and output validation filters, an invocation action for auditing, more consistent schemas, selective response fields, typed REST inputs, filtering, execution lifecycle hooks, and a unified public-exposure flag.

That makes abilities easier for REST, MCP, WebMCP, AI, and other programmatic clients to discover and interpret. It does not make every exposed action safe. Plugins still own permission checks, input boundaries, approval behavior, logging policy, and the decision to expose an ability publicly.

The official [Abilities API improvements note](https://make.wordpress.org/core/2026/07/31/abilities-api-improvements-in-wordpress-7-1/) warns that the invocation hook receives raw input before validation and permission checks. Do not log that input indiscriminately; it may contain personal or sensitive data.

Frontman currently uses its own reviewed WordPress tool workflow. This article does not claim that Frontman uses WordPress 7.1's new Abilities APIs.

## Frontman's Pre-Test WordPress 7.1 Assessment

Frontman 3.0.0 supports WordPress 6.0 or newer, requires PHP 7.4 or newer, and is tested through WordPress 7.0.2. It has not passed its runtime suite against WordPress 7.1. The table below is an architectural assessment, not a compatibility result.

| WordPress 7.1 area | Frontman relationship | Current boundary |
|---|---|---|
| Responsive block styles and custom viewports | Expected to preserve block attributes; 7.1 fixture test pending | Frontman has no dedicated Global Styles or `theme.json` breakpoint editor |
| Pseudo states, gradients, minimum width, and text shadow | Expected to preserve block markup; 7.1 fixture test pending | Additional CSS is supported, but 7.1 style-state controls are not |
| Client-side media processing | Separate server-side Media Library workflow | Does not use the new browser-side WASM pipeline |
| Notes and @mentions | Not integrated | Frontman has its own conversation and review workflow |
| Revisions | Direct support for Additional CSS revisions | No general post-revision browser |
| Persistent toolbar and editor iframe | Low direct coupling; 7.1 runtime test pending | Frontman runs outside the Gutenberg canvas |
| Abilities API | Not integrated | Frontman uses its own permissioned tool registry |
| jQuery UI 1.14.2 | No direct dependency; 7.1 runtime test pending | Other active plugins can still fail |

Frontman's Gutenberg tools read complete block attributes and serialize supported changes through WordPress. Its preview can render fixed desktop, tablet, mobile, and custom widths. That makes it useful for checking responsive output, but it does not provide a `theme.json` or Global Styles editor.

Frontman uploads supported attachments through WordPress PHP APIs, not the new browser-side media pipeline. It also has its own permissioned tool registry rather than the Abilities API. Notes, @mentions, DataViews, the SVG Icon API, and WordPress design tokens are not Frontman integrations.

Frontman has low direct coupling to several high-risk 7.1 changes because it does not inject into Gutenberg, depend on jQuery UI, or replace Media Library screens. Lower coupling reduces expected risk; it does not establish compatibility. Frontman should not claim WordPress 7.1 support until its runtime suite passes against the final release.

## Where Frontman Fits in a WordPress 7.1 Upgrade

Yes, with the **audit, staging review, and post-upgrade checks**. Frontman does not currently install WordPress Core updates, update plugins or themes, create hosting backups, run WP-CLI, inspect PHP error logs, or restore a full database. Keep those upgrade operations in your host, deployment system, or established maintenance workflow.

Frontman's useful role is to inspect the WordPress state it can access, exercise representative pages beside a live preview, identify visible regressions, make supported content or layout corrections, and verify the rendered result.

Frontman can inventory the WordPress version, active theme and plugins, post types, block templates, menus, widgets, Additional CSS, Elementor, WooCommerce, and known cache plugins. Save that report outside the site. It is not a backup.

It can also capture representative pages before and after the upgrade at fixed viewport sizes. Screenshots, DOM inspection, computed styles, and same-origin interactions make visual differences easier to diagnose. Frontman does not produce automated pixel diffs or persist a formal upgrade baseline.

| Upgrade risk | Frontman-assisted check | Boundary |
|---|---|---|
| Responsive styles | Compare fixed desktop, tablet, mobile, and custom viewports; inspect computed styles and block markup | Cannot inspect `theme.json` files or edit Global Styles directly |
| Always-iframed editor | Confirm Frontman's standalone route and frontend preview still load; inspect affected page output | Cannot validate every third-party Gutenberg editor extension from the frontend preview |
| Client-side media processing | Upload a supported attachment through Frontman's separate Media Library path and verify rendered output | Does not exercise WordPress 7.1's editor-side WASM upload pipeline |
| Templates and navigation | Read templates, template parts, menus, navigation posts, and rendered header/footer | Custom theme PHP files remain inaccessible |
| Additional CSS | Read current CSS, list revisions, compare hashes, and restore one confirmed revision if needed | Does not restore arbitrary theme or plugin files |
| jQuery UI changes | Exercise visible frontend interactions in the preview | Cannot fully inspect wp-admin dialogs or plugin settings screens |
| WooCommerce | Read supported store data and inspect product/cart/checkout presentation | Do not use Frontman as payment or order-integrity automation |
| Cache effects | Detect supported cache plugins, clear known caches, then reload preview | Host, CDN, reverse-proxy, and unknown plugin caches may remain |

When a visible regression maps to supported WordPress state, Frontman can repair posts, blocks, templates, menus, widgets, Additional CSS, Elementor content, or supported WooCommerce data. It should inspect first, change one state at a time, clear known caches, reload, and verify with a screenshot. Destructive actions and site-wide CSS changes require confirmation.

Example prompt:

> Run a read-only WordPress 7.1 regression check on this staging site. Inventory the active theme, plugins, templates, menus, widgets, Additional CSS, Elementor, WooCommerce, and cache plugins. Review the homepage, one post, contact page, and product page at 1440px, 768px, and 390px. Report each route as pass, changed, or blocked with screenshots. Do not change anything.

Frontman cannot replace full backups and restoration, Core/plugin/theme updates, WP-CLI, infrastructure logs, security scanning, payment and webhook tests, or assistive-technology testing. Its Lighthouse tool is not available in WordPress sessions. Use Frontman as browser-grounded review and supported repair inside a broader upgrade runbook, not as updater or infrastructure monitor.

## Should You Upgrade Immediately?

- **Site owner with a standard site:** Wait for the final release, confirm backups, then test staging.
- **Business-critical or WooCommerce site:** Wait for theme, plugin, and host compatibility evidence, then run the full transaction checklist.
- **Plugin or theme developer:** Test the current release candidate now, especially the iframe editor and media paths.
- **Site with custom editor code:** Treat iframe compatibility as the release blocker.
- **Site using older admin UI libraries:** Audit jQuery UI usage before production deployment.

WordPress 7.1 offers meaningful improvements, especially for responsive editing and media-heavy workflows. The safest upgrade is not the fastest click on **Update Now**. It is the one whose editor, uploads, customer flows, and rollback have already passed on staging.

## Sources and Update Log

Primary sources checked on August 12, 2026:

- [WordPress 7.1 Field Guide](https://make.wordpress.org/core/2026/08/05/wordpress-7-1-field-guide/)
- [WordPress 7.1 release-candidate announcement](https://wordpress.org/news/2026/08/wordpress-7-1-release-candidate-1/)
- [Iframed Editor Changes in WordPress 7.1](https://make.wordpress.org/core/2026/08/03/iframed-editor-changes-in-wordpress-7-1/)
- [Responsive block styles and configurable viewports](https://make.wordpress.org/core/2026/08/05/responsive-block-styles-and-configurable-viewports-in-wordpress-7-1/)
- [Client-Side Media Processing in WordPress 7.1](https://make.wordpress.org/core/2026/07/22/client-side-media-processing-in-wordpress-7-1/)
- [jQuery UI updated to 1.14.2](https://make.wordpress.org/core/2026/07/29/jquery-ui-updated-to-1-14-2-in-wordpress-7-1/)
- [Abilities API improvements in WordPress 7.1](https://make.wordpress.org/core/2026/07/31/abilities-api-improvements-in-wordpress-7-1/)

**Update log**

- **August 12, 2026:** Published pre-release audit from the Field Guide and release-candidate documentation.
- **August 19, 2026:** Pending final release verification.
