export const trackInstallIntent = (
  root: Element,
  framework = root.getAttribute('data-agent-framework'),
) => {
  if (!framework || !['nextjs', 'astro', 'vite', 'wordpress'].includes(framework)) return
  const view = root.ownerDocument.defaultView
  if (!view || typeof view.trackEvent !== 'function') return
  view.trackEvent('install_intent', {
    event_category: 'engagement',
    event_label: framework === 'wordpress' ? 'manual_step_copy' : 'command_copy',
    placement: 'install_step',
    destination: framework === 'wordpress' ? 'wordpress_admin' : 'local_project',
    framework,
    site_type: framework === 'wordpress' ? 'wordpress' : 'framework',
    page_path: view.location.pathname,
  })
}
