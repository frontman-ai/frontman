---
title: 'The AI Said My Code Was Fine. It Hadn''t Read It.'
pubDate: 2026-03-25T05:00:00Z
description: 'AI code reviews pattern-match the genre of analysis without doing the work. A structured reasoning template fixes this — here is the one we use.'
author: 'Danni Friedland'
image: '/blog/ai-code-review-hallucination-cover.png'
tags: ['ai', 'developer-tools']
---

Last month I asked my AI assistant to review a function that parsed webhook payloads from three different providers. Each provider sent timestamps differently. One used Unix epoch seconds, another ISO 8601. The third embedded the timezone in the field name rather than the value. The function normalized all three into UTC before storing them.

The AI said it looked good. "Handles edge cases well." "The timezone conversion logic is sound."

I shipped it. Two days later, the third provider's timestamps were off by three hours. I went back to the review. The model had never traced where the timezone value actually came from. It saw a function that *looked like* it handled timezones — it had `pytz` and `datetime` imports, a `utc` variable — and produced a review that *looked like* it had checked the logic. The shape was right. The work was missing.

The model didn't refuse to answer. It didn't say "I'm not sure." It pattern-matched the *genre* of a code review ("The function correctly handles...", "Edge cases are covered by...") rather than performing one. This is what code review hallucination actually looks like — not wrong facts, but an answer shaped like analysis with no analysis inside it. Those phrases show up in millions of real code reviews in its training data. The model doesn't need to read your function to produce them. It just needs to see that you asked for a review.

I spent a week after that incident trying to fix the problem. The answer turned out to be forty lines of markdown.

### The Research Behind It

Shubham Ugare and Satish Chandra at Meta published "Agentic Code Reasoning" (arXiv:2603.01896) in March 2026 with a result that clicked: when you force a language model to fill in a structured reasoning template *before* it can state a conclusion, accuracy on code analysis tasks jumps by five to twelve percentage points depending on the task. Patch equivalence verification went from 78% to 88%. Code question answering went from 78% to 87%. Fault localization improved by up to 12 points.

The template requires the model to produce intermediate artifacts — a table of every function it examined, a trace of how data flows through the code, a list of properties it claims are true with line-number evidence — before it can output an answer. You can verify each artifact independently. If a row in the function trace table is wrong, you can see it. If a data flow claim skips a mutation, the gap is visible.

The template makes laziness expensive. Not impossible — a model can still hallucinate a line number — but now that hallucination is checkable. A model that hasn't read a function can't fill in a row that requires the function's file path, line number, and verified behavior. The structure demands work product that can't be fabricated without doing the work.

### The Template

The paper uses task-specific templates for each benchmark. We adapted the idea into a single reusable command for everyday code review. Most AI coding tools support custom commands or reusable prompts. Here's what ours looks like:

```
You are a code reasoning agent answering questions about a codebase.
You can read files to gather evidence. You CANNOT execute code.

=== RULES ===
1. Before reading a file, state what you expect to find and why.
2. After reading a file, note observations with line numbers.
3. Before answering, you MUST fill in ALL sections below.
4. Every claim must cite a specific file:line.

=== REQUIRED CERTIFICATE (fill in before answering) ===

FUNCTION TRACE TABLE:
| Function | File:Line | Behavior (VERIFIED by reading source) |
|----------|-----------|--------------------------------------|
(List every function you examined.)

DATA FLOW ANALYSIS:
Variable: [name]
- Created at: [file:line]
- Modified at: [file:line(s), or NEVER MODIFIED]
- Used at: [file:line(s)]

SEMANTIC PROPERTIES:
Property N: [factual claim about the code]
- Evidence: [file:line]

ALTERNATIVE HYPOTHESIS CHECK:
If the OPPOSITE of your answer were true, what would you expect?
- Searched for: [what]
- Found: [what, at file:line]
- Conclusion: REFUTED or SUPPORTED
```

Four sections. Each one closes a specific escape route.

### How Each Section Works

