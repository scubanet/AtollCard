import type { PublicCard, PublicField } from './types'

function esc(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n')
}

function lineFor(field: PublicField): string | null {
  switch (field.type) {
    case 'email': return `EMAIL;TYPE=${esc(field.label)}:${field.value}`
    case 'phone': return `TEL;TYPE=${esc(field.label)}:${field.value}`
    case 'url':
    case 'social': return `URL:${field.value}`
    case 'address': return `ADR;TYPE=${esc(field.label)}:;;${esc(field.value)};;;;`
    case 'custom': return `NOTE:${esc(field.label)}: ${esc(field.value)}`
  }
}

export function toVCard(card: PublicCard): string {
  const lines = ['BEGIN:VCARD', 'VERSION:3.0', `FN:${esc(card.display_name)}`]
  if (card.company) lines.push(`ORG:${esc(card.company)}`)
  if (card.title) lines.push(`TITLE:${esc(card.title)}`)
  for (const f of card.fields) {
    const l = lineFor(f)
    if (l) lines.push(l)
  }
  lines.push('END:VCARD')
  return lines.join('\r\n') + '\r\n'
}
