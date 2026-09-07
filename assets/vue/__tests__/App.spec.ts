import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import App from '../App.vue'
import KanbanColumn from '../components/KanbanColumn.vue'

describe('App.vue Kanban Board', () => {
  const sampleColumns = [
    { id: '0191c78a-0001-7000-8000-000000000001', name: 'Lead', order: 1 },
    { id: '0191c78a-0002-7000-8000-000000000002', name: 'Meeting', order: 2 },
    { id: '0191c78a-0003-7000-8000-000000000003', name: 'Proposal', order: 3 },
    { id: '0191c78a-0004-7000-8000-000000000004', name: 'Won', order: 4 },
    { id: '0191c78a-0005-7000-8000-000000000005', name: 'Lost', order: 5 }
  ]

  const getSampleDeals = () => [
    {
      id: 'deal-1',
      title: 'Deal in Lead',
      amount: 15000000,
      pipeline_column_id: '0191c78a-0001-7000-8000-000000000001',
      contact: { id: 'c-1', name: 'Dewi Lestari' }
    },
    {
      id: 'deal-2',
      title: 'Deal in Meeting',
      amount: 30000000,
      pipeline_column_id: '0191c78a-0002-7000-8000-000000000002',
      contact: { id: 'c-2', name: 'Eko Prasetyo' }
    }
  ]

  beforeEach(() => {
    vi.restoreAllMocks()

    global.fetch = vi.fn().mockImplementation(async (url: string, init?: RequestInit) => {
      if (url === '/api/pipeline') {
        return {
          ok: true,
          status: 200,
          json: async () => ({ columns: sampleColumns })
        }
      }

      if (url === '/api/deals') {
        return {
          ok: true,
          status: 200,
          json: async () => getSampleDeals()
        }
      }

      if (url.startsWith('/api/deals/') && init?.method === 'PATCH') {
        const body = JSON.parse(init.body as string)
        return {
          ok: true,
          status: 200,
          json: async () => ({
            id: 'deal-1',
            title: 'Deal in Lead',
            amount: 15000000,
            pipeline_column_id: body.pipeline_column_id,
            contact: { id: 'c-1', name: 'Dewi Lestari' }
          })
        }
      }

      return {
        ok: false,
        status: 404,
        json: async () => ({ error: 'not_found' })
      }
    })
  })

  it('renders pipeline title, new deal button, and 5 columns', async () => {
    const wrapper = mount(App)
    await flushPromises()

    expect(wrapper.text()).toContain('Pipeline')
    expect(wrapper.text()).toContain('Deal flow and stage tracking across your sales pipeline')
    expect(wrapper.find('a[href="/deals/new"]').exists()).toBe(true)

    const columns = wrapper.findAllComponents(KanbanColumn)
    expect(columns).toHaveLength(5)
  })

  it('places deals in their respective columns with matching totals and counts', async () => {
    const wrapper = mount(App)
    await flushPromises()

    const leadCol = wrapper.find('#column-0191c78a-0001-7000-8000-000000000001')
    expect(leadCol.find('[data-role="column-count"]').text()).toBe('1')
    expect(leadCol.find('[data-role="column-total"]').text()).toBe('Rp 15.000.000')
    expect(leadCol.text()).toContain('Deal in Lead')
    expect(leadCol.text()).toContain('Dewi Lestari')

    const meetingCol = wrapper.find('#column-0191c78a-0002-7000-8000-000000000002')
    expect(meetingCol.find('[data-role="column-count"]').text()).toBe('1')
    expect(meetingCol.find('[data-role="column-total"]').text()).toBe('Rp 30.000.000')
    expect(meetingCol.text()).toContain('Deal in Meeting')
    expect(meetingCol.text()).toContain('Eko Prasetyo')

    const proposalCol = wrapper.find('#column-0191c78a-0003-7000-8000-000000000003')
    expect(proposalCol.find('[data-role="column-count"]').text()).toBe('0')
    expect(proposalCol.find('[data-role="column-total"]').text()).toBe('Rp 0')
  })

  it('clicking a card targets the LiveView deal detail route', async () => {
    const wrapper = mount(App)
    await flushPromises()

    const card = wrapper.find('#deal-card-deal-1')
    expect(card.attributes('href')).toBe('/deals/deal-1')
  })

  it('dragging a deal from Lead to Meeting updates totals and issues PATCH /api/deals/:id', async () => {
    const wrapper = mount(App)
    await flushPromises()

    const meetingColumn = wrapper.findAllComponents(KanbanColumn).find(
      c => c.props('column').name === 'Meeting'
    )
    expect(meetingColumn).toBeDefined()

    // Trigger drop on Meeting column
    await meetingColumn!.vm.$emit('drop-deal', {
      dealId: 'deal-1',
      targetColumn: sampleColumns[1] // Meeting
    })
    await flushPromises()

    // Verify PATCH was called
    expect(global.fetch).toHaveBeenCalledWith(
      '/api/deals/deal-1',
      expect.objectContaining({
        method: 'PATCH',
        headers: expect.objectContaining({ 'Content-Type': 'application/json' }),
        body: JSON.stringify({
          pipeline_column_id: '0191c78a-0002-7000-8000-000000000002'
        })
      })
    )

    // Verify Lead column is now empty (0, Rp 0)
    const leadCol = wrapper.find('#column-0191c78a-0001-7000-8000-000000000001')
    expect(leadCol.find('[data-role="column-count"]').text()).toBe('0')
    expect(leadCol.find('[data-role="column-total"]').text()).toBe('Rp 0')

    // Verify Meeting column now has both deals (2, Rp 45.000.000)
    const meetingCol = wrapper.find('#column-0191c78a-0002-7000-8000-000000000002')
    expect(meetingCol.find('[data-role="column-count"]').text()).toBe('2')
    expect(meetingCol.find('[data-role="column-total"]').text()).toBe('Rp 45.000.000')
  })

  it('reverts optimistic move and shows error if PATCH fails', async () => {
    global.fetch = vi.fn().mockImplementation(async (url: string, init?: RequestInit) => {
      if (url === '/api/pipeline') return { ok: true, status: 200, json: async () => ({ columns: sampleColumns }) }
      if (url === '/api/deals') return { ok: true, status: 200, json: async () => getSampleDeals() }
      if (url.startsWith('/api/deals/') && init?.method === 'PATCH') {
        return { ok: false, status: 500, json: async () => ({ error: 'server_error' }) }
      }
      return { ok: false, status: 404 }
    })

    const wrapper = mount(App)
    await flushPromises()

    const meetingColumn = wrapper.findAllComponents(KanbanColumn).find(
      c => c.props('column').name === 'Meeting'
    )

    await meetingColumn!.vm.$emit('drop-deal', {
      dealId: 'deal-1',
      targetColumn: sampleColumns[1]
    })
    await flushPromises()

    // Error banner displayed
    expect(wrapper.find('[data-testid="error-banner"]').text()).toContain('Unable to move deal.')

    // Deal reverted back to Lead
    const leadCol = wrapper.find('#column-0191c78a-0001-7000-8000-000000000001')
    expect(leadCol.find('[data-role="column-count"]').text()).toBe('1')
    expect(leadCol.find('[data-role="column-total"]').text()).toBe('Rp 15.000.000')
  })
})
