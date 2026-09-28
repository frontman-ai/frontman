import fs from "node:fs";
import path from "node:path";

export function namespaceToPublicModule(namespace) {
  if (!namespace.startsWith("WebApi")) {
    throw new Error(`Unsupported namespace: ${namespace}`);
  }

  return namespace.slice("WebApi".length);
}

export function publicModuleToInternalPrefix(publicModule) {
  return publicModule.replace(/[A-Z]+(?=[A-Z][a-z]|$)|[A-Z][a-z]*/g, (part) => {
    return part[0] + part.slice(1).toLowerCase();
  });
}

export function publicNameForLeafModule(leafName, internalPrefix) {
  const preservedPrefixedModules = new Set(["PushEvent"]);
  const duplicatedSuffixes = ["Types", "Global", "Event", "File", "HTMLMediaElement"];

  if (preservedPrefixedModules.has(leafName)) {
    return leafName;
  }

  for (const suffix of duplicatedSuffixes) {
    if (leafName === `${internalPrefix}${suffix}`) {
      return suffix;
    }
  }

  return leafName;
}

const simplifiedLegacyLeaves = new Map([
  ["Canvas", new Map([["Global", "Canvas"]])],
  ["Fetch", new Map([["Global", "Fetch"]])],
  [
    "ServiceWorker",
    new Map([["ServiceWorkerGlobalScope", "ServiceWorkerScope"]]),
  ],
  [
    "WebWorkers",
    new Map([
      ["SharedWorkerGlobalScope", "SharedWorkerScope"],
      ["WorkerGlobalScope", "Worker"],
    ]),
  ],
]);

const legacyLeavesByCurrentLeaf = new Map(
  [...simplifiedLegacyLeaves.entries()].map(([publicModule, leafMap]) => [
    publicModule,
    new Map([...leafMap.entries()].map(([legacyLeaf, currentLeaf]) => [currentLeaf, legacyLeaf])),
  ]),
);

function simplifiedLeafName(spec, leafName) {
  return simplifiedLegacyLeaves.get(spec.publicModule)?.get(leafName);
}

export function legacyPublicNamesForLeafModule(leafName, spec) {
  const names = [publicNameForLeafModule(leafName, spec.internalPrefix)];
  const legacyLeaf = legacyLeavesByCurrentLeaf.get(spec.publicModule)?.get(leafName);

  if (legacyLeaf !== undefined && !names.includes(legacyLeaf)) {
    names.push(legacyLeaf);
  }

  return names;
}

export const featureSpecs = [
  ["Base", "WebApiBase"],
  ["CSSFontLoading", "WebApiCSSFontLoading"],
  ["Canvas", "WebApiCanvas"],
  ["ChannelMessaging", "WebApiChannelMessaging"],
  ["Clipboard", "WebApiClipboard"],
  ["CredentialManagement", "WebApiCredentialManagement"],
  ["DOM", "WebApiDOM"],
  ["EncryptedMediaExtensions", "WebApiEncryptedMediaExtensions"],
  ["Event", "WebApiEvent"],
  ["Fetch", "WebApiFetch"],
  ["File", "WebApiFile"],
  ["FileAndDirectoryEntries", "WebApiFileAndDirectoryEntries"],
  ["Gamepad", "WebApiGamepad"],
  ["Geolocation", "WebApiGeolocation"],
  ["History", "WebApiHistory"],
  ["IndexedDB", "WebApiIndexedDB"],
  ["IntersectionObserver", "WebApiIntersectionObserver"],
  ["MediaCapabilities", "WebApiMediaCapabilities"],
  ["MediaCaptureAndStreams", "WebApiMediaCaptureAndStreams"],
  ["MediaSession", "WebApiMediaSession"],
  ["MutationObserver", "WebApiMutationObserver"],
  ["Notification", "WebApiNotification"],
  ["Performance", "WebApiPerformance"],
  ["Permissions", "WebApiPermissions"],
  ["PictureInPicture", "WebApiPictureInPicture"],
  ["Push", "WebApiPush"],
  ["RemotePlayback", "WebApiRemotePlayback"],
  ["ResizeObserver", "WebApiResizeObserver"],
  ["ScreenWakeLock", "WebApiScreenWakeLock"],
  ["ServiceWorker", "WebApiServiceWorker"],
  ["Storage", "WebApiStorage"],
  ["UIEvents", "WebApiUIEvents"],
  ["URL", "WebApiURL"],
  ["ViewTransitions", "WebApiViewTransitions"],
  ["VisualViewport", "WebApiVisualViewport"],
  ["WebAudio", "WebApiWebAudio"],
  ["WebCrypto", "WebApiWebCrypto"],
  ["WebLocks", "WebApiWebLocks"],
  ["WebMIDI", "WebApiWebMIDI"],
  ["WebSockets", "WebApiWebSockets"],
  ["WebSpeech", "WebApiWebSpeech"],
  ["WebStorage", "WebApiWebStorage"],
  ["WebVTT", "WebApiWebVTT"],
  ["WebWorkers", "WebApiWebWorkers"],
].map(([dirName, legacyNamespace]) => {
  const publicModule = namespaceToPublicModule(legacyNamespace);

  return {
    dirName,
    legacyNamespace,
    publicModule,
    featureName: `WebAPI.${publicModule}`,
    internalPrefix: publicModuleToInternalPrefix(publicModule),
    sourceDir: `src/${dirName}`,
  };
});

export function migratedLeafName({ spec, leafName, duplicateLeaves }) {
  if (spec.dirName === "Base" && leafName === "DOM") {
    return "DOM";
  }

  const simplifiedName = simplifiedLeafName(spec, leafName);
  if (simplifiedName !== undefined) {
    return simplifiedName;
  }

  if (leafName === spec.publicModule) {
    return leafName;
  }

  if (duplicateLeaves.has(leafName)) {
    return `${spec.internalPrefix}${leafName}`;
  }

  return leafName;
}

export function findDuplicateLeafModules(rootDir, specs = featureSpecs) {
  const counts = new Map();

  for (const spec of specs) {
    const legacySourceDir = path.join(rootDir, "packages", spec.dirName, "src");
    if (!fs.existsSync(legacySourceDir)) continue;

    for (const entry of fs.readdirSync(legacySourceDir, { withFileTypes: true })) {
      if (!entry.isFile() || !entry.name.endsWith(".res")) continue;

      const leafName = path.basename(entry.name, ".res");
      counts.set(leafName, (counts.get(leafName) ?? 0) + 1);
    }
  }

  return new Set([...counts.entries()].filter(([, count]) => count > 1).map(([leafName]) => leafName));
}