The **function trace table** forces the model to list every function it examined, with the file path, line number, and a description of the behavior it verified by reading source. The model can't claim a function behaves a certain way without pointing to the exact lines where it confirmed that behavior. When you must point to the source, you either read it or leave the row blank. Blank rows are visible. Fabricated line numbers are checkable.

The **data flow analysis** picks a variable and tracks its life: where it was created, where it changed (or explicitly that it never changed), and where it was consumed. This is the section that would have caught my timezone bug. The third provider's timezone value was created in the webhook parser, never passed into the normalization function, and consumed only in the log formatter. The normalization function used a hardcoded default. Tracing the variable makes this gap visible on inspection.

It works because following a variable from creation to consumption is a simpler question than "is this function correct?" — and the simpler question actually gets answered.

**Semantic properties** require factual claims about the code, each backed by a file:line citation. "The function returns early on null input" isn't enough. "The function returns early on null input (auth.py:47)" is what the template demands. Each property is a reasoning step you can check on its own.

The **alternative hypothesis check** asks: if the opposite of your answer were true, what evidence would you expect to find? The model has to search for that evidence and report what it found. If it concludes that a function is safe, it must search for inputs that could make it unsafe. If it concludes that a variable is never modified, it must search for assignments and report the results. This is the section that catches the confident, unexamined answer. The exact failure mode that burned me.

### What Changes in Practice

Without the template, a review of a database migration reads like this:

> The migration looks correct. It adds the new column with the right type and default value. The rollback function properly drops the column. Edge cases around null values appear to be handled.

Which column? What type? What default? Which null edge cases? "Appear to be handled" is doing the work of an entire analysis that didn't happen.

With the template, the same review produces:

> **Function Trace Table:**
> | `add_status_column` | migrations/024_add_status.py:12 | Adds `status` column, type VARCHAR(20), default 'pending', nullable=False |
> | `rollback` | migrations/024_add_status.py:31 | Drops `status` column via `op.drop_column('orders', 'status')` |
>
> **Data Flow:**
> Variable: `status` column default
> - Created at: migrations/024_add_status.py:15 (server_default='pending')
> - Modified at: NEVER MODIFIED (default is set at column creation only)
> - Used at: models/order.py:8 (mapped as `status = Column(...)` with no Python-side default)
>
> **Semantic Property 1:** The migration sets a *server* default but the SQLAlchemy model does not set a Python default.
> - Evidence: migrations/024_add_status.py:15 vs models/order.py:8
>
> **Alternative Hypothesis:** If creating an Order in Python without specifying status *does* produce 'pending', we'd expect a `default=` argument in the Column definition.
> - Searched for: `default` in models/order.py
> - Found: no `default` parameter (models/order.py:8)
> - Conclusion: SUPPORTED — Python-created Orders will have status=None until the ORM flushes and the DB applies the server default.

The second review found a real bug that the first review declared handled. The template made it impossible to claim "edge cases appear to be handled" without specifying which edge cases and where the handling occurs.

### Why Structured Output Beats "Be Thorough"

The standard approach — telling a model "please be thorough" or "check edge cases carefully" — changes the style of the response, not the substance. The model produces tokens associated with thoroughness ("Upon careful examination") without examining anything. You get a more confident-sounding review, not a more accurate one.

A structured template changes what the model must *produce*. The function trace table isn't a suggestion. It's a table with columns that require specific values: function name, file path, line number, verified behavior. You can't fill in those columns with vibes. You need to read the files.

Meta's results bear this out. Five to twelve percentage points of accuracy improvement from a markdown template, without fine-tuning or code execution. The template works because it matches the model's output format to the verification process you were going to do anyway: reading the code. It just makes the model read it first.

---

The template is forty lines. Drop it into whatever AI coding tool you use. The next time you ask it to review code, it'll show you the trace table, the data flow, the semantic properties, and the counter-argument before it gives you an answer. If any section is thin, you'll know. If the model skipped the work, the gap will be visible.

At [Frontman](https://frontman.sh), we build an AI agent that makes visual changes directly on running applications. When the AI misreads your code, the change breaks your app in real time — there's no pull request buffer to catch it. Structured reasoning isn't academic for us. It's how we keep the agent honest.
