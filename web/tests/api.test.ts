import { describe, it, expect, vi } from 'vitest'
import { getPublicCard, recordEvent, type SupabaseLike } from '../src/lib/api'
import type { PublicCard } from '../src/lib/types'

const sample: PublicCard = {
  display_name: 'Jane Doe', title: null, company: null, theme: 'default',
  accent_color: '#0E7C86', cover_url: null, logo_url: null, photo_url: null, fields: [],
}

function fakeClient(rpcImpl: (fn: string, args: unknown) => Promise<{ data: unknown; error: unknown }>): SupabaseLike {
  return { rpc: (fn: string, args: unknown) => rpcImpl(fn, args) }
}

describe('getPublicCard', () => {
  it('returns the card when present', async () => {
    const client = fakeClient(async () => ({ data: sample, error: null }))
    expect((await getPublicCard(client, 'jane-doe'))?.display_name).toBe('Jane Doe')
  })
  it('returns null when RPC yields null', async () => {
    const client = fakeClient(async () => ({ data: null, error: null }))
    expect(await getPublicCard(client, 'secret')).toBeNull()
  })
  it('throws on RPC error', async () => {
    const client = fakeClient(async () => ({ data: null, error: { message: 'boom' } }))
    await expect(getPublicCard(client, 'x')).rejects.toThrow('boom')
  })
})

describe('recordEvent', () => {
  it('calls record_card_event with slug + type', async () => {
    const rpc = vi.fn(async () => ({ data: null, error: null }))
    await recordEvent(fakeClient(rpc), 'jane-doe', 'view')
    expect(rpc).toHaveBeenCalledWith('record_card_event', { p_slug: 'jane-doe', p_type: 'view', p_coarse_geo: null })
  })
  it('never throws', async () => {
    const client = fakeClient(async () => ({ data: null, error: { message: 'down' } }))
    await expect(recordEvent(client, 'jane-doe', 'save')).resolves.toBeUndefined()
  })
})
