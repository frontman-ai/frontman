set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
pin=ceb8a2b8f2d89434be7ff52d3de7ec3738c5cc9d
cache="$root/node_modules/.cache/paths-filter/$pin"
mkdir -p "$cache"
if [[ ! -d "$cache/repository.git" ]]; then
  git init --bare -q "$cache/repository.git"
fi
if ! git --git-dir="$cache/repository.git" cat-file -e "$pin:dist/index.js" 2>/dev/null; then
  git --git-dir="$cache/repository.git" fetch --depth=1 https://github.com/dorny/paths-filter.git "$pin"
fi
git --git-dir="$cache/repository.git" show "$pin:dist/index.js" > "$cache/index.js"
work=$(mktemp -d "$cache/test.XXXXXX")
trap 'rm -rf "$work"' EXIT
helper="$root/.github/self-hosted-checks.sh"
repo="$work/repo"
git init -q "$repo"
cd "$repo"
git config user.name 'CI scope test'
git config user.email ci-scope@example.invalid
mkdir -p apps/frontman_server/lib apps/swarm_ai/lib
printf 'server\n' > apps/frontman_server/lib/example.ex
printf 'swarm\n' > apps/swarm_ai/lib/example.ex
git add .
git commit -qm base
base=$(git rev-parse HEAD)
count=0

output() {
  awk -v name="$1" '
    index($0, name "<<") == 1 { getline; print; exit }
    index($0, name "=") == 1 { print substr($0, length(name) + 2); exit }
  ' "$2"
}

expect_failure() {
  if "$@" > "$work/negative.log" 2>&1; then
    printf 'Expected failure: %s\n' "$*" >&2
    exit 1
  fi
  count=$((count + 1))
}

select_from_action() {
  local expected_swarm="$1" expected_server="$2" head
  head=$(git rev-parse HEAD)
  : > "$work/base-output"
  BASE_SHA="$base" HEAD_SHA="$head" GITHUB_OUTPUT="$work/base-output" bash "$helper" base
  printf '{"pull_request":{"base":{"sha":"%s"}}}\n' "$base" > "$work/event.json"
  : > "$work/action-output"
  if ! env \
    "INPUT_TOKEN=" \
    "INPUT_BASE=$(output sha "$work/base-output")" \
    "INPUT_FILTERS=$root/.github/self-hosted-paths.yml" \
    "INPUT_PREDICATE-QUANTIFIER=every" \
    GITHUB_EVENT_NAME=pull_request \
    GITHUB_EVENT_PATH="$work/event.json" \
    GITHUB_OUTPUT="$work/action-output" \
    GITHUB_WORKSPACE="$repo" \
    GITHUB_REPOSITORY=frontman-ai/frontman \
    node "$cache/index.js" > "$work/action.log" 2>&1; then
    cat "$work/action.log"
    exit 1
  fi
  : > "$work/selection"
  EVENT_NAME=pull_request FULL_VERIFICATION=false FILTER_RESULT=success \
    SHARED="$(output shared "$work/action-output")" \
    SERVER="$(output server "$work/action-output")" \
    GITHUB_OUTPUT="$work/selection" bash "$helper" select
  if [[ "$(output swarm "$work/selection")" != "$expected_swarm" ||
        "$(output server "$work/selection")" != "$expected_server" ]]; then
    cat "$work/action.log" "$work/action-output" "$work/selection"
    exit 1
  fi
  count=$((count + 1))
}

reset_repo() {
  git reset --hard -q "$base"
  git clean -fdq
}

