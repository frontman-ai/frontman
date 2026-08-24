const commonInstructions = `Before changing files:
- Confirm the project framework and package manager.
- Inspect existing configuration and git status.
- Preserve existing application behavior and merge configuration safely.
- Follow https://frontman.sh/docs/installation/.`

const verificationInstructions = `Start the project's normal development server, detect its actual local origin, and verify /frontman loads on that origin.

Do not enter credentials or complete OAuth. Report:
- commands run
- files changed
- verification result
- manual sign-in and provider steps still required`

export const agentInstructions = {
  nextjs: `Install Frontman for this Next.js project.

${commonInstructions}

Run:
npx @frontman-ai/nextjs install

Review the generated or updated middleware or proxy carefully. Frontman routes can remain present in a production deployment unless the integration is removed or protected with an environment guard.

${verificationInstructions}`,
  astro: `Install Frontman for this Astro project.

${commonInstructions}

Run:
npx astro add @frontman-ai/astro

${verificationInstructions}`,
  vite: `Install Frontman for this Vite project.

${commonInstructions}

Run:
npx @frontman-ai/vite install

${verificationInstructions}`,
  wordpress: `Help me install Frontman for WordPress manually.

Before making changes:
- Confirm this is a staging site, not production.
- Confirm a current backup exists.
- Confirm I have WordPress administrator access.
- Read https://frontman.sh/docs/installation/ and the linked WordPress guide.
- Explain each wp-admin step, but leave administrator actions to me.

Guide me through finding Frontman Agentic AI Editor in wp-admin, installing and activating it, then opening Frontman from the admin menu.

Do not ask for or enter credentials. I will complete WordPress administrator actions, GitHub or Google OAuth, and AI provider setup. Report the verification steps and any risks I should review before using Frontman on production.`,
}

const frameworkNames = {
  nextjs: "Next.js",
  astro: "Astro",
  vite: "Vite",
  wordpress: "WordPress",
}

const defaultLabel = "Copy for agent"

export const setupInstallAgent = (document, clipboard = globalThis.navigator.clipboard) => {
  const root = document.querySelector("[data-install-agent]")
  const button = root.querySelector("[data-copy-agent-instructions]")
  const label = button.querySelector("[data-copy-agent-label]")
  const copyIcon = button.querySelector("[data-copy-agent-icon]")
  const successIcon = button.querySelector("[data-copy-agent-success-icon]")
  const status = root.querySelector("[data-copy-agent-status]")
  const tabs = root.querySelectorAll("[data-framework]")
  let interactionVersion = 0

  button.setAttribute("aria-label", "Copy setup instructions for coding agent")

  const showCopyIcon = () => {
    copyIcon.removeAttribute("hidden")
    successIcon.setAttribute("hidden", "")
  }

  tabs.forEach(tab => {
    tab.addEventListener("click", () => {
      interactionVersion += 1
      root.dataset.agentFramework = tab.dataset.framework
      tabs.forEach(candidate => {
        candidate.setAttribute("aria-pressed", String(candidate === tab))
      })
      label.textContent = defaultLabel
      status.textContent = ""
      showCopyIcon()
    })
  })

  button.addEventListener("click", async () => {
    const framework = root.dataset.agentFramework
    const frameworkName = frameworkNames[framework]
    const requestVersion = ++interactionVersion

    try {
      await clipboard.writeText(agentInstructions[framework])
      if (requestVersion !== interactionVersion) return

      label.textContent = "Copied!"
      status.textContent = `${frameworkName} setup instructions copied to clipboard.`
      copyIcon.setAttribute("hidden", "")
      successIcon.removeAttribute("hidden")
    } catch {
      if (requestVersion !== interactionVersion) return

      label.textContent = "Copy failed"
      status.textContent = `Could not copy ${frameworkName} setup instructions. Try again.`
      showCopyIcon()
    }
  })
}
