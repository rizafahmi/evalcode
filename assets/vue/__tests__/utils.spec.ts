import { describe, it, expect } from 'vitest'
import { formatIdr, stageBadgeClass, DEFAULT_COLUMNS } from '../utils'

describe('formatIdr', () => {
  it('formats positive numbers as IDR with period separators', () => {
    expect(formatIdr(15000000)).toBe('Rp 15.000.000')
    expect(formatIdr(500000)).toBe('Rp 500.000')
    expect(formatIdr(1000)).toBe('Rp 1.000')
  })

  it('formats zero correctly', () => {
    expect(formatIdr(0)).toBe('Rp 0')
  })

  it('handles null, undefined and NaN gracefully', () => {
    expect(formatIdr(null)).toBe('Rp 0')
    expect(formatIdr(undefined)).toBe('Rp 0')
    expect(formatIdr(NaN)).toBe('Rp 0')
  })

  it('formats negative numbers with leading minus', () => {
    expect(formatIdr(-15000000)).toBe('-Rp 15.000.000')
  })
})

describe('stageBadgeClass', () => {
  it('returns distinct Depot badge styles for canonical stages', () => {
    expect(stageBadgeClass('Lead')).toContain('text-ash')
    expect(stageBadgeClass('Meeting')).toContain('text-link-blue')
    expect(stageBadgeClass('Proposal')).toContain('text-lavender-mist')
    expect(stageBadgeClass('Won')).toContain('text-signal-green')
    expect(stageBadgeClass('Lost')).toContain('text-rose-400')
  })

  it('returns default styling for unknown stages', () => {
    expect(stageBadgeClass('Unknown')).toContain('text-ash')
  })
})

describe('DEFAULT_COLUMNS', () => {
  it('contains 5 standard stages in correct order', () => {
    expect(DEFAULT_COLUMNS).toHaveLength(5)
    expect(DEFAULT_COLUMNS.map(c => c.name)).toEqual(['Lead', 'Meeting', 'Proposal', 'Won', 'Lost'])
  })
})
