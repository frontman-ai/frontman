---
"@frontman/client": minor
"@frontman/frontman-astro": minor
---

Replace ~170 hardcoded dark-theme colors with semantic CSS variable tokens, enabling proper light and dark theme support. Add `isLightTheme` config option to Astro middleware (matching Next.js). The client widget now renders correctly in both light and dark modes instead of only looking right with a dark background.
