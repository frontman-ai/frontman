---
title: 'Team Collaboration for Design Systems Without the Engineering Bottleneck'
pubDate: 2026-02-16T05:00:00Z
description: 'You built the system. You maintain it across teams. But every token tweak still routes through a developer. Frontman changes that.'
author: 'Danni Friedland'
image: '/blog/team-collaboration-cover.png'
tags: ['collaboration', 'workflow', 'design-systems']
updatedDate: 2026-03-20T00:00:00Z
---

You spent months building your design system. Tokens, components, spacing scales, the whole thing. Two product teams use it now. It works. Mostly.

Then someone on the growth team notices the card component has 24px padding and it should be 16px to match the updated token. Here is what happens next:

1. You file a ticket: "Update card padding to match spacing-4 token"
2. It sits in the backlog. The engineers are shipping the new onboarding flow
3. Two days later a developer picks it up, asks which card variant you mean
4. You send a Figma link and a screenshot with a red circle
5. The developer makes the change, opens a PR
6. You review it — close, but they used a hardcoded value instead of the token
7. Another round. Another day
8. Merged. Four days for a token alignment

Four days. For a change you could describe in one sentence. Not because the developers are slow — they are doing real work. Your design system update just cannot compete with the onboarding deadline.

This is the part that stings: you _own_ this system. You know exactly what the change should be. But you cannot make it yourself, because only developers can touch the code.

### The Real Cost

You have felt this. Every designer and PM at a growing startup has. The system drifts. Not because anyone decided to let it drift, but because the queue of trivial visual fixes never reaches the top of the sprint. There is always something more urgent.

So the card padding stays wrong for three weeks. Then another team copies that card into a new feature. Now the wrong padding is in two places. Then someone notices the button tokens are stale too. The system you built to create consistency is _losing_ consistency because you cannot maintain it at the speed it needs.

The problem is not tooling. The problem is access. The people who care most about the design system — who built it, who maintain it, who notice when it drifts — are locked out of the one place where it actually lives: the code.

### What It Looks Like When You Can Just Fix It

With Frontman, you open the app in your browser. You click the card. You type: "Use spacing-4 token for padding." Frontman edits the source file and hot-reloads. You see the result. If it looks right, you commit. The engineer reviews a clean one-line diff in the PR.

Five minutes. No ticket. No waiting for sprint capacity. The engineer still reviews the code — nothing ships without their sign-off. But they review a _finished change_ instead of spending three days playing telephone about which card variant you meant. This [framework-aware AI approach](/blog/ai-coding-agents-blind-to-ui/) means the tool sees what you see.

Your PM can do this too. That CTA copy that has said "Get Started" since launch even though you repositioned the product two months ago? They open the page, click the button, type the new copy, commit. Done before the next standup.

### How This Works at Your Scale

You have two, maybe three product teams now. You are past the stage where one designer and one developer sit next to each other and just talk. But you are not so big that you need a platform team or a formal RFC process for spacing changes. You are in the middle — big enough that coordination hurts, small enough that adding process feels wrong.

Frontman fits this stage. Here is what each role gets:

- **You (design)** maintain the system directly. Token updates, spacing fixes, component tweaks — you make them in the browser, describe what you want, and commit. No IDE. No file paths. No asking someone else to translate your Figma redlines into code.
- **Your PM** fixes copy, updates CTAs, and adjusts content without filing tickets. The landing page actually reflects the positioning you agreed on last week, not the positioning from three sprints ago.
- **Your engineers** review PRs instead of making trivial visual changes. They focus on the onboarding flow, the API integration, the performance work — the problems that actually need engineering judgment.

Every change still goes through code review. Every change is a standard Git diff. Your branch protection rules apply. Nothing bypasses the process — only the routing changes.

### The Objections You Are Already Thinking

**"What if someone breaks something?"**
Every change is a Git commit on a branch. It goes through the same PR process as engineering work. If the diff is bad, it does not get merged. Frontman shows you the result via hot-reload before you commit — if the layout breaks, you see it immediately and undo it. The code review gate catches everything else.

**"We tried giving non-devs access to the repo before."**
Giving people VS Code access is not the same thing. Frontman [differs from general-purpose agents](/blog/what-are-framework-aware-ai-coding-tools/) — it's a constrained tool. You click an element, describe a change in plain English, and Frontman edits the source file. You cannot accidentally refactor the state management. You can update the padding. That is the right level of access for the right people.

**"Our engineers will push back on this."**
Show them their PR queue. Count the tickets that say "update spacing," "fix typo," "change button color." Ask them if those are the problems they want to spend their week on. Every designer-authored PR is a PR the engineer did not have to write. They still review it — they just did not have to context-switch to create it.

### What Changes

Right now your design system is a shared asset that only one discipline can touch. That constraint made sense when the codebase was new and the team was three people. It does not make sense now — and understanding [how Frontman actually sees the browser](/blog/frontman-launch/) shows why. You have a real system, real tokens, real components — and the people who built them should be able to maintain them.

Move the visual maintenance to the people who own it. Your engineers get their sprint capacity back. Your design system stays consistent across teams. Your PM stops waiting three days to fix a typo. Nobody is blocked on anyone else for changes that take thirty seconds to make and thirty seconds to review.

That is not a workflow hack. That is your team actually working the way it already should.

[Try Frontman](https://frontman.sh) — [one install command](/blog/getting-started/), works with your existing project. Read about [how Frontman keeps every change safe and reviewable](/blog/security/).
