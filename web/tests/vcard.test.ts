import { describe, it, expect } from 'vitest'
import { toVCard } from '../src/lib/vcard'
import type { PublicCard } from '../src/lib/types'

const card: PublicCard = {
  display_name: 'Jane Doe', title: 'CTO', company: 'Acme', theme: 'default',
  accent_color: '#0E7C86', cover_url: null, logo_url: null, photo_url: null,
  fields: [
    { type: 'email', label: 'Work', value: 'jane@acme.com' },
    { type: 'phone', label: 'Mobile', value: '+41791112233' },
    { type: 'url', label: 'Site', value: 'https://acme.com' },
  ],
}

describe('toVCard', () => {
  it('includes name, org, title', () => {
    const v = toVCard(card)
    expect(v).toContain('FN:Jane Doe'); expect(v).toContain('ORG:Acme'); expect(v).toContain('TITLE:CTO')
  })
  it('maps email, phone, url fields', () => {
    const v = toVCard(card)
    expect(v).toContain('EMAIL;TYPE=Work:jane@acme.com')
    expect(v).toContain('TEL;TYPE=Mobile:+41791112233')
    expect(v).toContain('URL:https://acme.com')
  })
  it('begins and ends with vCard markers', () => {
    const v = toVCard(card)
    expect(v.startsWith('BEGIN:VCARD')).toBe(true); expect(v.trim().endsWith('END:VCARD')).toBe(true)
  })
  it('escapes commas and semicolons in values', () => {
    const v = toVCard({ ...card, company: 'Acme, Inc;' })
    expect(v).toContain('ORG:Acme\\, Inc\\;')
  })
})
