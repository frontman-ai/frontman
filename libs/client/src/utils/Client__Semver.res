// Re-export from the canonical location in frontman-core.
// Kept for backward compatibility — new code should use FrontmanCore__Semver directly.

type t = FrontmanAiFrontmanCore.FrontmanCore__Semver.t = {
  major: int,
  minor: int,
  patch: int,
  prerelease: bool,
}

let parse = FrontmanAiFrontmanCore.FrontmanCore__Semver.parse
let isBehind = FrontmanAiFrontmanCore.FrontmanCore__Semver.isBehind
