# Security alert triage

Reviewed against commit `7e702cfe`.

## Status

- CodeQL #7, #8, and #9: dismissed as false positives on GitHub.
- CodeQL #12: parsed HTTPS/exact-hostname assertions implemented and reviewed; requires a new scan after landing.
- Dependabot #706: unused gray-matter dependency and legacy YAML/formatter chain removed; requires a new dependency scan after landing.
- Dependabot #699 and #700: remain open. GitHub lists no patched version at this review.

## Implementation verification

Reviewed the complete executor diff and pulled the changes into this thread.
Independent reruns in the executor's isolated checkout passed:

- `make -C apps/marketing test`: 114 tests across 15 files.
- `NODE_ENV=production make -C test/sites/blog-starter build`: TypeScript and six generated pages.
- `git diff --check`: clean.

The executor reported that the plain fixture build failed with an inherited
nonstandard NODE_ENV. The production build retains a metadataBase warning.
No commits, pushes, or remote scans were performed.

## Dependabot #700: http-cache-semantics

https://github.com/frontman-ai/frontman/security/dependabot/700

Version 4.2.0 reproduces unsafe cache reuse with a client max-stale directive.
Synthetic responses containing a fake session cookie return a policy hit.
This confirms the package defect, not a deployed cache leak.

The reviewed Astro 7.3.2 consumer uses the package for build-time remote-image
TTL calculation. It calls storable() and timeToLive(), not the vulnerable
request-reuse methods. The marketing workflow deploys the generated dist
directory to Cloudflare Pages.

The other lockfile consumer is make-fetch-happen through fsevents and node-gyp.
It uses the affected reuse method, but no application endpoint forwarding visitor
requests into this cache was found. It checks response storability before writing.

Keep open pending an upstream patch or removal. Reassess if server-side shared
caching is introduced, client cache headers are forwarded, or consumers change.
Do not treat this finding as evidence of a Cloudflare cache vulnerability.

## Dependabot #699: braces

https://github.com/frontman-ai/frontman/security/dependabot/699

Version 3.0.3 reproduces stack exhaustion below its 10,000-character limit.
Compilation failed at 3,500 nested braces; expansion failed at 4,998.
Exceptions were caught in bounded subprocess reproductions on Node 26.12.0.

Frontman's filename-search tool uses its own string matcher, not braces.
The marketing broken-link checker uses the constant fast-glob pattern
`**/*.html`. Other lockfile consumers include shadcn and ts-morph tooling.
No public request path accepting attacker-controlled brace patterns was found.

Keep open pending an upstream patch or removal. Reassess if untrusted patterns
are passed to fast-glob, micromatch, or braces. Do not add unrelated guards to
Frontman's independent filename matcher.

## Dismissed stored-XSS findings

The reported sinks are React link attributes with a fixed `/posts/` prefix.
Filename-derived slugs override frontmatter slugs. React 19.2.5 server rendering
encoded quote/tag payloads and kept scheme payloads within the path.
This assessment is limited to the reported links, not raw post HTML.
No actual Next.js browser reproduction was run.

## Follow-up verification

After the implementation changes land, confirm that CodeQL #12 and Dependabot
#706 close. Recheck upstream patched versions for #699 and #700 before choosing
an upgrade. Do not use speculative resolutions or dismiss these real package
defects as false positives.
