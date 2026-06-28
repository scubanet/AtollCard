import type { PublicCard } from './types'

export interface SupabaseLike {
  rpc(fn: string, args: unknown): Promise<{ data: unknown; error: unknown }>
}

export async function getPublicCard(client: SupabaseLike, slug: string): Promise<PublicCard | null> {
  const { data, error } = await client.rpc('get_public_card', { p_slug: slug })
  if (error) throw new Error((error as { message?: string }).message ?? 'RPC error')
  if (!data) return null
  const card = data as PublicCard
  if (!card.display_name) return null
  return card
}

export async function recordEvent(
  client: SupabaseLike,
  slug: string,
  type: 'view' | 'tap' | 'save' | 'share',
): Promise<void> {
  try {
    await client.rpc('record_card_event', { p_slug: slug, p_type: type, p_coarse_geo: null })
  } catch {
    // best-effort analytics; never surface to the visitor
  }
}
