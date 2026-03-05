// Minimal semver utilities for version comparison.
// Supports "X.Y.Z" and "X.Y.Z-prerelease" formats.
// Per semver spec, a pre-release version has lower precedence than
// the same version without a pre-release suffix (1.0.0-beta.1 < 1.0.0).

type t = {major: int, minor: int, patch: int, prerelease: bool}

// Parse a version string like "1.2.3" or "1.2.3-beta.1" into a semver value.
// Pre-release suffixes are stripped from the triple but tracked via the
// `prerelease` flag. Returns None for malformed input.
let parse = (version: string): option<t> => {
  let parts = version->String.split("-")
  let hasPrerelease = parts->Array.length > 1
  let base = parts->Array.get(0)->Option.getOr(version)

  switch base->String.split(".") {
  | [majorStr, minorStr, patchStr] =>
    switch (Int.fromString(majorStr), Int.fromString(minorStr), Int.fromString(patchStr)) {
    | (Some(major), Some(minor), Some(patch)) =>
      Some({major, minor, patch, prerelease: hasPrerelease})
    | _ => None
    }
  | _ => None
  }
}

// Returns true when `a` is strictly less than `b`.
// Compares major → minor → patch, then pre-release flag:
// when the triple is equal, a pre-release is behind a release (1.0.0-beta < 1.0.0).
let isBehind = (a: t, b: t): bool =>
  switch (a.major - b.major, a.minor - b.minor) {
  | (n, _) if n < 0 => true
  | (n, _) if n > 0 => false
  | (_, n) if n < 0 => true
  | (_, n) if n > 0 => false
  | _ =>
    switch compare(a.patch, b.patch) {
    | n if n < 0 => true
    | n if n > 0 => false
    | _ => a.prerelease && !b.prerelease
    }
  }
