import { execFileSync } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const fixtures = dirname(fileURLToPath(import.meta.url));
const root = resolve(fixtures, "../..");
const work = mkdtempSync(join(tmpdir(), "frontman-otel-compat-"));
const run = (command, args, cwd, env = {}) =>
  execFileSync(command, args, {
    cwd,
    env: { ...process.env, ...env },
    stdio: "inherit",
    timeout: 180_000,
  });

try {
  run("npm", ["pack", join(root, "libs/frontman-nextjs"), "--pack-destination", work], root);
  const pkg = JSON.parse(readFileSync(join(root, "libs/frontman-nextjs/package.json")));
  const tarball = join(work, `frontman-ai-nextjs-${pkg.version}.tgz`);
  const matrix = [
    { sdk: "0.52.0", api: "1.9.0", trace: "1.25.0", logs: "0.52.0" },
    { sdk: "0.223.0", api: "1.9.1", trace: "2.12.0", logs: "0.223.0" },
    { sdk: "0.300.0", api: "1.10.0", trace: "3.0.0", logs: "3.0.0" },
  ];

  for (const versions of matrix) {
    console.log(`Testing OpenTelemetry SDK ${versions.sdk} / API ${versions.api}`);
    const tracePackage = versions.trace === "3.0.0" ? "@opentelemetry/sdk-trace" : "@opentelemetry/sdk-trace-base";
    const consumer = join(work, versions.sdk);
    mkdirSync(consumer);
    writeFileSync(join(consumer, "package.json"), JSON.stringify({
      name: "frontman-otel-compat",
      private: true,
      type: "module",
      dependencies: {
        "@frontman-ai/nextjs": `file:${tarball}`,
        "@opentelemetry/api": versions.api,
        ...(versions.trace === "3.0.0" ? {} : { "@opentelemetry/api-logs": versions.logs }),
        "@opentelemetry/sdk-node": versions.sdk,
        [tracePackage]: versions.trace,
        "@opentelemetry/sdk-logs": versions.logs,
        next: "16.4.6",
        react: "19.3.1",
        "react-dom": "19.3.1",
        typescript: "5.9.3",
        "@types/node": "^24.0.0",
      },
    }));
    copyFileSync(join(fixtures, "consumer.mjs"), join(consumer, "consumer.mjs"));
    let typeTest = readFileSync(join(fixtures, "consumer.ts"), "utf8")
      .replaceAll("@opentelemetry/sdk-trace-base", tracePackage);
    if (versions.sdk === "0.52.0") {
      typeTest = typeTest.replace("logRecordProcessors: [logProcessor]", "logRecordProcessor: logProcessor");
    }
    writeFileSync(join(consumer, "consumer.ts"), typeTest);
    run("npm", ["install", "--strict-peer-deps", "--no-audit", "--no-fund", "--progress=false"], consumer);
    run(process.execPath, [
      "node_modules/typescript/bin/tsc", "--noEmit", "--strict",
      "--module", "nodenext", "--moduleResolution", "nodenext", "consumer.ts",
    ], consumer);
    for (const enabled of ["1", "0"]) {
      run(process.execPath, ["consumer.mjs"], consumer, {
        FRONTMAN_ENABLED: enabled,
        FRONTMAN_INTERNAL_DEV: "false",
        OTEL_METRICS_EXPORTER: "none",
        OTEL_TRACES_EXPORTER: "none",
        OTEL_LOGS_EXPORTER: "none",
        OTEL_SDK_VERSION: versions.sdk,
      });
    }
  }
} finally {
  rmSync(work, { recursive: true, force: true });
}
