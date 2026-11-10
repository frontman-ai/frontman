#!/usr/bin/env bash
set -euo pipefail

production_origin="${PRODUCTION_ORIGIN:-https://api.frontman.sh}"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
curl_args=(
  --connect-timeout "${PRODUCTION_SMOKE_CONNECT_TIMEOUT_SECONDS:-5}"
  --max-time "${PRODUCTION_SMOKE_MAX_TIME_SECONDS:-20}"
  -fsS -b "$scratch/cookies" -c "$scratch/cookies"
)

for path in /health /health/ready; do
  curl "${curl_args[@]}" "${production_origin}${path}" >/dev/null
done
curl "${curl_args[@]}" "${production_origin}/users/log-in" -o "$scratch/login.html"
csrf_token="$(python3 - "$scratch/login.html" <<'PY'
import sys
from html.parser import HTMLParser
from pathlib import Path

class LoginForm(HTMLParser):
    tokens = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "input" and attrs.get("name") == "_csrf_token":
            self.tokens.append(attrs.get("value"))

form = LoginForm()
form.feed(Path(sys.argv[1]).read_text())
if not form.tokens or not form.tokens[0]:
    sys.exit("Login page has no CSRF token")
print(form.tokens[0])
PY
)"

check_redirect() {
  local provider="$1" expected_provider="$2" response status location
  response="$(curl "${curl_args[@]}" -o /dev/null -w '%{http_code} %{redirect_url}' \
    --data-urlencode "_csrf_token=$csrf_token" "${production_origin}/auth/${provider}")"
  status="${response%% *}"
  location="${response#* }"
  if [[ "$status" != "302" || "$location" != https://api.workos.com/user_management/authorize\?* ]]; then
    echo "Expected /auth/${provider} to redirect to WorkOS, got: ${response}" >&2
    exit 1
  fi
  if [[ ! "$location" =~ [\?\&]provider=${expected_provider}(\&|$) ]]; then
    echo "Expected /auth/${provider} to include provider=${expected_provider}, got: ${location}" >&2
    exit 1
  fi
}

check_redirect google GoogleOAuth
check_redirect github GitHubOAuth
