import type { SupabaseLike } from './api'

export interface ConnectPayload {
  name: string
  email?: string
  phone?: string
  company?: string
  note?: string
}

export function validateConnect(p: ConnectPayload): { ok: boolean; error?: string } {
  if (!p.name || p.name.trim() === '') return { ok: false, error: 'Name erforderlich' }
  if (p.email && !/.+@.+\..+/.test(p.email)) return { ok: false, error: 'E-Mail ungültig' }
  return { ok: true }
}

export async function recordConnection(client: SupabaseLike, slug: string, p: ConnectPayload): Promise<void> {
  const { error } = await client.rpc('record_connection', {
    p_slug: slug,
    p_name: p.name,
    p_email: p.email ?? null,
    p_phone: p.phone ?? null,
    p_company: p.company ?? null,
    p_note: p.note ?? null,
  })
  if (error) throw new Error((error as { message?: string }).message ?? 'RPC error')
}
