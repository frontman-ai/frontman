# Blog Deduplication Optimization Report

**Run ID:** `autoresearch-blog-dedup-2026-04-14`
**Content type:** Blog post set (3 posts with 30-40% content overlap)
**Optimization goal:** Eliminate duplicate content signals to fix Google indexing
**Score threshold:** 80 | **Holistic set score:** 86.6

## Problem

Three blog posts published within 8 days (Feb 15-23, 2026) share 30-40% overlapping content:
- Same pain narrative ("file a ticket, wait for sprint") in all 3
- Runtime context / "Frontman sees" value prop in 2 of 3
- Design system consistency angle in all 3
- "Click element, describe change" workflow in all 3
- Framework-aware / one-line install in all 3
- "Changes go through PR review" trust signal in all 3

Google likely treating them as near-duplicates, indexing only one.

## Winners

### 1. `introducing-frontman` — "Every AI Coding Agent Is Blind to Your UI"
**Score:** 83.6 | **Role:** Problem diagnosis
**Biggest score jump:** Variant 7 (80.0) → Variant 12 (83.6) — naming specific agents + "architectural not intelligence" framing

Structure:
- Open: Name the agents (Claude Code, Cursor, Copilot). They share a blind spot.
- Body: 4 concrete scenarios — source says X, screen shows Y, agent has no idea.
- Close: The gap is architectural. Define "runtime context gap."
- Zero product pitch. Link to launch post.

**Runner-ups:**
- "AI Agents Are Guessing What Your UI Looks Like" (83.2)
- "AI Agents Edit Files. Users See Pixels." evolved (82.0)

### 2. `frontman-launch` — "Frontman Launch: Ship UI Fixes From the Browser"
**Score:** 84.4 | **Role:** Product announcement
**Biggest score jump:** Multi-promise structure (#7, 80.4) + problem-reference-not-re-explain pattern → 84.4

Structure:
- 1-line problem reference + link to problem post
- What Frontman Does (capabilities with examples)
- For Teams With a Design System (differentiator)
- How It Works (one paragraph)
- What Changes for Your Team (workflow)
- Honest Tradeoffs (what works, what doesn't)
- Why Open Source (security)
- Get Started (CTA)

**Runner-ups:**
- "One-Line Install. Your Code Never Leaves Your Machine." (82.4)
- "Click. Describe. Ship. Here's How Frontman Works." (82.0)

### 3. `getting-started` — "Frontman Quickstart: Change a Button Color in 5 Minutes"
**Score:** 84.8 | **Role:** Tutorial
**Biggest score jump:** Generic tutorial (#8, 80.4) → hyper-specific single-outcome walkthrough (#15, 84.8)

Structure:
- One specific outcome: change a button to use your primary color
- Prerequisites checklist
- Install (per framework)
- Connect AI provider
- ONE edit walkthrough with diff
- Done. Next steps.

**Runner-ups:**
- "From Install to Your First UI Edit" evolved (83.2)
- "Your First Frontman Edit: A 5-Minute Tutorial" (81.6)

## Cross-Breed Analysis

| Dimension | Score |
|-----------|-------|
| Content overlap (lower = better differentiation) | 90 |
| Internal linking logic | 88 |
| SEO keyword differentiation | 85 |
| Audience clarity | 88 |
| Set coherence | 82 |
| **Holistic set score** | **86.6** |

## Key Patterns That Won

1. **Specificity over generality** — naming agents, naming exact scenarios, ONE button color change
2. **Honest limitations** — tradeoffs sections scored highest with skeptical founder
3. **Zero content duplication** — each post stays in its lane, links to siblings for other angles
4. **Action-oriented titles** — "Ship UI Fixes" > "Introducing Frontman"
5. **Concrete examples** — diffs, code blocks, specific CSS changes

## Linking Strategy

```
introducing-frontman (problem)
  → frontman-launch (here's the solution)
  → /blog/runtime-context-gap/ (deep dive)

frontman-launch (announcement)
  → introducing-frontman (why this matters)
  → getting-started (try it now)

getting-started (tutorial)
  → frontman.sh (full docs)
  → frontman-launch (what else can it do)
```

## Next Steps

Write the actual content for all three posts following the winning structures above.
