---
title: 'Make an Elementor Video Play on Scroll With Frontman'
seoTitle: 'How to Make a Video Play on Scroll in Elementor'
description: 'Build a scroll-controlled Elementor video with GSAP, then use Frontman to inspect, edit, preview, and roll back the page safely.'
pubDate: 2026-07-17T00:00:00Z
image: '/blog/play-video-on-scroll-elementor-with-frontman-cover.png'
imageAlt: 'Frontman cover reading Make an Elementor Video Play on Scroll With Frontman'
author: 'Danni Friedland'
articleSection: 'Tutorial'
tags: ['wordpress', 'elementor', 'tutorial', 'gsap']
video:
  name: 'Play Video on Scroll in Elementor'
  description: 'Nicolai Palmkvist demonstrates a GSAP ScrollTrigger technique that ties self-hosted Elementor video playback to page scroll.'
  youtubeId: 's7n9vRFvmM0'
  uploadDate: '2024-07-23'
faq:
  - question: 'How do you make a video play as you scroll in Elementor?'
    answer: 'Use a self-hosted muted video, provide enough scroll distance, keep the video visible while scrolling, and map GSAP ScrollTrigger progress to the video currentTime value. Test the result on staging across desktop and mobile.'
  - question: 'Can Frontman add a scroll-controlled video to an Elementor page?'
    answer: 'Frontman can inspect Elementor page structure, update element settings, add generic widgets, edit exact fragments in HTML widgets, save Elementor rollback snapshots, and refresh Elementor CSS. The exact implementation still depends on the page and Elementor version.'
  - question: 'Does a scroll-controlled video have to be exactly 30 fps?'
    answer: 'No universal web standard requires exactly 30 fps for this effect. The source tutorial recommends 30 fps as a practical target, but smooth seeking depends on the encoded file and browser. Test the actual asset instead of treating one frame rate as a guarantee.'
---

You scroll. The video advances. You reverse direction. The video rewinds with the page.

