import { spawn, type ChildProcess } from "node:child_process";
import * as S from "sury";

export function requiredEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`[e2e] Missing ${name}`);
  return value;
}

export async function providerRequest<T>(
  provider: "workos" | "stripe", path: string, schema: S.Schema<T>, method = "GET",
): Promise<T> {
  const key = requiredEnv(provider === "workos" ? "E2E_WORKOS_API_KEY" : "E2E_STRIPE_SECRET_KEY");
  if (!/^(sk|rk)_test_/.test(key)) throw new Error(`[e2e] Refusing non-test ${provider} key`);
  const response = await fetch(`https://api.${provider}.com/${provider === "stripe" ? "v1/" : ""}${path}`, {
    method, headers: { Authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) throw new Error(`[e2e] ${provider} ${method} failed: ${response.status}`);
  return S.parser(schema)(response.status === 204 ? undefined : await response.json());
}

export async function startStripeListener(): Promise<ChildProcess> {
  for (const name of ["E2E_WORKOS_API_KEY", "E2E_WORKOS_CLIENT_ID", "E2E_WORKOS_CONNECTION_ID",
    "E2E_STRIPE_SECRET_KEY", "E2E_STRIPE_MONTHLY_PRICE_ID", "E2E_STRIPE_YEARLY_PRICE_ID"]) requiredEnv(name);
  const priceSchema = S.schema({ livemode: false, active: true, recurring: { interval: S.string } });
  for (const interval of ["MONTHLY", "YEARLY"] as const) {
    const price = await providerRequest("stripe", `prices/${encodeURIComponent(requiredEnv(`E2E_STRIPE_${interval}_PRICE_ID`))}`, priceSchema);
    if (price.recurring.interval !== (interval === "MONTHLY" ? "month" : "year")) throw new Error("[e2e] Wrong Stripe price interval");
  }
  const proc = spawn("stripe", ["listen", "--forward-to", "https://localhost:4002/api/stripe/webhook", "--skip-verify",
    "--events", "checkout.session.completed,customer.subscription.created,customer.subscription.updated,customer.subscription.deleted"], {
    env: { ...process.env, STRIPE_API_KEY: requiredEnv("E2E_STRIPE_SECRET_KEY") }, stdio: "pipe", detached: true,
  });
  try {
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("[e2e] Stripe listener readiness timed out")), 30_000);
      const finish = (error?: Error) => { clearTimeout(timer); error ? reject(error) : resolve(); };
      let output = "";
      const capture = (chunk: Buffer) => {
        output = (output + chunk.toString()).slice(-4000);
        const secret = output.match(/(whsec_[A-Za-z0-9_]+)(?=[\s.)])/);
        if (secret) { process.env.E2E_STRIPE_WEBHOOK_SECRET = secret[1]; finish(); }
      };
      proc.stdout!.on("data", capture);
      proc.stderr!.on("data", capture);
      proc.once("error", () => finish(new Error("[e2e] Cannot start Stripe CLI")));
      proc.once("exit", () => finish(new Error("[e2e] Stripe listener exited")));
    });
    return proc;
  } catch (error) {
    await stopProcess(proc);
    throw error;
  }
}

export async function stopProcess(proc: ChildProcess | undefined): Promise<void> {
  if (!proc?.pid || proc.exitCode !== null || proc.signalCode !== null) return;
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => {
      process.kill(-proc.pid!, "SIGKILL");
      reject(new Error("[e2e] Child process did not stop cleanly"));
    }, 5000);
    proc.once("exit", () => { clearTimeout(timer); resolve(); });
    process.kill(-proc.pid!, "SIGTERM");
  });
}

export async function cleanupSignup(email: string, sessions: string[]): Promise<void> {
  if (!/^frontman-e2e-[a-f0-9-]+@example\.com$/.test(email)) throw new Error("[e2e] Refusing unowned identity cleanup");
  const results = await Promise.allSettled([
    (async () => {
      const users = await providerRequest("workos", `user_management/users?email=${encodeURIComponent(email)}&limit=100`,
        S.schema({ data: S.array(S.schema({ id: S.string, email: S.string })) }));
      for (const user of users.data) {
        if (user.email !== email) throw new Error("[e2e] WorkOS cleanup ownership mismatch");
        await providerRequest("workos", `user_management/users/${encodeURIComponent(user.id)}`, S.unknown, "DELETE");
      }
    })(),
    ...sessions.map(async id => {
      if (!/^cs_test_[A-Za-z0-9]+$/.test(id)) throw new Error("[e2e] Refusing non-test session cleanup");
      const session = await providerRequest("stripe", `checkout/sessions/${id}`, S.schema({
        livemode: false, status: S.string, customer: S.union([S.string, S.literal(null)]),
      }));
      if (session.status === "open") await providerRequest("stripe", `checkout/sessions/${id}/expire`, S.unknown, "POST");
      if (session.customer) {
        const customer = await providerRequest("stripe", `customers/${session.customer}`, S.schema({ livemode: false, email: S.string }));
        if (customer.email !== email) throw new Error("[e2e] Stripe cleanup ownership mismatch");
        await providerRequest("stripe", `customers/${session.customer}`, S.schema({ deleted: true }), "DELETE");
      }
    }),
  ]);
  const errors = results.filter(result => result.status === "rejected").map(result => result.reason);
  if (errors.length) throw new AggregateError(errors, "[e2e] Signup cleanup failed");
}
