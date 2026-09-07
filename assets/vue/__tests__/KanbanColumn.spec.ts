import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import KanbanColumn from '../components/KanbanColumn.vue'
import type { Deal, PipelineColumn } from '../types'

describe('KanbanColumn.vue', () => {
  const sampleColumn: PipelineColumn = {
    id: 'col-1',
    name: 'Meeting',
    order: 2
  }

  const sampleDeals: Deal[] = [
    {
      id: 'deal-1',
      title: 'First Meeting Deal',
      amount: 10000000,
      pipeline_column_id: 'col-1',
      contact: { id: 'c-1', name: 'Alice' }
    },
    {
      id: 'deal-2',
      title: 'Second Meeting Deal',
      amount: 20000000,
      pipeline_column_id: 'col-1',
      contact: { id: 'c-2', name: 'Bob' }
    }
  ]

  it('renders column header with stage name, deal count, and formatted total', () => {
    const wrapper = mount(KanbanColumn, {
      props: {
        column: sampleColumn,
        deals: sampleDeals,
        totalAmount: 30000000
      }
    })

    expect(wrapper.text()).toContain('Meeting')
    expect(wrapper.find('[data-role="column-count"]').text()).toBe('2')
    expect(wrapper.find('[data-role="column-total"]').text()).toBe('Rp 30.000.000')
    expect(wrapper.findAllComponents({ name: 'DealCard' })).toHaveLength(2)
  })

  it('renders empty placeholder when column has no deals', () => {
    const wrapper = mount(KanbanColumn, {
      props: {
        column: sampleColumn,
        deals: [],
        totalAmount: 0
      }
    })

    expect(wrapper.find('[data-role="column-count"]').text()).toBe('0')
    expect(wrapper.find('[data-role="column-total"]').text()).toBe('Rp 0')
    expect(wrapper.text()).toContain('Drop deals here')
  })
})
