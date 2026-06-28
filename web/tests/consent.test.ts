import { describe, it, expect, beforeEach } from 'vitest'
import { hasConsent, grantConsent } from '../src/lib/consent'

beforeEach(() => localStorage.clear())

describe('consent', () => {
  it('defaults to no consent', () => { expect(hasConsent()).toBe(false) })
  it('persists granted consent', () => { grantConsent(); expect(hasConsent()).toBe(true) })
})
