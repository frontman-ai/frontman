import type { APIRoute } from 'astro'

const siteUrl = new URL(import.meta.env.SITE)
const origin = siteUrl.origin

const apiCatalog = {
  linkset: [
    {
      anchor: `${origin}/`,
      about: [
        {
          href: `${origin}/how-it-works/`,
          type: 'text/html',
          title: 'How Frontman works',
        },
      ],
      'service-doc': [
        {
          href: `${origin}/docs/`,
          type: 'text/html',
          title: 'Frontman documentation',
        },
      ],
      contact: [
        {
          href: `${origin}/contact/`,
          type: 'text/html',
          title: 'Contact Frontman',
        },
      ],
      'version-history': [
        {
          href: `${origin}/changelog/`,
          type: 'text/html',
          title: 'Frontman changelog',
        },
      ],
    },
  ],
}

export const GET: APIRoute = () => {
  return new Response(JSON.stringify(apiCatalog, null, 2), {
    headers: {
      'Content-Type': 'application/linkset+json; charset=utf-8',
    },
  })
}
