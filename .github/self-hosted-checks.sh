set -euo pipefail

case "${1:-}" in
  base)
    [[ "$BASE_SHA" =~ ^[0-9a-f]{40}$ && "$HEAD_SHA" =~ ^[0-9a-f]{40}$ ]]
    sha=$(git merge-base "$BASE_SHA" "$HEAD_SHA")
    printf 'sha=%s\n' "$sha" >> "$GITHUB_OUTPUT"
    ;;
  select)
    if [[ "$EVENT_NAME" != pull_request || "$FULL_VERIFICATION" == true ]]; then
      swarm=true
      server=true
    else
      [[ "$FILTER_RESULT" == success ]]
      [[ "$SHARED" == true || "$SHARED" == false ]]
      [[ "$SERVER" == true || "$SERVER" == false ]]
      swarm="$SHARED"
      server=false
      if [[ "$SHARED" == true || "$SERVER" == true ]]; then server=true; fi
    fi
    printf 'swarm=%s\nserver=%s\n' "$swarm" "$server" >> "$GITHUB_OUTPUT"
    ;;
  aggregate)
    [[ "$DETECTION_RESULT" == success ]]
    for entry in "$SWARM:$SWARM_RESULT" "$SERVER:$SERVER_RESULT" "$SERVER:$LINT_RESULT"; do
      case "$entry" in
        true:success|false:success|false:skipped) ;;
        *) printf 'Invalid or unsuccessful check: %s\n' "$entry" >&2; exit 1 ;;
      esac
    done
    ;;
  *)
    printf 'Expected base, select, or aggregate\n' >&2
    exit 1
    ;;
esac