**Quick answer:** In Elementor, this effect combines a self-hosted muted video, a tall scroll area, a sticky video layer, and JavaScript that maps scroll progress to the media `currentTime`. [GSAP ScrollTrigger](https://gsap.com/docs/v3/Plugins/ScrollTrigger/) supplies the scrubbed scroll progress. Frontman can make the Elementor editing loop easier by inspecting the page structure, updating the relevant widgets, showing the page beside the chat, and preserving Elementor rollback snapshots.

This guide is based on [Nicolai Palmkvist's original video tutorial](https://www.youtube.com/watch?v=s7n9vRFvmM0). We do not own or claim the video. It is embedded below with credit because it provides the visual demonstration; the analysis, technical sourcing, and Frontman workflow here are original.

<iframe width="100%" height="400" src="https://www.youtube-nocookie.com/embed/s7n9vRFvmM0" title="Nicolai Palmkvist tutorial: play video on scroll in Elementor" frameborder="0" referrerpolicy="strict-origin-when-cross-origin" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen style="border-radius: 8px; margin: 2rem 0;"></iframe>

If the embedded player is unavailable, [watch the original tutorial on YouTube](https://www.youtube.com/watch?v=s7n9vRFvmM0).

## What the original workflow actually needs

The tutorial shows several separate jobs that are easy to blur together:

1. Add a full-width container and self-hosted video widget ([00:47](https://www.youtube.com/watch?v=s7n9vRFvmM0&t=47s)).
2. Mute the video, hide player controls, and remove unwanted container padding ([01:16](https://www.youtube.com/watch?v=s7n9vRFvmM0&t=76s)).
3. Give the section substantial vertical height so the page has distance over which to scrub the video ([02:13](https://www.youtube.com/watch?v=s7n9vRFvmM0&t=133s)).
4. Insert the JavaScript through an Elementor HTML widget ([02:38](https://www.youtube.com/watch?v=s7n9vRFvmM0&t=158s)).
5. Keep the video sticky while the visitor moves through that scroll distance ([03:05](https://www.youtube.com/watch?v=s7n9vRFvmM0&t=185s)).
6. Correct the stacking order so later page content appears above or after the pinned video ([04:12](https://www.youtube.com/watch?v=s7n9vRFvmM0&t=252s)).

Elementor published a similar [official GSAP and video-scroll tutorial](https://elementor.com/blog/gsap-animations-made-faster-video-scroll-tutorial/). Its setup also uses a self-hosted muted video, hidden controls, scroll space, sticky positioning, an HTML widget, and ScrollTrigger code. That independent primary source supports the overall pattern without requiring us to copy code from the video description.

## How the scroll-to-video link works

This is not normal autoplay. The page treats the scrollbar as a media scrubber.

The browser exposes video position through [`HTMLMediaElement.currentTime`](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/currentTime). Reading it returns playback position in seconds. Setting it seeks the media to a new time when that part of the file is available.

ScrollTrigger provides a progress value between the configured start and end positions. Its `scrub` behavior links animation progress to scrollbar progress, while its pinning features can keep an element fixed during the active range. The implementation then maps scroll progress from `0` to `1` onto video time from `0` to its duration.

That distinction matters when debugging:

- **Video does not move:** inspect whether duration is available and whether the script selected the intended video element.
- **Video jumps or stalls:** test the actual encoded asset and browser rather than assuming Elementor layout is the only cause.
- **Video scrolls away:** inspect sticky or ScrollTrigger pin configuration.
- **Later content sits behind it:** inspect stacking context and section spacing.
- **Mobile feels wrong:** use a smaller breakpoint-specific setup or disable the effect rather than forcing the desktop interaction onto every screen.

The source video recommends converting the asset to 30 fps ([04:37](https://www.youtube.com/watch?v=s7n9vRFvmM0&t=277s)). Treat that as the creator's practical recommendation, not a universal browser requirement. Neither the media API nor ScrollTrigger requires one exact frame rate. Smooth seeking must be tested with the real encoding.

## Make the Elementor edit with Frontman

Frontman does not remove the need for GSAP or browser media behavior. It removes much of the admin-screen navigation and blind copy-paste work around them.

Frontman for WordPress is currently beta. Use a staging site, keep a normal backup, and review every change. It requires WordPress 6.0 or later, PHP 7.4 or later, an authenticated WordPress user with the `manage_options` capability (normally an administrator), and an active Elementor installation for Elementor-specific tools.

### Evidence behind this workflow

This guide separates three evidence layers. Palmkvist's recording demonstrates the manual Elementor layout and scroll interaction at the timestamps above. Frontman capabilities below were verified against the plugin's version 1.3.0 implementation and current WordPress integration documentation on July 17, 2026. We did not run this exact page-and-video combination on a live site, so browser behavior, Elementor-version differences, encoding performance, and site-specific results remain staging checks rather than demonstrated outcomes.

### 1. Open the target page beside Frontman

Install [Frontman for WordPress](/wordpress/), sign in with the required capability, then append `/frontman` to the page URL. For example, open `/landing-page/frontman` to load the chat beside a preview of that page.

Frontman can inspect the compact Elementor tree before changing anything. That matters here because a page may contain several containers, videos, and HTML widgets. The agent should identify the intended element IDs instead of guessing from visible order.

### 2. Give the agent an inspect-first prompt

Use a prompt with explicit boundaries:

> On this Elementor page, make the existing self-hosted video progress with vertical scroll. First inspect the Elementor page structure and the schemas for unfamiliar widgets. Reuse the existing video and container where possible. Keep the video muted, hide controls, preserve unrelated content, provide a defined scroll range, and keep the video visible during that range. Use GSAP ScrollTrigger to map scroll progress to video currentTime only after media duration is available. Respect reduced-motion preference by providing a non-scrubbed fallback. Update or add an Elementor HTML widget only if needed. Save rollback information, flush Elementor CSS, and stop for confirmation before any full-page-data replacement.

This prompt is deliberately stricter than "make this animate." Frontman exposes granular Elementor operations for inspecting page structure, updating one element, adding a generic widget, and replacing an exact fragment inside an existing HTML widget. Full page-tree replacement is available but requires confirmation and should not be the default.

### 3. Review the visible result

Do not stop at a successful tool response. In the live preview:

- Scroll forward and backward through the entire active range.
- Confirm the video begins and ends at sensible positions.
- Confirm page content after the effect remains reachable.
- Test desktop and mobile widths.
- Reload once to catch initialization or cache problems.
- Check the reduced-motion path.
- Verify unrelated Elementor sections did not change.

Frontman can flush Elementor CSS after visual changes. A separate WordPress caching plugin or CDN can still serve stale output, so clear that layer when the preview and public page disagree.

### 4. Roll back if the structure is wrong

Elementor mutations made through current Frontman tools save private rollback snapshots. Frontman can list and restore those snapshots, with confirmation required for restoration.

That is useful, but it is not a substitute for a site backup. Frontman does not guarantee one-click undo for every WordPress mutation. Keep staging and backup discipline outside the agent.

## Where Frontman is easier, and where it is not

**Frontman is easier when the hard part is locating and coordinating existing Elementor data.** It can inspect the page tree, identify widgets, update targeted settings, edit an HTML fragment, flush Elementor CSS, and keep the preview in the same workflow.

**Elementor AI may be simpler when your whole workflow already lives inside the Elementor editor.** Elementor has its own official prompt-driven tutorial for this effect. Frontman is more useful when the request crosses page structure, widget data, preview verification, and rollback concerns.

**Frontman does not make arbitrary generated code trustworthy.** GSAP loading, selectors, media readiness, mobile behavior, accessibility, and asset performance still require review. Current Elementor settings also vary by version and widget configuration.

For accessibility, honor [`prefers-reduced-motion`](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion). Large scrubbed motion can be uncomfortable for some visitors. A static poster, ordinary playback control, or disabled scrub behavior is better than ignoring an explicit reduced-motion preference.

Also review current [GSAP installation and licensing guidance](https://gsap.com/docs/v3/Installation) before shipping third-party scripts.

## Use the video as the reference, not the code source

Watch the embedded tutorial to understand the intended interaction. Then implement against your own page structure, current Elementor controls, and primary GSAP and browser documentation.

On a staging copy, install [Frontman for WordPress](/wordpress/), open the target page with `/frontman`, and submit the inspect-first prompt above. Review the full scroll range before deciding whether the effect belongs in production.
