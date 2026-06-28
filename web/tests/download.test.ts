import { describe, it, expect } from 'vitest'
import { vcardFilename } from '../src/lib/download'

describe('vcardFilename', () => {
  it('slugifies the display name', () => { expect(vcardFilename('Jane Doe')).toBe('jane-doe.vcf') })
  it('falls back to contact for empty', () => { expect(vcardFilename('   ')).toBe('contact.vcf') })
})
