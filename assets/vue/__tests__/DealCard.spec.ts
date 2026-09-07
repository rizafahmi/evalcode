import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import DealCard from '../components/DealCard.vue'
import type { Deal } from '../types'

describe('DealCard.vue', () => {
  const sampleDeal: Deal = {
    id: 'deal-123',
    title: 'Enterprise License Deal',
    amount: 25000000,
    pipeline_column_id: 'col-1',
    contact: {
      id: 'contact-456',
      name: 'Budi Santoso'
    }
  }

  it('renders deal title, contact name, and formatted IDR amount', () => {
    const wrapper = mount(DealCard, {
      props: { deal: sampleDeal }
    })

    expect(wrapper.text()).toContain('Enterprise License Deal')
    expect(wrapper.text()).toContain('Budi Santoso')
    expect(wrapper.text()).toContain('Rp 25.000.000')
  })

  it('links to the LiveView deal page', () => {
    const wrapper = mount(DealCard, {
      props: { deal: sampleDeal }
    })

    const link = wrapper.find('a')
    expect(link.attributes('href')).toBe('/deals/deal-123')
    expect(link.attributes('data-deal-id')).toBe('deal-123')
    expect(link.attributes('draggable')).toBe('true')
  })

  it('falls back to "No contact" if contact is missing', () => {
    const dealWithoutContact: Deal = {
      id: 'deal-789',
      title: 'Inbound Inquiry',
      amount: 5000000,
      pipeline_column_id: 'col-1'
    }

    const wrapper = mount(DealCard, {
      props: { deal: dealWithoutContact }
    })

    expect(wrapper.text()).toContain('No contact')
  })
})
