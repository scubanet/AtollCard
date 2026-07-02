import { describe, it, expect, vi } from 'vitest'
import { recordConnection, validateConnect } from '../src/lib/connect'

describe('validateConnect', () => {
  it('requires first and last name', () => {
    expect(validateConnect({ firstName: '', lastName: 'M' }).ok).toBe(false)
    expect(validateConnect({ firstName: 'Max', lastName: ' ' }).ok).toBe(false)
    expect(validateConnect({ firstName: 'Max', lastName: 'Muster' }).ok).toBe(true)
  })
  it('rejects a malformed email', () => {
    expect(validateConnect({ firstName: 'A', lastName: 'B', email: 'nope' }).ok).toBe(false)
  })
})

describe('recordConnection', () => {
  it('maps payload to the RPC params', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: null })
    await recordConnection({ rpc }, 'jane-doe', { firstName: 'Max', lastName: 'Muster', email: 'm@x.co', phone: '1', company: 'Acme', note: 'hi' })
    expect(rpc).toHaveBeenCalledWith('record_connection', {
      p_slug: 'jane-doe', p_first_name: 'Max', p_last_name: 'Muster',
      p_email: 'm@x.co', p_phone: '1', p_company: 'Acme', p_note: 'hi',
    })
  })
  it('throws on rpc error', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: 'boom' } })
    await expect(recordConnection({ rpc }, 's', { firstName: 'A', lastName: 'B' })).rejects.toThrow('boom')
  })
})
