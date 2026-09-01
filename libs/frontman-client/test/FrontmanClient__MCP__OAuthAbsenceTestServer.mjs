import {createServer} from 'node:http'

const discoveryError = id => JSON.stringify({
  jsonrpc: '2.0',
  id,
  error: {code: -32000, message: 'Application authentication required'},
})

export const start = () => new Promise((resolve, reject) => {
  const requests = []
  const server = createServer((request, response) => {
    requests.push({method: request.method, path: request.url})
    const address = server.address()
    const baseUrl = `http://127.0.0.1:${address.port}`
    if (request.url !== '/mcp') {
      response.writeHead(200, {'content-type': 'application/json'})
      response.end(JSON.stringify({
        resource: `${baseUrl}/mcp`,
        authorization_servers: [`${baseUrl}/hostile-authorization-server`],
        issuer: `${baseUrl}/hostile-authorization-server`,
        registration_endpoint: `${baseUrl}/hostile-registration`,
        token_endpoint: `${baseUrl}/hostile-token`,
      }))
      return
    }

    const chunks = []
    request.on('data', chunk => chunks.push(chunk))
    request.on('error', reject)
    request.on('end', () => {
      const body = JSON.parse(Buffer.concat(chunks).toString('utf8'))
      response.writeHead(401, {
        'content-type': 'application/json',
        'www-authenticate': `Bearer resource_metadata="${baseUrl}/hostile-resource-metadata"`,
      })
      response.end(discoveryError(body.id))
    })
  })
  server.once('error', reject)
  server.listen(0, '127.0.0.1', () => {
    const address = server.address()
    resolve({
      baseUrl: `http://127.0.0.1:${address.port}`,
      requestCount: () => requests.length,
      originalPostCount: () => requests.filter(request =>
        request.method === 'POST' && request.path === '/mcp').length,
      oauthDiscoveryCount: () => requests.filter(request =>
        request.path === '/hostile-resource-metadata' ||
        request.path.includes('/.well-known/')).length,
      oauthTokenCount: () => requests.filter(request =>
        request.path === '/hostile-token').length,
      oauthRegistrationCount: () => requests.filter(request =>
        request.path === '/hostile-registration').length,
      close: () => new Promise((resolveClose, rejectClose) => {
        server.close(error => error ? rejectClose(error) : resolveClose())
      }),
    })
  })
})
