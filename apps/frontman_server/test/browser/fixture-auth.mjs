import assert from "node:assert/strict"

// Local fixture authentication uses the existing CSRF-protected endpoint.
// It does not add a production bypass or claim to exercise Google/GitHub OAuth.
export async function signInFixture(page, base, email, password) {
  assert(["localhost", "127.0.0.1"].includes(base.hostname), "Use a local test server")
  const csrf = await page.locator("meta[name=csrf-token]").getAttribute("content")
  const response = await page.request.post(new URL("/users/log-in", base).href, {
    form: {"_csrf_token": csrf, "user[email]": email, "user[password]": password},
    maxRedirects: 0,
  })
  assert.equal(response.status(), 302)
  const destination = new URL(response.headers().location, base)
  assert.equal(destination.origin, base.origin)
  await page.goto(destination.href)
}
