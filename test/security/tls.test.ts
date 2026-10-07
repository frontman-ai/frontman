import { expect, test } from "vitest";
import { execFileSync, spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { createServer } from "node:https";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("Node accepts an explicitly trusted test CA and rejects an untrusted certificate", async () => {
  const dir = mkdtempSync(join(tmpdir(), "frontman-tls-"));
  const cert = join(dir, "cert.pem");
  const key = join(dir, "key.pem");
  execFileSync("openssl", ["req", "-x509", "-newkey", "rsa:2048", "-nodes",
    "-keyout", key, "-out", cert, "-days", "1", "-subj", "/CN=localhost",
    "-addext", "subjectAltName=DNS:localhost"], { stdio: "ignore" });
  const server = createServer({ key: readFileSync(key), cert: readFileSync(cert) },
    (_, response) => response.end("trusted"));
  try {
    await new Promise<void>((resolve, reject) => {
      server.once("error", reject);
      server.listen(0, "127.0.0.1", resolve);
    });
    const address = server.address();
    if (!address || typeof address === "string") throw new Error("Missing HTTPS port");
    const url = `https://localhost:${address.port}`;
    const check = (trust: boolean) => new Promise<{ code: number | null; output: string }>((resolve, reject) => {
      const env = { ...process.env };
      delete env.NODE_TLS_REJECT_UNAUTHORIZED;
      delete env.NODE_EXTRA_CA_CERTS;
      if (trust) env.NODE_EXTRA_CA_CERTS = cert;
      const child = spawn(process.execPath, ["-e",
        `fetch(${JSON.stringify(url)}).then(r => r.text()).then(console.log).catch(e => { console.error(e.cause.code); process.exitCode = 1; })`],
        { env, stdio: ["ignore", "pipe", "pipe"] });
      let output = "";
      child.stdout.on("data", data => { output += data; });
      child.stderr.on("data", data => { output += data; });
      child.once("error", reject);
      child.once("close", code => resolve({ code, output }));
    });
    expect(await check(true)).toEqual({ code: 0, output: "trusted\n" });
    const rejected = await check(false);
    expect(rejected.code).toBe(1);
    expect(rejected.output).toMatch(/SELF_SIGNED_CERT/);
    for (const file of ["test/e2e/global-setup.ts", ".github/workflows/e2e.yml"]) {
      expect(readFileSync(file, "utf8")).not.toContain("NODE_TLS_REJECT_UNAUTHORIZED");
    }
    expect(readFileSync("Makefile", "utf8")).toContain('export NODE_EXTRA_CA_CERTS=');
    expect(readFileSync(".github/workflows/e2e.yml", "utf8")).toContain("NODE_EXTRA_CA_CERTS=%s");
  } finally {
    await new Promise<void>(resolve => server.close(() => resolve()));
    rmSync(dir, { recursive: true, force: true });
  }
});
