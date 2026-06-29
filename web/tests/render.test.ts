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
  it('renders the connect form with a required name input', () => {
    const html = renderCard(card)
    expect(html).toContain('id="connect-form"')
    expect(html).toMatch(/<input id="c-name"[^>]*\srequired/)
  })
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

function cardWith(fields: { type: string; label: string; value: string }[]) {
  return {
    display_name: 'Jane', title: null, company: null, theme: 'default',
    accent_color: '#0E7C86', cover_url: null, logo_url: null, photo_url: null,
    fields,
  } as any
}

describe('fieldRow link safety', () => {
  it('does not emit a javascript: href for a url field', () => {
    const html = renderCard(cardWith([{ type: 'url', label: 'Web', value: 'javascript:alert(1)' }]))
    expect(html).not.toContain('href="javascript')
    expect(html).toContain('<span class="value">javascript:alert(1)</span>')
  })
  it('emits an https href for a valid url field', () => {
    const html = renderCard(cardWith([{ type: 'url', label: 'Web', value: 'https://acme.example' }]))
    expect(html).toContain('href="https://acme.example')
  })
  it('treats social the same (no unsafe scheme)', () => {
    const html = renderCard(cardWith([{ type: 'social', label: 'X', value: 'data:text/html,evil' }]))
    expect(html).not.toContain('href="data:')
  })
  it('builds mailto/tel for email/phone', () => {
    const html = renderCard(cardWith([
      { type: 'email', label: 'M', value: 'a@b.co' },
      { type: 'phone', label: 'P', value: '+41 79 1' },
    ]))
    expect(html).toContain('href="mailto:a@b.co')
    expect(html).toContain('href="tel:+41791"')
  })
})
