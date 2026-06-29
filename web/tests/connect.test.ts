import { describe, it, expect, vi } from 'vitest'
import { recordConnection, validateConnect } from '../src/lib/connect'

describe('validateConnect', () => {
  it('requires a name', () => {
    expect(validateConnect({ name: '' }).ok).toBe(false)
    expect(validateConnect({ name: '  ' }).ok).toBe(false)
  })
  it('rejects a malformed email', () => {
    expect(validateConnect({ name: 'A', email: 'nope' }).ok).toBe(false)
  })
  it('accepts name only and name+valid email', () => {
    expect(validateConnect({ name: 'A' }).ok).toBe(true)
    expect(validateConnect({ name: 'A', email: 'a@b.co' }).ok).toBe(true)
  })
})

describe('recordConnection', () => {
  it('maps payload to the RPC params', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: null })
    await recordConnection({ rpc }, 'jane-doe', { name: 'Max', email: 'm@x.co', phone: '1', company: 'Acme', note: 'hi' })
    expect(rpc).toHaveBeenCalledWith('record_connection', {
      p_slug: 'jane-doe', p_name: 'Max', p_email: 'm@x.co', p_phone: '1', p_company: 'Acme', p_note: 'hi',
    })
  })
  it('throws on rpc error', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: 'boom' } })
    await expect(recordConnection({ rpc }, 's', { name: 'A' })).rejects.toThrow('boom')
  })
})
