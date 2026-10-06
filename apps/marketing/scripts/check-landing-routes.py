"""Check the built WordPress-first landing routes with stdlib only."""
import json
from html.parser import HTMLParser
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
PLUGIN = "https://wordpress.org/plugins/frontman-agentic-ai-editor/"


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.links = []
        self.ids = set()
        self.canonical = None
        self.schema = []
        self.json_ld = None
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "a":
            self.links.append(attrs)
        if tag == "link" and attrs.get("rel") == "canonical":
            self.canonical = attrs["href"]
        if tag == "script" and attrs.get("type") == "application/ld+json":
            self.json_ld = ""

    def handle_data(self, data):
        if self.json_ld is not None:
            self.json_ld += data

    def handle_endtag(self, tag):
        if tag == "script" and self.json_ld is not None:
            self.schema.append(json.loads(self.json_ld))
            self.json_ld = None


home = Page(DIST / "index.html")
frameworks = Page(DIST / "frameworks/index.html")
assert home.canonical == "https://frontman.sh/"
home_copy = (DIST / "index.html").read_text().lower()
assert "production-ready" in home_copy and "battle-tested" in home_copy
assert "beta" not in home_copy and "experimental software" not in home_copy
assert frameworks.canonical == "https://frontman.sh/frameworks/"
assert any(link.get("href") == "/frameworks/" and "wp-secondary-link" in link.get("class", "") for link in home.links)
assert any(link.get("href") == PLUGIN and "header__cta" in link.get("class", "") for link in home.links)
assert any(link.get("href") == "/frameworks/#install" and "header__cta" in link.get("class", "") for link in frameworks.links)
assert "install" in frameworks.ids
assert any(node.get("runtimePlatform") == "WordPress" and node.get("url") == home.canonical
           for schema in home.schema for node in schema.get("@graph", []))
redirects = (DIST / "_redirects").read_text().splitlines()
assert "/wordpress / 301" in redirects and "/wordpress/ / 301" in redirects
urls = {node.text for path in DIST.glob("sitemap*.xml")
        for node in ET.parse(path).iter("{http://www.sitemaps.org/schemas/sitemap/0.9}loc")}
assert home.canonical in urls and frameworks.canonical in urls
assert "https://frontman.sh/wordpress/" not in urls
assert "https://frontman.sh/docs/integrations/wordpress/" in urls
assert "https://frontman.sh/frameworks/" in (DIST / "index.md").read_text()
for path in (ROOT / "src").rglob("*"):
    if path.suffix in {".astro", ".md", ".ts"}:
        assert "/#install" not in path.read_text().replace("/frameworks/#install", ""), path
print("Landing routes, redirects, installation links, canonicals, schema, and sitemap passed.")
