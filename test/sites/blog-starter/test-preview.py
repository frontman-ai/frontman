import os
from html.parser import HTMLParser
from urllib.parse import urlsplit, urlunsplit
from urllib.request import urlopen


class Entrypoint(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_entrypoint = False
        self.value = ""

    def handle_starttag(self, tag, attrs):
        if tag == "span" and dict(attrs).get("id") == "frontman-entrypoint-url":
            self.in_entrypoint = True

    def handle_endtag(self, tag):
        if tag == "span":
            self.in_entrypoint = False

    def handle_data(self, data):
        if self.in_entrypoint:
            self.value += data


base = urlsplit(os.environ.get("NEXTJS_URL", "http://localhost:3000"))
origin = urlunsplit((base.scheme, base.netloc, "", "", ""))
for route, page in (
    ("/frontman", "/"),
    ("/frontman/", "/"),
    ("/posts/hello-world/frontman", "/posts/hello-world/"),
    ("/posts/hello-world/frontman/", "/posts/hello-world/"),
    ("/posts/dynamic-routing/frontman/?debug=1", "/posts/dynamic-routing/"),
    ("/frontman/?debug=1", "/"),
):
    with urlopen(origin + route, timeout=30) as response:
        assert response.status == 200
        parser = Entrypoint()
        parser.feed(response.read().decode())
    assert parser.value == origin + page, (route, parser.value, origin + page)
    print(route + " previews " + page + " on the public origin")
