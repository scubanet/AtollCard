import { describe, it, expect } from 'vitest'
import { renderCard, renderNotFound } from '../src/render'
import type { PublicCard } from '../src/lib/types'

const card: PublicCard = {
  display_name: 'Jane Doe', title: 'CTO', company: 'Acme', theme: 'default',
  accent_color: '#0E7C86', cover_url: null, logo_url: null, photo_url: null,
  fields: [{ type: 'email', label: 'Work', value: 'jane@acme.com' }],
}

describe('renderCard', () => {
  it('shows name, title, company', () => {
    const html = renderCard(card)
    expect(html).toContain('Jane Doe'); expect(html).toContain('CTO'); expect(html).toContain('Acme')
  })
  it('renders a save-contact button', () => { expect(renderCard(card)).toContain('id="save-contact"') })
  it('applies the per-card accent color', () => { expect(renderCard(card)).toContain('--accent:#0E7C86') })
  it('renders cover and avatar images when present', () => {
    const html = renderCard({ ...card, cover_url: 'https://x/c.png', photo_url: 'https://x/a.png' })
    expect(html).toContain('https://x/c.png'); expect(html).toContain('https://x/a.png')
  })
  it('escapes HTML in user values', () => {
    const html = renderCard({ ...card, display_name: '<script>alert(1)</script>' })
    expect(html).not.toContain('<script>alert(1)</script>'); expect(html).toContain('&lt;script&gt;')
  })
})

describe('renderNotFound', () => {
  it('shows a friendly message', () => { expect(renderNotFound()).toContain('nicht gefunden') })
})
