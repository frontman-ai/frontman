"""Run after `make -C apps/marketing build`: python apps/marketing/scripts/check-search-content.py."""

import json
import re
from pathlib import Path

DIST = Path(__file__).resolve().parents[1] / "dist"


def page(route):
    content = (DIST / route / "index.html").read_text()
    assert len(re.findall(r"<h1\b", content)) == 1, route
    assert f'href="https://frontman.sh/{route}/"' in content, route
    return content


wordpress = page("blog/wordpress-7-1-new-features-breaking-changes")
for obsolete in ("not final yet", "is scheduled for", "Pending final release verification"):
    assert obsolete not in wordpress, obsolete
assert "WordPress 7.1.2 Security Update" in wordpress
schemas = [json.loads(block) for block in re.findall(
    r'<script\b[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', wordpress, re.S
)]
faq = next(schema for schema in schemas if schema.get("@type") == "FAQPage")
assert faq["mainEntity"][0]["name"] == "When was WordPress 7.1 released?"
assert "was released on August 19, 2026" in faq["mainEntity"][0]["acceptedAnswer"]["text"]

buyer = page("blog/best-frontend-coding-agent")
assert "Limited without external browser tooling" not in buyer
assert "How We Tested Frontend Coding Agents" not in buyer
assert "https://cursor.com/docs/agent/tools/browser" in buyer
assert "other pricing snapshots were not refreshed" in buyer

team = page("blog/best-ai-coding-agents-frontend-development-teams-2026")
assert "Run a Bounded Team Pilot" in team
assert "Visual verification still happens outside the IDE" not in team
assert "visual evidence is not native" not in team

home = (DIST / "index.html").read_text()
assert "The only AI coding tool with direct access" not in home
print("Search-content checks passed: release status, FAQ schema, Cursor capabilities, and page intent.")
