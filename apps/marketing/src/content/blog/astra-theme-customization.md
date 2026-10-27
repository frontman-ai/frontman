---
title: 'Astra Theme Customization: Delegate the Work, Review the Result'
seoTitle: 'Astra Theme Customization With Frontman'
description: 'Customize Astra layouts, headers, typography, colors, and templates. Follow the manual steps or give Frontman a concrete task, then check the result.'
pubDate: 2026-10-16T00:00:00Z
image: '/blog/astra-theme-customization-cover.png'
imageAlt: 'Frontman cover reading Astra Theme Customization: Delegate the Work, Review the Result'
author: 'Danni Friedland'
articleSection: 'Technical Explainer'
tags: ['wordpress', 'astra', 'website-customization', 'nontechnical-users']
---

## Astra customization starts with the change you want

A more compact header. Less empty space on mobile. Headings that match your brand. You know the result you want, but Astra customization can involve theme settings, page-builder overrides, and several pages to check.

Frontman is our AI agent for making changes to your existing WordPress site. Instead of finding every setting yourself, describe the result you want and ask the agent to inspect what controls it. Frontman can use screenshots and inspect the DOM—the page structure the browser renders—to help check the result.

The sections below explain the manual Astra route and give you a task to delegate to Frontman. The prompts are suggested starting points, not recordings of completed Astra workflows. Ask the agent to identify the available editing path first. If a required Astra setting is unsupported, use the manual route for that step.

**Before you edit:** Work on a staging copy and keep a backup. WordPress edits can affect the connected site immediately, including published pages. Preview is not a universal approval gate.

## Adjust responsive layout and spacing

