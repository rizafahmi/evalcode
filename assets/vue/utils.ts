import type { PipelineColumn } from './types'

export const DEFAULT_COLUMNS: PipelineColumn[] = [
  { id: '0191c78a-0001-7000-8000-000000000001', name: 'Lead', order: 1 },
  { id: '0191c78a-0002-7000-8000-000000000002', name: 'Meeting', order: 2 },
  { id: '0191c78a-0003-7000-8000-000000000003', name: 'Proposal', order: 3 },
  { id: '0191c78a-0004-7000-8000-000000000004', name: 'Won', order: 4 },
  { id: '0191c78a-0005-7000-8000-000000000005', name: 'Lost', order: 5 }
]

export function formatIdr(amount: number | null | undefined): string {
  if (amount == null || isNaN(amount)) {
    return 'Rp 0'
  }
  const isNegative = amount < 0
  const abs = Math.abs(Math.round(amount))
  const formatted = abs.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')
  return `${isNegative ? '-Rp ' : 'Rp '}${formatted}`
}

export function stageBadgeClass(stageName: string): string {
  switch (stageName) {
    case 'Lead':
      return 'bg-slate border-basalt text-ash'
    case 'Meeting':
      return 'bg-slate border-link-blue/40 text-link-blue'
    case 'Proposal':
      return 'bg-plum-edge border-iris-border text-lavender-mist'
    case 'Won':
      return 'bg-fern-ground border-moss-border text-signal-green'
    case 'Lost':
      return 'bg-rose-950/40 border-rose-900/50 text-rose-400'
    default:
      return 'bg-slate border-basalt text-ash'
  }
}
