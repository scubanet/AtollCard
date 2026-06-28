import type { PublicCard, PublicField } from './lib/types'

function escapeHTML(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

function safeURL(raw: string | null): string | null {
  if (!raw) return null
  try {
    const u = new URL(raw)
    return (u.protocol === 'https:' || u.protocol === 'http:') ? u.toString() : null
  } catch { return null }
}

function fieldRow(f: PublicField): string {
  const label = escapeHTML(f.label)
  const value = escapeHTML(f.value)
  let href = '#'
  if (f.type === 'email') href = `mailto:${value}`
  else if (f.type === 'phone') href = `tel:${value}`
  else if (f.type === 'url' || f.type === 'social') href = value
  return `<li class="field field--${f.type}"><span class="label">${label}</span>` +
    `<a class="value" href="${href}">${value}</a></li>`
}

export function renderCard(card: PublicCard): string {
  const name = escapeHTML(card.display_name)
  const title = card.title ? `<p class="title">${escapeHTML(card.title)}</p>` : ''
  const company = card.company ? `<p class="company">${escapeHTML(card.company)}</p>` : ''
  const fields = card.fields.map(fieldRow).join('')
  const accent = /^#[0-9a-fA-F]{3,8}$/.test(card.accent_color) ? card.accent_color : '#0E7C86'
  const cover = safeURL(card.cover_url)
  const photo = safeURL(card.photo_url)
  const coverEl = cover ? `<div class="cover" style="background-image:url('${cover}')"></div>` : `<div class="cover cover--empty"></div>`
  const avatarEl = photo ? `<img class="avatar" src="${photo}" alt="" />` : `<div class="avatar avatar--initials">${escapeHTML(name.slice(0,1))}</div>`
  return `<section class="card theme-${escapeHTML(card.theme)}" style="--accent:${accent}">
    ${coverEl}${avatarEl}
    <h1 class="name">${name}</h1>${title}${company}
    <ul class="fields">${fields}</ul>
    <button id="save-contact" type="button">Kontakt speichern</button>
  </section>`
}

export function renderNotFound(): string {
  return `<section class="not-found"><h1>Karte nicht gefunden</h1>
    <p>Diese Visitenkarte existiert nicht oder ist nicht öffentlich.</p></section>`
}
