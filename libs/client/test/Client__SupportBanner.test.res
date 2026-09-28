open Vitest

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

test("support banner uses the shared rating target for every framework", t => {
  let frameworks: array<Client__RuntimeConfig.frameworkId> = [Nextjs, Vite, Astro, Wordpress]
  frameworks->Array.forEach(framework => {
    let html = renderToStaticMarkup(<Client__SupportBanner framework />)
    let (url, label) = switch framework {
    | Nextjs | Vite | Astro => ("https://github.com/frontman-ai/frontman", "Star us on GitHub")
    | Wordpress => ("https://wordpress.org/plugins/frontman-agentic-ai-editor/", "Leave a review")
    }
    t->expect(html->String.includes(`href="${url}"`))->Expect.toBe(true)
    t->expect(html->String.includes(label))->Expect.toBe(true)
    t->expect(html->String.includes("Enjoying Frontman?"))->Expect.toBe(true)
    t->expect(html->String.includes("target=\"_blank\""))->Expect.toBe(true)
    t->expect(html->String.includes("rel=\"noopener noreferrer\""))->Expect.toBe(true)
  })
})
