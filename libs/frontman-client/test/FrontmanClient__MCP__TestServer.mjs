import {createServer} from 'node:http'

const readBody = request => new Promise((resolve, reject) => {
  const chunks = []
  request.on('data', chunk => chunks.push(chunk))
  request.on('end', () => resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))))
  request.on('error', reject)
})

const inputSchema = {type: 'object', additionalProperties: false}
const version = '2026-07-28'

const tool = name => ({name, inputSchema})

const paddedTool = (name, bytes) => {
  const definition = {name, description: '', inputSchema}
  const baseBytes = Buffer.byteLength(JSON.stringify(definition))
  if (baseBytes > bytes) {
    throw new Error(`Tool ${name} cannot fit in ${bytes} bytes`)
  }
  definition.description = 'x'.repeat(bytes - baseBytes)
  const actualBytes = Buffer.byteLength(JSON.stringify(definition))
  if (actualBytes !== bytes) {
    throw new Error(`Tool ${name} is ${actualBytes} bytes, expected ${bytes}`)
  }
  return definition
}

const discoverResult = instructions => ({
  resultType: 'complete',
  supportedVersions: [version],
  capabilities: {tools: {listChanged: false}},
  _meta: {'io.modelcontextprotocol/serverInfo': {name: 'test-framework', version: '2.0.0'}},
  ...(instructions === undefined ? {} : {instructions}),
  ttlMs: 60000,
  cacheScope: 'private',
})

const withoutResultType = result => {
  const {resultType: _resultType, ...legacyResult} = result
  return legacyResult
}

const envelope = (id, result) => JSON.stringify({jsonrpc: '2.0', id, result})

const exactDiscoveryEnvelope = (id, targetBytes) => {
  const empty = envelope(id, discoverResult(''))
  const emptyBytes = Buffer.byteLength(empty)
  if (emptyBytes > targetBytes) {
    throw new Error(`Discovery envelope cannot fit in ${targetBytes} bytes`)
  }
  const value = envelope(id, discoverResult('x'.repeat(targetBytes - emptyBytes)))
  const actualBytes = Buffer.byteLength(value)
  if (actualBytes !== targetBytes) {
    throw new Error(`Discovery envelope is ${actualBytes} bytes, expected ${targetBytes}`)
  }
  return value
}

const listResult = (tools, nextCursor) => ({
  resultType: 'complete',
  tools,
  ...(nextCursor === undefined ? {} : {nextCursor}),
  ttlMs: 60000,
  cacheScope: 'private',
})

const defaultTools = body => {
  if (!Object.hasOwn(body.params, 'cursor')) {
    return listResult([{
      name: 'write_unicode',
      description: 'Writes a value',
      inputSchema: {
        type: 'object',
        properties: {value: {type: 'string', 'x-mcp-header': 'Value'}},
        required: ['value'],
      },
    }], '')
  }
  return listResult([
    {name: 'invalid_remote', inputSchema: {$schema: 'https://example.com/unsupported', type: 'object'}},
    {name: 'json_tool', inputSchema, outputSchema: {type: 'string'}},
    tool('retry_header'),
    {
      name: 'attachment_tool',
      inputSchema: {type: 'object', additionalProperties: true},
      annotations: {readOnlyHint: true},
      _meta: {
        'ai.frontman/attachment-resolution': {
          version: 1,
          referenceArgument: 'asset',
          contentArgument: 'bytes',
          encodingArgument: 'format',
          encodingValue: 'base64',
          removeReference: true,
          mediaTypeArgument: 'mediaType',
        },
      },
    },
    {
      name: 'slow_input',
      inputSchema: {
        type: 'object',
        properties: {value: {type: 'string', pattern: '^(a+)+$'}},
        required: ['value'],
      },
    },
    {name: 'slow_output', inputSchema, outputSchema: {type: 'string', pattern: '^(a+)+$'}},
  ])
}

const indexedTools = count => Array.from({length: count}, (_, index) => tool(`tool_${index}`))