For checks beyond spacing, use the [mobile layout and usability checklist](/blog/how-to-make-wordpress-website-mobile-friendly/#before-you-publish-check-the-experience-and-recovery-path).

**What you want:** Less empty space on a phone without squeezing the desktop layout.

### The manual Astra route

In WordPress, open Appearance > Customize. The Customizer’s device simulators show desktop, tablet, and mobile views. Look for a responsive editing icon beside a setting before assuming it supports separate values for each view. [1](https://wpastra.com/docs/manage-customizer-options)

Margin and padding values can be linked across top, right, bottom, and left. Unlink them to edit each side separately. Where unit icons appear, you can choose a unit: pixels provide fixed spacing, while percentages scale with the relevant screen or element size. [1](https://wpastra.com/docs/manage-customizer-options)

### Do it with Frontman

Describe where the spacing feels wrong instead of hunting through controls and guessing values. Give the agent both the change and the layout you want to preserve.

> The homepage has too much space between sections on mobile. Inspect what controls that spacing, then reduce it without changing the desktop layout. Check the result at mobile and desktop widths and tell me which widths you checked.

**What to check afterward:** Comfortable spacing, no horizontal overflow, and an unchanged desktop layout. Screenshots at a few widths do not cover every device, so also open the page on a phone.

## Make the header more compact

First [identify what controls the visible header](/blog/how-to-edit-wordpress-header-footer/#find-what-controls-the-header-or-footer). An Elementor template or custom implementation may own it instead of Astra's header settings.

**What you want:** A header that leaves more room for your content while keeping navigation usable.

### The manual Astra route

Astra’s free theme offers a drag-and-drop header builder. Its rows are Above, Primary, and Below. You can add and move elements such as buttons, widgets, and menus. The builder’s General tab provides settings for individual elements. [4](https://wpastra.com/guides-and-tutorials/wordpress-customize-header) [5](https://wpastra.com/docs/create-header-with-header-builder)

Element placement and spacing are separate. The main Design tab provides header width and spacing controls, while each row has height and design settings. Astra also documents header design for responsive devices. [4](https://wpastra.com/guides-and-tutorials/wordpress-customize-header) [5](https://wpastra.com/docs/create-header-with-header-builder)

### Do it with Frontman

Start with the visible header rather than learning which row or setting controls each part. Tell the agent what must stay so that a smaller header does not lose an important link or button.

> Inspect this header and identify the available editing path. Make it more compact while keeping the logo, navigation links, and contact button. On mobile, keep the menu accessible. Explain any unsupported steps before changing anything.

**What to check afterward:** The logo stays readable, links work, and the mobile menu opens and closes correctly. Check another page too: a shared header change can affect more than the page you started on.

## Match typography and colors to your brand

**What you want:** Consistent headings and buttons, without unexpected changes to body text or other pages.

### The manual Astra route

Open Appearance > Customize > Global > Typography. Astra provides base-font controls for body text and headings, including a common heading style and individual sizes for H1 to H6. Body font settings also apply to posts. Page builders can override theme typography in specific sections. [2](https://wpastra.com/docs/typography-free)

For colors, open Appearance > Customize > Global > Colors. Text Color controls body text and descriptions. Theme Color applies to theme elements such as buttons. Link Color and Link Hover Color control linked text. The body background supports a color and an image; adjust color opacity so the image remains visible when you use both. [3](https://wpastra.com/docs/colors-background)

Builder colors can override theme colors, and page or post colors are not automatically synced with archive colors. A saved global setting is not proof that every page matches. [3](https://wpastra.com/docs/colors-background)

### Do it with Frontman

Delegate the investigation as well as the edit. You do not need to diagnose whether Astra or a page builder controls an inconsistent heading before asking for a change. Supply your actual font names and color values so the agent has a clear target.

> Use our brand font and colors listed below for the homepage headings and buttons. Inspect what controls them and find any page-builder overrides that cause inconsistencies. Keep body text readable. Explain whether the proposed changes also affect other pages before applying them.

**What to check afterward:** Headings and buttons match your supplied brand values, text has readable contrast, and hover states remain clear. Check a blog post and archive page for unintended changes too.

## Plan shared templates with Astra Pro

**What you want:** A consistent blog-post design that appears on the right content, not across unrelated pages.

### The manual Astra route

Astra Pro’s Site Builder module provides custom templates, with layouts categorized as Single and Archive. Template settings specify where a template appears, which user roles can see it, and which devices show it. The documentation also describes a visibility duration. Save the settings with Publish or Update. [6](https://wpastra.com/docs/custom-template)

Astra Pro is required for this Site Builder workflow. Frontman does not supply an Astra Pro license or unlock paid theme features. [6](https://wpastra.com/docs/custom-template)

### Do it with Frontman

Start with the intended design and where it belongs. Ask Frontman to inspect the prerequisites and available tools before you commit to a template workflow.

> Check whether this site has the Astra Pro features needed for a shared blog-post template. I want the design to apply to blog posts, not landing pages. Identify the available editing path and explain any unsupported steps before making changes.

This is a prerequisite and planning task, not a promise that Frontman can create or configure every Astra Pro template. Use Site Builder for any unsupported steps.

**What to check afterward:** The template appears on the intended posts and stays off unrelated pages. Check its user-role, device, and duration rules as well as its design.

## Try your first Astra update with Frontman

[Set up Frontman for WordPress](/docs/integrations/wordpress/), then open it from the WordPress admin menu. Setup requires administrator access, Frontman sign-in and service access, and an AI-provider connection.

Choose one small change on your staging site. Use a prompt above, replacing the page and design details with your own. Ask Frontman to explain what it changed and show the result. Check the page yourself, then refine the request if something still looks wrong.

You provide the direction; the agent takes on the inspection and supported editing work. The manual Astra instructions remain available whenever you need them.

## Sources

1. [This Is Your Customizer — Use It To Create Perfection](https://wpastra.com/docs/manage-customizer-options)
2. [Global Typography Options in the Astra Theme](https://wpastra.com/docs/typography-free)
3. [Global Color and Background Options in Astra Theme](https://wpastra.com/docs/colors-background)
4. [How To Customize the Header in WordPress (Beginner’s Guide)](https://wpastra.com/guides-and-tutorials/wordpress-customize-header)
5. [How To Create a Header With Astra Header Builder](https://wpastra.com/docs/create-header-with-header-builder)
6. [Custom Template in Astra](https://wpastra.com/docs/custom-template)
