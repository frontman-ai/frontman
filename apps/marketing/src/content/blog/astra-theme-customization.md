---
title: 'Astra Theme Customization: Delegate the Work, Review the Result'
seoTitle: 'Astra Theme Customization With Frontman'
description: 'Customize Astra settings, headers, typography, colors, and templates. Delegate the work to Frontman and review changes with screenshots and DOM inspection.'
pubDate: 2026-10-16T00:00:00Z
image: '/blog/astra-theme-customization-cover.png'
imageAlt: 'Frontman cover reading Astra Theme Customization: Delegate the Work, Review the Result'
author: 'Danni Friedland'
articleSection: 'Technical Explainer'
tags: ['wordpress', 'astra', 'website-customization', 'nontechnical-users']
---

## Astra customization starts with settings—and ends with the rendered site

Astra customization happens across theme settings, page-builder options, and the pages visitors actually see. In WordPress, open Appearance > Customize to reach the Customizer; its desktop, tablet, and mobile previews let you inspect different device views. The Astra dashboard also contains Astra settings and information about other features. You can activate modules and options you need, which then become available in the Customizer. [1](https://wpastra.com/docs/manage-customizer-options)

A saved setting is not the same as a checked result. Page builders can override theme settings in specific sections, so a global option may not describe what appears across the website. Frontman is an AI agent that supports Astra customization and can do customization work for people who do not want to operate theme settings manually. It can use screenshots and inspect the DOM—the page structure the browser renders—to review visual output and structure. That is a way to examine the result, not a guarantee of correctness or a replacement for your judgment. [2](https://wpastra.com/docs/typography-free) [3](https://wpastra.com/docs/colors-background)

## Responsive previews show views, but not every setting is responsive

The Customizer’s device simulators show how the site may look in desktop, tablet, and mobile views. The documentation says settings can be adjusted separately for each view, but look for a responsive editing icon beside an option before assuming it supports separate values. That icon indicates responsive editing is available for that option. [1](https://wpastra.com/docs/manage-customizer-options)

Spacing controls have their own details. Margin and padding values may be linked across top, right, bottom, and left; unlinking them allows individual editing. Where unit icons appear, they let you choose a unit. Astra’s example contrasts fixed pixel padding with percentage padding that adjusts to screen or element size. [1](https://wpastra.com/docs/manage-customizer-options)

## Header rows and spacing shape the site’s shared frame

Astra’s free theme offers a drag-and-drop header builder. Its rows are Above, Primary, and Below; elements such as buttons, widgets, and menus can be added and moved into position. The builder’s General tab provides settings for individual elements. [4](https://wpastra.com/guides-and-tutorials/wordpress-customize-header) [5](https://wpastra.com/docs/create-header-with-header-builder)

Header spacing is separate from element placement. The main Design tab provides controls for header width and spacing, while settings for each row include its height and design. Astra’s documentation also describes designing a header for responsive devices. [4](https://wpastra.com/guides-and-tutorials/wordpress-customize-header) [5](https://wpastra.com/docs/create-header-with-header-builder)

These Astra controls explain the available customization options; they do not establish that Frontman operates a particular header control or responsive setting. The product evidence confirms Astra customization support, not control-by-control integration.

## Global typography and colors can be overridden by page builders

Astra’s typography settings are at Appearance > Customize > Global > Typography. The documented base-font controls cover body text and headings, and body font settings also apply to posts. You can set a common heading style and individual sizes for H1 to H6. A page builder can override theme typography in specific sections, so the global setting may not describe every rendered page. [2](https://wpastra.com/docs/typography-free)

Global colors are at Appearance > Customize > Global > Colors. Astra describes Text Color for body text and descriptions, Theme Color for theme elements such as buttons, and Link Color and Link Hover Color for linked text. The background setting applies to the body across the site; when both a background color and image are set, the guide advises adjusting color opacity so the image remains visible. [3](https://wpastra.com/docs/colors-background)

Builder color settings can override theme colors for builder content, while other pages and posts continue to use theme settings. Astra warns that page and post text or heading colors may differ from the Blog Archive or Posts, and that these settings are not automatically synced. Inspect the affected rendered pages rather than treating a global setting as proof that every section matches. [3](https://wpastra.com/docs/colors-background)

## Astra Pro Site Builder adds custom templates and display conditions

A custom template in Astra is a separate Astra Pro capability. Astra’s documentation says the Site Builder module in Astra Pro can create templates for specific purposes and categorizes layouts as Single and Archive. The cited material does not explain the difference between those categories. [6](https://wpastra.com/docs/custom-template) [7](https://wpindigo.com/astra-pro-vs-elementor-pro)

Template settings can specify where a template appears, which user roles can see it, and whether it is visible across devices or only selected devices. The documentation also describes a visibility duration and saving the settings with Publish or Update. These conditions matter because a template’s saved design alone does not tell you where or when it will appear. [6](https://wpastra.com/docs/custom-template)

Astra Pro is a prerequisite for the documented Site Builder module. Frontman’s Astra support does not establish that it supplies an Astra Pro license or unlocks paid features; those remain separate product requirements. [6](https://wpastra.com/docs/custom-template) [7](https://wpindigo.com/astra-pro-vs-elementor-pro)

## Use Frontman as an agent, not as a substitute for review

A general illustrative request could be: “Help customize my Astra site for the changes I describe, then review the result with screenshots and DOM inspection.” This describes a proposed task, not a demonstrated run or a promise that the agent can operate a specific Customizer control. Frontman is the agent doing customization work; your review still matters.

Frontman reports that current users customize sites 10× faster. That is a publisher-reported user observation, not a controlled benchmark or independently verified study; results vary with user experience and the changes being made. Screenshots and DOM inspection can help examine visual output and page structure, but they do not establish perfect verification, exhaustive device coverage, or automatic correctness.

We built Frontman, so this is our product’s role in an Astra workflow, not an independent product evaluation. Describe the customization you want, then review the resulting screenshots and DOM with the distinction between theme settings, builder overrides, and rendered pages in mind. Keep Astra Pro requirements separate from Frontman’s confirmed Astra support. [2](https://wpastra.com/docs/typography-free) [3](https://wpastra.com/docs/colors-background) [6](https://wpastra.com/docs/custom-template) [7](https://wpindigo.com/astra-pro-vs-elementor-pro)

## Sources

1. [This Is Your Customizer — Use It To Create Perfection](https://wpastra.com/docs/manage-customizer-options)
2. [Global Typography Options in the Astra Theme](https://wpastra.com/docs/typography-free)
3. [Global Color and Background Options in Astra Theme](https://wpastra.com/docs/colors-background)
4. [How To Customize the Header in WordPress (Beginner’s Guide)](https://wpastra.com/guides-and-tutorials/wordpress-customize-header)
5. [How To Create a Header With Astra Header Builder](https://wpastra.com/docs/create-header-with-header-builder)
6. [Custom Template in Astra](https://wpastra.com/docs/custom-template)
7. [Astra Pro vs Elementor Pro – Which One is Better in 2026?](https://wpindigo.com/astra-pro-vs-elementor-pro)