const catalogTools = targetBytes => {
  const count = 17
  const bytesPerTool = Math.floor(targetBytes / count)
  const extraBytes = targetBytes % count
  const tools = Array.from({length: count}, (_, index) =>
    paddedTool(`catalog_${index}`, bytesPerTool + (index < extraBytes ? 1 : 0)))
  const actualBytes = tools.reduce((total, definition) => total + Buffer.byteLength(JSON.stringify(definition)), 0)
  if (actualBytes !== targetBytes) {
    throw new Error(`Catalog is ${actualBytes} bytes, expected ${targetBytes}`)
  }
  return tools
}

const scenarioList = (scenario, body, authorization, requestCount) => {
  const cursor = body.params.cursor
  switch (scenario) {
    case 'absolute-deadline':
      return listResult([])
    case 'pages-32': {
      const page = cursor === undefined ? 0 : Number(cursor)
      return listResult([tool(`page_${page}`)], page === 31 ? undefined : String(page + 1))
    }
    case 'pages-33': {
      const page = cursor === undefined ? 0 : Number(cursor)
      return listResult([tool(`page_${page}`)], String(page + 1))
    }
    case 'tools-256':
      return listResult(indexedTools(256))
    case 'tools-257':
      return listResult(indexedTools(257))
    case 'cursor-4096':
      return cursor === undefined
        ? listResult([tool('cursor_first')], `${'é'.repeat(2047)}ab`)
        : listResult([tool('cursor_second')])
    case 'cursor-4097':
      return listResult([tool('cursor_first')], `${'é'.repeat(2048)}a`)
    case 'repeated-opaque-cursor':
      return requestCount < 3
        ? listResult([tool(`repeated_${requestCount}`)], 'opaque-repeat')
        : listResult([tool('repeated_3')])
    case 'invalid-cursor-restart':
      if (requestCount === 1) return listResult([tool('discarded_tool')], 'expired-cursor')
      if (requestCount === 2) return {error: {code: -32602, message: 'Invalid cursor'}}
      return requestCount === 3
        ? listResult([tool('fresh_first')], 'fresh-cursor')
        : listResult([tool('fresh_second')])
    case 'invalid-cursor-restart-bounded':
      return cursor === undefined
        ? listResult([tool(`attempt_${requestCount}`)], `invalid-${requestCount}`)
        : {error: {code: -32602, message: 'Invalid cursor'}}
    case 'absent-list-result-type':
      return withoutResultType(listResult([tool('legacy_tool')]))
    case 'input-required-list':
      return {resultType: 'input_required', requestState: 'opaque-list-state'}
    case 'absent-call-result-type':
    case 'input-required-call':
    case 'malformed-input-required-call':
      return listResult([tool('result_type_tool')])
    case 'cache-delayed-page':
      return cursor === undefined
        ? listResult([tool('cache_first')], 'cache-page-2')
        : listResult([tool('cache_second')])
    case 'tool-bytes-65536':
      return listResult([paddedTool('boundary_tool', 65536), tool('valid_sibling')])
    case 'tool-bytes-65537':
      return listResult([paddedTool('boundary_tool', 65537), tool('valid_sibling')])
    case 'catalog-bytes-1048576': {
      const tools = catalogTools(1048576)
      return cursor === undefined ? listResult(tools.slice(0, 8), 'catalog-page-2') : listResult(tools.slice(8))
    }
    case 'catalog-bytes-1048577': {
      const tools = catalogTools(1048577)
      return cursor === undefined ? listResult(tools.slice(0, 8), 'catalog-page-2') : listResult(tools.slice(8))
    }
    case 'authorization-isolation':
      return listResult([tool(authorization === 'Bearer alpha' ? 'alpha_tool' : 'beta_tool')])
    default:
      return defaultTools(body)
  }
}

const sendSplit = (response, bytes) => {
  const splitAt = Math.floor(bytes.length / 2)
  response.write(bytes.subarray(0, splitAt))
  response.end(bytes.subarray(splitAt))
}

