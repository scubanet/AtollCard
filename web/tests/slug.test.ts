import { describe, it, expect } from 'vitest'
import { slugFromPath } from '../src/lib/slug'

describe('slugFromPath', () => {
  it('extracts a simple slug', () => { expect(slugFromPath('/jane-doe')).toBe('jane-doe') })
  it('ignores trailing slash', () => { expect(slugFromPath('/jane-doe/')).toBe('jane-doe') })
  it('returns null for root', () => { expect(slugFromPath('/')).toBeNull() })
  it('rejects nested paths', () => { expect(slugFromPath('/a/b')).toBeNull() })
})
