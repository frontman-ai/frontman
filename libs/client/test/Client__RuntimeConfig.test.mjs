import { describe, expect, test, afterEach } from 'vitest'
import * as RuntimeConfig from '../src/Client__RuntimeConfig.res.mjs'

afterEach(() => {
  delete window.__frontmanRuntime
})

describe('Client__RuntimeConfig', () => {
  test('read works without wpNonce for non-WordPress integrations', () => {
    window.__frontmanRuntime = {
      framework: 'nextjs',
      basePath: 'frontman',
    }

    let config = RuntimeConfig.read()

    expect(config.framework).toBe('Nextjs')
    expect(config.basePath).toBe('frontman')
    expect(config.wpNonce).toBeUndefined()
  })

  test('read preserves wpNonce for WordPress integrations', () => {
    window.__frontmanRuntime = {
      framework: 'wordpress',
      basePath: 'frontman',
      wpNonce: 'nonce-123',
    }

    let config = RuntimeConfig.read()

    expect(config.framework).toBe('Wordpress')
    expect(config.wpNonce).toBe('nonce-123')
  })

  test('toMeta does not leak wpNonce into ACP metadata', () => {
    let meta = RuntimeConfig.toMeta({
      framework: 'Wordpress',
      basePath: 'frontman',
      wpNonce: 'nonce-123',
      openrouterKeyValue: undefined,
      anthropicKeyValue: undefined,
      projectRoot: undefined,
      sourceRoot: undefined,
    })

    expect(meta).toEqual({
      framework: 'wordpress',
      basePath: 'frontman',
    })
    expect(meta.wpNonce).toBeUndefined()
  })
})
