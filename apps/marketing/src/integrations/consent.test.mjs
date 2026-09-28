import {afterEach, describe, expect, test, vi} from "vitest"
import {createConsentScript} from "./consent.mjs"

const createStorage = initial => {
  const values = new Map(Object.entries(initial ?? {}))
  return {
    getItem: key => values.get(key) ?? null,
    removeItem: key => values.delete(key),
    setItem: (key, value) => values.set(key, value),
    value: key => values.get(key),
  }
}

const executeConsentScript = ({storedConsent, storage: storageOverride} = {}) => {
  const storage = storageOverride ?? createStorage(
    storedConsent ? {"frontman-cookie-consent": JSON.stringify(storedConsent)} : {},
  )
  const events = []
  const document = {
    dispatchEvent: event => events.push(event),
    getElementById: () => null,
    readyState: "complete",
  }
  const location = {reload: vi.fn()}
  const window = {
    astroConsent: undefined,
    requestIdleCallback: () => {},
    setTimeout: () => {},
  }
  class CustomEvent {
    constructor(type, options) {
      this.type = type
      this.detail = options?.detail
    }
  }

  new Function("window", "document", "localStorage", "location", "CustomEvent", createConsentScript())(
    window,
    document,
    storage,
    location,
    CustomEvent,
  )

  return {events, location, storage, window}
}

afterEach(() => vi.restoreAllMocks())

describe("local consent integration", () => {
  test("emits valid browser JavaScript", () => {
    expect(() => new Function(createConsentScript())).not.toThrow()
  })

  test("returns unexpired stored consent", () => {
    vi.spyOn(Date, "now").mockReturnValue(1_000)
    const {window} = executeConsentScript({
      storedConsent: {
        updatedAt: 500,
        expiresAt: 2_000,
        categories: {essential: true, analytics: true},
      },
    })

    expect(window.astroConsent.get().categories).toEqual({essential: true, analytics: true})
  })

  test("removes expired stored consent", () => {
    vi.spyOn(Date, "now").mockReturnValue(2_001)
    const {storage, window} = executeConsentScript({
      storedConsent: {
        updatedAt: 500,
        expiresAt: 2_000,
        categories: {essential: true, analytics: true},
      },
    })

    expect(window.astroConsent.get()).toBeNull()
    expect(storage.value("frontman-cookie-consent")).toBeUndefined()
  })

  test("stores only essential and analytics consent and dispatches an event", () => {
    vi.spyOn(Date, "now").mockReturnValue(1_000)
    const {events, storage, window} = executeConsentScript()

    window.astroConsent.set({essential: false, analytics: true, marketing: true})

    const stored = JSON.parse(storage.value("frontman-cookie-consent"))
    expect(stored.categories).toEqual({essential: true, analytics: true})
    expect(events).toEqual([
      expect.objectContaining({
        type: "consentchange",
        detail: {essential: true, analytics: true},
      }),
    ])
  })

  test("normalizes stored categories to essential and analytics", () => {
    vi.spyOn(Date, "now").mockReturnValue(1_000)
    const {storage, window} = executeConsentScript({
      storedConsent: {
        updatedAt: 500,
        expiresAt: 2_000,
        categories: {essential: false, analytics: true, marketing: true},
      },
    })

    expect(window.astroConsent.get().categories).toEqual({essential: true, analytics: true})
    expect(JSON.parse(storage.value("frontman-cookie-consent")).categories).toEqual({
      essential: true,
      analytics: true,
    })
  })

  test("reset clears consent and reloads the page", () => {
    const {location, storage, window} = executeConsentScript({
      storedConsent: {
        updatedAt: 500,
        expiresAt: 2_000,
        categories: {essential: true, analytics: false},
      },
    })

    window.astroConsent.reset()

    expect(storage.value("frontman-cookie-consent")).toBeUndefined()
    expect(location.reload).toHaveBeenCalledOnce()
  })

  test("keeps consent in memory when browser storage is unavailable", () => {
    const unavailableStorage = {
      getItem: () => { throw new DOMException("Blocked", "SecurityError") },
      removeItem: () => { throw new DOMException("Blocked", "SecurityError") },
      setItem: () => { throw new DOMException("Blocked", "SecurityError") },
    }
    const {window} = executeConsentScript({storage: unavailableStorage})

    expect(window.astroConsent.get()).toBeNull()
    window.astroConsent.set({analytics: true})
    expect(window.astroConsent.get().categories).toEqual({essential: true, analytics: true})
  })
})
