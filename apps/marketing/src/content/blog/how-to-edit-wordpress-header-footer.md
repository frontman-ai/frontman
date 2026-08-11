---
title: 'How to Edit the Header and Footer in WordPress'
seoTitle: 'How to Edit the Header and Footer in WordPress'
pubDate: 2026-08-11T00:00:00Z
description: 'Find and edit your WordPress header or footer in a block theme, classic theme, widget area, or Elementor without changing the wrong page.'
author: 'Itay Adler'
articleSection: 'Tutorial'
image: '/blog/how-to-edit-wordpress-header-footer-cover.png'
imageAlt: 'Dark cover reading Edit the right layer with Header, Footer, Template, and Builder labels'
tags: ['wordpress', 'tutorial', 'elementor']
faq:
  - question: 'How do I edit the header and footer in WordPress?'
    answer: 'First identify what controls them. Block themes use Appearance > Editor > Patterns. Classic themes usually use Appearance > Customize or Widgets. Elementor sites can use Elementor > Theme Builder. Custom themes may define them in code.'
  - question: 'Why can I not edit my WordPress header from the page editor?'
    answer: 'The header is usually a global template part, theme setting, widget area, or page-builder template. It is separate from the content of an individual page.'
  - question: 'Where is the footer editor in WordPress?'
    answer: 'For a block theme, open Appearance > Editor > Patterns and find the Footer template part. Classic themes may place footer controls under Appearance > Customize or Appearance > Widgets.'
  - question: 'How do I edit an Elementor header or footer?'
    answer: 'If Elementor Theme Builder controls the site, open Elementor > Theme Builder, select Header or Footer, and edit the active template. Check its display conditions before publishing.'
---

You open a WordPress page, click **Edit**, and find everything except the header or footer you need to change.

That is normal. A WordPress page usually owns its main content. The header and footer often live in a template part, theme setting, widget area, navigation menu, or page-builder template instead.

**Quick answer:** Check **Appearance > Editor** first. If it exists, open **Patterns** and find the Header or Footer template part. If it does not exist, check **Appearance > Customize**, **Appearance > Widgets**, or your page builder's Theme Builder.

## Find What Controls the Header or Footer

Do not start by editing theme files. Identify the active controller first.

| What you see in wp-admin | Likely controller | Where to edit |
|---|---|---|
| **Appearance > Editor** | Block theme | **Editor > Patterns > Template Parts** |
| **Appearance > Customize** | Classic or hybrid theme | Theme-specific Header, Footer, Menus, or Widgets panel |
| Footer columns under **Appearance > Widgets** | Widget-enabled classic theme | The matching footer widget area |
| **Elementor > Theme Builder** | Elementor Theme Builder template | Active Header or Footer template |
| None of these controls affect the site | Custom theme or another builder | Theme options, builder templates, or custom code |

The header and footer do not have to share one controller. A classic theme can use the Customizer for its logo, **Appearance > Menus** for navigation, and widgets for footer columns.

Before changing anything, create a backup and use staging when possible. Header and footer changes can affect every page that uses the same template.

## Edit a Header or Footer in a Block Theme

Block themes use the WordPress Site Editor for global site structure. WordPress only shows **Appearance > Editor** when a block theme is active.

1. Open **Appearance > Editor**.
2. Select **Patterns**.
3. Find **Template Parts** in the Patterns view.
4. Select **Header** or **Footer**.
5. Edit the relevant blocks.
6. Click **Save**.
7. Review the list of affected templates and template parts before confirming.

The exact labels can vary between WordPress versions and themes. Block themes commonly use reusable template parts, but a theme can place header or footer blocks directly inside a template.

