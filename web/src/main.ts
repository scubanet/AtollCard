import { createClient } from '@supabase/supabase-js'
import { slugFromPath } from './lib/slug'
import { getPublicCard, recordEvent } from './lib/api'
import { toVCard } from './lib/vcard'
import { downloadVCard } from './lib/download'
import { hasConsent, grantConsent } from './lib/consent'
import { renderCard, renderNotFound } from './render'
import './style.css'

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL as string
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY as string

function consentBanner(): string {
  if (hasConsent()) return ''
  return `<div id="consent" class="consent">
    <span>Anonyme Statistik (Aufrufe) erlauben?</span>
    <button id="consent-ok" type="button">OK</button>
  </div>`
}

async function boot() {
  const app = document.getElementById('app')!
  const slug = slugFromPath(window.location.pathname)
  if (!slug) { app.innerHTML = renderNotFound(); return }

  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  let card
  try { card = await getPublicCard(client, slug) }
  catch { app.innerHTML = renderNotFound(); return }
  if (!card) { app.innerHTML = renderNotFound(); return }

  app.innerHTML = renderCard(card) + consentBanner()
  if (hasConsent()) void recordEvent(client, slug, 'view')

  document.getElementById('consent-ok')?.addEventListener('click', () => {
    grantConsent()
    document.getElementById('consent')?.remove()
    void recordEvent(client, slug, 'view')
  })

  document.getElementById('save-contact')?.addEventListener('click', () => {
    downloadVCard(toVCard(card!), card!.display_name)
    if (hasConsent()) void recordEvent(client, slug, 'save')
  })
}

boot()
