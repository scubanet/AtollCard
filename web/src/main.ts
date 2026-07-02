import { createClient } from '@supabase/supabase-js'
import { slugFromPath } from './lib/slug'
import { getPublicCard, recordEvent } from './lib/api'
import { recordConnection, validateConnect, type ConnectPayload } from './lib/connect'
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

  const connectToggle = document.getElementById('connect-toggle')
  const connectForm = document.getElementById('connect-form') as HTMLFormElement | null
  connectToggle?.addEventListener('click', () => {
    if (!connectForm) return
    const willShow = connectForm.hidden
    connectForm.hidden = !willShow
    connectToggle.setAttribute('aria-expanded', String(willShow))
    if (willShow) (document.getElementById('c-firstname') as HTMLInputElement | null)?.focus()
  })

  connectForm?.addEventListener('submit', async (e) => {
    e.preventDefault()
    const status = document.getElementById('c-status')
    const val = (id: string) =>
      (document.getElementById(id) as HTMLInputElement | HTMLTextAreaElement | null)?.value.trim() ?? ''
    const consent = (document.getElementById('c-consent') as HTMLInputElement | null)?.checked ?? false
    const setStatus = (msg: string) => { if (status) status.textContent = msg }

    if (!consent) { setStatus('Bitte stimme der Übermittlung zu.'); return }

    const payload: ConnectPayload = {
      firstName: val('c-firstname'),
      lastName: val('c-lastname'),
      email: val('c-email') || undefined,
      phone: val('c-phone') || undefined,
      company: val('c-company') || undefined,
      note: val('c-note') || undefined,
    }

    const check = validateConnect(payload)
    if (!check.ok) { setStatus(check.error ?? 'Bitte Eingaben prüfen.'); return }

    setStatus('Wird gesendet…')
    try {
      await recordConnection(client, slug, payload)
      connectForm.reset()
      connectForm.hidden = true
      connectToggle?.setAttribute('aria-expanded', 'false')
      setStatus('Danke! Deine Daten wurden übermittelt.')
    } catch {
      setStatus('Senden fehlgeschlagen. Bitte später erneut versuchen.')
    }
  })
}

boot()
