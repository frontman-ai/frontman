type t = {major: int, minor: int, patch: int, prerelease: bool}

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