WordPress notes that a saved Header or Footer template part can affect every page using that part. Its official [Site Editor guide](https://wordpress.org/documentation/article/site-editor/) also explains how templates and template parts relate.

### If the Header or Footer Is Locked

A lock icon can mean that you selected a theme pattern rather than an editable custom pattern. WordPress does not let you edit bundled theme patterns directly.

Open the pattern's actions menu and select **Duplicate**. Edit the copy under **My patterns**, then replace the original pattern inside the Header or Footer template part. Duplicating a pattern alone does not change the live template. The official [Site Editor Patterns guide](https://wordpress.org/documentation/article/site-editor-patterns/) documents the locked and editable pattern types.

A block can also have editing restrictions. Select the parent Group, Template Part, or Navigation block and inspect its lock settings before assuming that WordPress is broken.

### If You Need to Change the Menu

Select the Navigation block inside the header. Open its List View to identify the active menu and its items.

WordPress can store multiple menus, so editing a menu does not guarantee that the current header uses it. The [Navigation block guide](https://wordpress.org/documentation/article/navigation-block/) explains how to identify the selected menu, edit links, and manage its structure.

## Edit a Header or Footer in a Classic Theme

Classic themes do not use the Site Editor. Their controls depend on what the theme registered.

1. Open **Appearance > Customize**.
2. Look for **Header**, **Footer**, **Site Identity**, **Menus**, or **Widgets**.
3. Change one setting.
4. Review it in the Customizer preview.
5. Publish only after the preview shows the correct global result.

The [WordPress Customizer documentation](https://wordpress.org/documentation/article/customizer/) confirms that each theme can expose different controls. Some themes provide complete header builders. Others expose only a logo, site title, menu location, or footer widget area.

If **Customize** is absent, confirm which theme is active under **Appearance > Themes**. Block themes hide most Customizer controls because their global structure belongs in the Site Editor.

### Edit Header and Footer Menus

For a classic or hybrid theme, open **Appearance > Menus**.

1. Select the menu you want to change.
2. Add, remove, rename, or reorder items.
3. Check its **Display location**.
4. Assign it to the header or footer location defined by the theme.
5. Save the menu.

The [Appearance Menus guide](https://wordpress.org/documentation/article/appearance-menus-screen/) explains why menu locations vary by theme. A saved menu can exist without being assigned to the visible header or footer.

### Edit a Widget-Based Footer

Some classic themes build footer columns from widget areas.

1. Open **Appearance > Widgets**.
2. Find an area named **Footer**, **Footer 1**, **Footer Column**, or similar.
3. Edit the blocks or widgets in that area.
4. Save and review the public site.

Widget-area names come from the theme. The [classic Widgets documentation](https://wordpress.org/documentation/article/appearance-widgets-screen-classic-editor/) notes that themes can register widget areas in headers and footers.

## Edit an Elementor Header or Footer

If opening a page with Elementor does not expose the header or footer, Elementor Theme Builder may control it separately.

1. Open **Elementor > Theme Builder**. Older Elementor versions can list Theme Builder under **Templates**.
2. Select **Header** or **Footer**.
3. Find the active template.
4. Select **Edit**.
5. Make the change and review responsive layouts.
6. Check the template's display conditions.
7. Publish the update.

Display conditions determine where the template appears. A correct edit can seem ineffective when another template has priority or the active template excludes the page you are viewing.

Elementor documents these workflows in its guides to [editing a WordPress header](https://elementor.com/help/header-site-part/) and [creating or modifying a footer](https://elementor.com/help/footer-site-part/). Theme Builder features require an Elementor plan that includes them.

Do not assume that every Elementor site uses Elementor for global templates. A site can use Elementor for page content while its WordPress theme still controls the header and footer.

## When None of These Changes Work

Work through this sequence:

1. Confirm that the edit saved, then clear only the cache layers serving stale output.
2. Confirm that you edited the template assigned to the current page.
3. Check for separate desktop and mobile header templates.
4. Check page-builder display conditions.
5. Look for theme-specific options outside standard WordPress menus.
6. Inspect whether a child theme or custom plugin replaces the global template.

If the header or footer is hard-coded in theme PHP, do not edit the parent theme directly. A theme update can overwrite that change. Use a child theme or ask the site's developer to move the structure into an editable template.

## Use Frontman to Inspect Candidate Structures

We build Frontman, so this is the product-specific route.

[Frontman for WordPress](/wordpress/) works beside a live preview and can inspect candidate WordPress structures, including block templates, template parts, menus, widgets, and Elementor page content. It cannot always prove which candidate controls rendered output.

Install Frontman on a staging site, open `/frontman`, and start with an inspection request:

> Inspect the candidate WordPress structures for this header. Do not change anything. Report what you can verify and what remains unknown.

After Frontman verifies a supported candidate structure, make one bounded request:

> Change the header button label from "Book a demo" to "View pricing." Keep its URL and styling unchanged. Show me the result in the preview.

Frontman is experimental. It does not support every theme, custom plugin, hard-coded template, or page-builder configuration. Keep a backup, start on staging, and review the changed site at desktop and mobile widths.

## The Rule to Remember

If you cannot edit a WordPress header or footer from the page editor, the content probably belongs to a different layer.

Find that layer before changing anything:

- Block theme: **Appearance > Editor > Patterns**.
- Classic theme: **Appearance > Customize**.
- Widget footer: **Appearance > Widgets**.
- Classic navigation: **Appearance > Menus**.
- Elementor template: **Elementor > Theme Builder**.
- Custom implementation: theme options, a child theme, or custom code.

For supported sites, [install Frontman from the WordPress Plugin Directory](https://wordpress.org/plugins/frontman-agentic-ai-editor/) and let it inspect candidate structures beside the page preview. Start on staging and review every change.