export const startScenario = scenario => new Promise((resolve, reject) => {
  const requests = []
  let controlledResponse
  const controlledResponses = []
  const controlledWaiters = []
  let resolveControlledReceived
  let resolveControlledClientClosed
  const controlledReceived = new Promise(resolve => { resolveControlledReceived = resolve })
  const controlledClientClosed = new Promise(resolve => { resolveControlledClientClosed = resolve })
  let discoveryCount = 0
  let listCount = 0
  let callCount = 0
  let headerMismatchCount = 0
  let authorizationAlphaCount = 0
  let authorizationBetaCount = 0
  let authorizationMutatedCount = 0
  const server = createServer(async (request, response) => {
    try {
      const body = await readBody(request)
      requests.push({headers: request.headers, body})
      const authorization = request.headers.authorization
      if (authorization === 'Bearer alpha') authorizationAlphaCount += 1
      if (authorization === 'Bearer beta') authorizationBetaCount += 1
      if (authorization === 'Bearer mutated') authorizationMutatedCount += 1

      if (body.method === 'server/discover') {
        discoveryCount += 1
        if (scenario === 'same-version-retry' && discoveryCount === 1) {
          response.writeHead(400, {'content-type': 'application/json'})
          response.end(JSON.stringify({
            jsonrpc: '2.0',
            id: body.id,
            error: {
              code: -32022,
              message: 'Unsupported protocol version',
              data: {requested: version, supported: [version]},
            },
          }))
          return
        }
        if (
          scenario === 'absolute-deadline' ||
          scenario === 'response-error' ||
          scenario === 'connect-lifecycle' ||
          (scenario === 'cache-delayed-discovery' && discoveryCount === 1)
        ) {
          controlledResponse = response
          controlledResponses.push({response, body})
          for (const waiter of controlledWaiters.splice(0)) {
            if (controlledResponses.length >= waiter.count) waiter.resolve()
            else controlledWaiters.push(waiter)
          }
          response.once('close', () => {
            if (!response.writableEnded) resolveControlledClientClosed()
          })
          resolveControlledReceived()
          if (scenario === 'response-error') {
            response.writeHead(200, {'content-type': 'text/plain'})
            response.flushHeaders()
          }
          return
        }
        const responseBytes = scenario.match(/^(json|sse)-response-(12582912|12582913)$/)
        if (responseBytes) {
          const mediaType = responseBytes[1]
          const targetBytes = Number(responseBytes[2])
          const framingBytes = mediaType === 'sse' ? Buffer.byteLength('data: \r\n\r\n') : 0
          const payload = exactDiscoveryEnvelope(body.id, targetBytes - framingBytes)
          const bytes = mediaType === 'sse'
            ? Buffer.from(`data: ${payload}\r\n\r\n`)
            : Buffer.from(payload)
          if (bytes.length !== targetBytes) {
            throw new Error(`Response is ${bytes.length} bytes, expected ${targetBytes}`)
          }
          response.writeHead(200, {'content-type': mediaType === 'sse' ? 'text/event-stream' : 'application/json'})
          sendSplit(response, bytes)
          return
        }
        response.writeHead(200, {'content-type': 'application/json'})
        const result = scenario === 'absent-discovery-result-type'
          ? withoutResultType(discoverResult())
          : scenario === 'input-required-discovery'
            ? {resultType: 'input_required', requestState: 'opaque-discovery-state'}
            : discoverResult()
        response.end(envelope(body.id, result))
        return
      }

      if (body.method === 'tools/list') {
        listCount += 1
        if (scenario === 'cache-delayed-page' && body.params.cursor !== undefined) {
          controlledResponse = response
          controlledResponses.push({response, body})
          for (const waiter of controlledWaiters.splice(0)) {
            if (controlledResponses.length >= waiter.count) waiter.resolve()
            else controlledWaiters.push(waiter)
          }
          resolveControlledReceived()
          return
        }
        const result = scenario === 'connect-lifecycle'
          ? listResult([tool(listCount === 1 ? 'new_tool' : 'old_tool')])
          : scenarioList(scenario, body, authorization, listCount)
        response.writeHead(200, {'content-type': 'application/json'})
        response.end(result.error
          ? JSON.stringify({jsonrpc: '2.0', id: body.id, error: result.error})
          : envelope(body.id, result))
        return
      }

      if (body.method === 'tools/call') {
        callCount += 1
        let result
        if (body.params.name === 'retry_header' && headerMismatchCount++ === 0) {
          result = {error: {code: -32020, message: 'Header mismatch'}}
        } else if (body.params.name === 'json_tool') {
          result = {resultType: 'complete', content: [{type: 'text', text: 'json_tool'}], structuredContent: 'json_tool'}
        } else if (body.params.name === 'slow_output') {
          result = {resultType: 'complete', content: [{type: 'text', text: 'slow'}], structuredContent: `${'a'.repeat(64)}!`}
        } else if (scenario === 'absent-call-result-type') {
          result = {content: [{type: 'text', text: 'legacy call'}]}
        } else if (scenario === 'input-required-call') {
          result = {resultType: 'input_required', requestState: 'opaque:do-not-inspect'}
        } else if (scenario === 'malformed-input-required-call') {
          result = {resultType: 'input_required', inputRequests: {bad: {method: 'unknown'}}}
        } else {
          result = {resultType: 'complete', content: [{type: 'text', text: body.params.name}]}
        }
        const value = JSON.stringify(result.error
          ? {jsonrpc: '2.0', id: body.id, error: result.error}
          : {jsonrpc: '2.0', id: body.id, result})
        const status = result.error ? 400 : 200
        if (body.params.name === 'write_unicode') {
          response.writeHead(status, {'content-type': 'text/event-stream'})
          response.end(`: keepalive\r\ndata: ${value}\r\n\r\n`)
        } else {
          response.writeHead(status, {'content-type': 'application/json'})
          response.end(value)
        }
        return
      }

      throw new Error(`Unexpected method ${body.method}`)
    } catch (error) {
      if (!response.headersSent) response.writeHead(500, {'content-type': 'text/plain'})
      if (!response.writableEnded) response.end(String(error))
    }
  })
  server.once('error', reject)
  server.listen(0, '127.0.0.1', () => {
    const address = server.address()
    resolve({
      baseUrl: `http://127.0.0.1:${address.port}`,
      requests,
      counts: () => ({
        discoveryCount,
        listCount,
        callCount,
        headerMismatchCount,
        authorizationAlphaCount,
        authorizationBetaCount,
        authorizationMutatedCount,
      }),
      controlledReceived,
      controlledClientClosed,
      respondControlled: () => {
        if (controlledResponse === undefined) throw new Error('No controlled response is pending')
        controlledResponse.writeHead(200, {'content-type': 'application/json'})
        controlledResponse.end(envelope(requests[0].body.id, discoverResult()))
      },
      waitForControlled: count => controlledResponses.length >= count
        ? Promise.resolve()
        : new Promise(resolveWait => controlledWaiters.push({count, resolve: resolveWait})),
      respondControlledAt: index => {
        const controlled = controlledResponses[index]
        if (controlled === undefined) throw new Error(`No controlled response at index ${index}`)
        controlled.response.writeHead(200, {'content-type': 'application/json'})
        const result = controlled.body.method === 'server/discover'
          ? discoverResult()
          : scenarioList(scenario, controlled.body, undefined, listCount)
        controlled.response.end(envelope(controlled.body.id, result))
      },
      close: () => new Promise((resolveClose, rejectClose) => {
        if (!server.listening) {
          resolveClose()
          return
        }
        server.close(error => error ? rejectClose(error) : resolveClose())
      }),
    })
  })
})

export const start = () => startScenario('default')
