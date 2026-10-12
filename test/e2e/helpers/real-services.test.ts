import { spawn } from "node:child_process";
import { afterEach, expect, it, vi } from "vitest";
import * as S from "sury";
import { cleanupSignup, providerRequest, requiredEnv, stopProcess } from "./real-services.js";

afterEach(() => vi.unstubAllEnvs());

it("requires credentials instead of silently skipping", () => {
  vi.stubEnv("E2E_WORKOS_API_KEY", "");
  expect(() => requiredEnv("E2E_WORKOS_API_KEY")).toThrow("Missing E2E_WORKOS_API_KEY");
});

it("refuses live keys before any provider request", async () => {
  for (const provider of ["stripe", "workos"] as const) {
    vi.stubEnv(provider === "stripe" ? "E2E_STRIPE_SECRET_KEY" : "E2E_WORKOS_API_KEY", "sk_live_not_a_credential");
    await expect(providerRequest(provider, "users", S.unknown)).rejects.toThrow("Refusing non-test");
  }
});

it("refuses cleanup of identities not owned by this test", async () => {
  await expect(cleanupSignup("customer@example.com", [])).rejects.toThrow("Refusing unowned");
});

it("stops and waits for a real child process", async () => {
  const child = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], { detached: true });
  await stopProcess(child);
  expect(child.signalCode).toBe("SIGTERM");
  await stopProcess(child);
});
