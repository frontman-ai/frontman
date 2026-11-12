let updateInfoForVersions = (~target, ~installedVersion, ~latestVersion): option<
  Client__State__Types.updateInfo,
> =>
  switch (Client__Semver.parse(installedVersion), Client__Semver.parse(latestVersion)) {
  | (Some(installed), Some(latest)) if Client__Semver.isBehind(installed, latest) =>
    Some({target, installedVersion, latestVersion})
  | _ => None
  }