for path in \
  apps/marketing/blog/post.md apps/marketing/public/cover.png .changeset/marketing.md \
  docs/protocol.md README.md .changeset/release.md \
  apps/frontman_server/lib/example.ex apps/frontman_server/test/example_test.exs \
  apps/frontman_server/mix.exs apps/frontman_server/mix.lock \
  apps/swarm_ai/lib/example.ex apps/swarm_ai/test/example_test.exs \
  apps/swarm_ai/mix.exs apps/swarm_ai/mix.lock \
  Makefile mise.toml package.json yarn.lock .yarnrc.yml rescript.json \
  .github/workflows/ci.yml .github/self-hosted-paths.yml .github/self-hosted-checks.sh \
  scripts/ci/helper.sh libs/frontman-protocol/schemas/acp/schema.json \
  unknown/file unknown/nested.md test/ci-scope/scope.test.sh; do
  reset_repo
  mkdir -p "$(dirname "$path")"
  printf 'changed\n' > "$path"
  git add .
  git commit -qm change
  case "$path" in
    apps/marketing/*|docs/*|.changeset/*|README.md) select_from_action false false ;;
    apps/frontman_server/*) select_from_action false true ;;
    *) select_from_action true true ;;
  esac
done

reset_repo
mkdir -p apps/marketing/public .changeset
printf 'blog\n' > apps/marketing/post.md
printf 'cover\n' > apps/marketing/public/cover.png
printf 'release\n' > .changeset/marketing.md
git add .
git commit -qm marketing
select_from_action false false
reset_repo
select_from_action false false

for app in frontman_server swarm_ai; do
  reset_repo
  git rm -q "apps/$app/lib/example.ex"
  git commit -qm deletion
  if [[ "$app" == swarm_ai ]]; then select_from_action true true; else select_from_action false true; fi
  reset_repo
  mkdir -p docs
  git mv "apps/$app/lib/example.ex" docs/moved.md
  git commit -qm rename
  if [[ "$app" == swarm_ai ]]; then select_from_action true true; else select_from_action false true; fi
done

reset_repo
git checkout -qb pr
mkdir -p docs
printf 'docs\n' > docs/change.md
git add .
git commit -qm docs
pr=$(git rev-parse HEAD)
git checkout -qb advanced-base "$base"
printf 'base only\n' > shared-root-config
git add .
git commit -qm advance
base=$(git rev-parse HEAD)
git checkout -q "$pr"
select_from_action false false

for event in push workflow_call unknown pull_request; do
  full=false
  if [[ "$event" == pull_request ]]; then full=true; fi
  : > "$work/selection"
  EVENT_NAME="$event" FULL_VERIFICATION="$full" FILTER_RESULT=skipped SHARED= SERVER= \
    GITHUB_OUTPUT="$work/selection" bash "$helper" select
  [[ "$(output swarm "$work/selection")" == true && "$(output server "$work/selection")" == true ]]
  count=$((count + 1))
done

expect_failure env BASE_SHA=invalid HEAD_SHA="$pr" GITHUB_OUTPUT="$work/base-output" bash "$helper" base
expect_failure env BASE_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa HEAD_SHA="$pr" GITHUB_OUTPUT="$work/base-output" bash "$helper" base
for result in failure cancelled skipped success; do
  for invalid in '' invalid; do
    expect_failure env EVENT_NAME=pull_request FULL_VERIFICATION=false FILTER_RESULT="$result" \
      SHARED="$invalid" SERVER=false GITHUB_OUTPUT="$work/selection" bash "$helper" select
  done
  if [[ "$result" != success ]]; then
    expect_failure env EVENT_NAME=pull_request FULL_VERIFICATION=false FILTER_RESULT="$result" \
      SHARED=false SERVER=false GITHUB_OUTPUT="$work/selection" bash "$helper" select
  fi
done
expect_failure env "INPUT_TOKEN=" "INPUT_BASE=$base" "INPUT_FILTERS=$work/missing.yml" \
  GITHUB_EVENT_NAME=pull_request GITHUB_EVENT_PATH="$work/event.json" \
  GITHUB_OUTPUT="$work/action-output" node "$cache/index.js"

for detection in success failure cancelled skipped; do
  for swarm in true false '' invalid; do
    for server in true false '' invalid; do
      for job in swarm server lint; do
        for result in success failure cancelled skipped; do
          swarm_result=success server_result=success lint_result=success
          case "$job" in
            swarm) swarm_result="$result"; selected="$swarm" ;;
            server) server_result="$result"; selected="$server" ;;
            lint) lint_result="$result"; selected="$server" ;;
          esac
          expected=false
          if [[ "$detection" == success && "$swarm" =~ ^(true|false)$ && "$server" =~ ^(true|false)$ ]]; then
            if [[ "$result" == success || ( "$selected" == false && "$result" == skipped ) ]]; then expected=true; fi
          fi
          if env DETECTION_RESULT="$detection" SWARM="$swarm" SERVER="$server" \
            SWARM_RESULT="$swarm_result" SERVER_RESULT="$server_result" LINT_RESULT="$lint_result" \
            bash "$helper" aggregate > "$work/aggregate.log" 2>&1; then actual=true; else actual=false; fi
          [[ "$actual" == "$expected" ]] || { cat "$work/aggregate.log"; exit 1; }
          count=$((count + 1))
        done
      done
    done
  done
done
DETECTION_RESULT=success SWARM=false SERVER=false SWARM_RESULT=skipped SERVER_RESULT=skipped \
  LINT_RESULT=skipped bash "$helper" aggregate
printf 'Passed %s cases plus all-unselected/skipped aggregate using paths-filter %s\n' "$count" "$pin"
