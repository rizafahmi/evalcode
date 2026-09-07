import { Window } from '../../assets/node_modules/happy-dom/lib/index.js'
import fs from 'node:fs'
import path from 'node:path'

async function run() {
  const window = new Window({ url: 'http://localhost:4000/app' })
  const document = window.document
  global.window = window
  global.document = document
  global.HTMLElement = window.HTMLElement
  global.Element = window.Element
  global.Node = window.Node
  global.SVGElement = window.SVGElement
  global.CustomEvent = window.CustomEvent

  document.body.innerHTML = '<div id="app"></div>'

  const sampleColumns = [
    { id: 'col-1', name: 'Lead', order: 1 },
    { id: 'col-2', name: 'Meeting', order: 2 },
    { id: 'col-3', name: 'Proposal', order: 3 },
    { id: 'col-4', name: 'Won', order: 4 },
    { id: 'col-5', name: 'Lost', order: 5 }
  ]

  let deals = [
    {
      id: 'deal-101',
      title: 'Cloud Migration Opportunity',
      amount: 15000000,
      pipeline_column_id: 'col-1',
      contact: { id: 'c-1', name: 'Budi Santoso' }
    }
  ]

  let patchCalled = false
  let patchedBody = null

  const mockFetch = async (url, options = {}) => {
    if (url === '/api/pipeline') return { ok: true, status: 200, json: async () => ({ columns: sampleColumns }) }
    if (url === '/api/deals') return { ok: true, status: 200, json: async () => deals }
    if (url.startsWith('/api/deals/') && options.method === 'PATCH') {
      patchCalled = true
      patchedBody = JSON.parse(options.body)
      deals[0].pipeline_column_id = patchedBody.pipeline_column_id
      return { ok: true, status: 200, json: async () => deals[0] }
    }
    return { ok: false, status: 404 }
  }

  window.fetch = mockFetch
  global.fetch = mockFetch

  const bundlePath = path.resolve(import.meta.dirname, '../../priv/static/assets/js/vue.js')
  const bundleCode = fs.readFileSync(bundlePath, 'utf-8')
  const AlurVue = eval(bundleCode + '; AlurVue')
  window.AlurVue = AlurVue

  AlurVue.mountApp()
  await new Promise(resolve => setTimeout(resolve, 200))

  const appEl = document.getElementById('app')
  if (!appEl.hasAttribute('data-v-app')) throw new Error('Missing data-v-app on #app')

  const leadCol = document.getElementById('column-col-1')
  if (!leadCol || !leadCol.textContent.includes('Cloud Migration Opportunity')) {
    throw new Error('Deal not rendered in Lead column')
  }

  const leadCount = document.getElementById('column-count-col-1')?.textContent.trim()
  const leadTotal = document.getElementById('column-total-col-1')?.textContent.trim()
  if (leadCount !== '1' || leadTotal !== 'Rp 15.000.000') {
    throw new Error(`Lead totals mismatch: count=${leadCount}, total=${leadTotal}`)
  }

  const card = document.getElementById('deal-card-deal-101')
  if (card.getAttribute('href') !== '/deals/deal-101') {
    throw new Error(`Card does not link to /deals/deal-101: ${card.getAttribute('href')}`)
  }

  // Simulate drop to Meeting
  const dropzone = document.getElementById('dropzone-col-2')
  const dropEvent = new window.CustomEvent('drop', { bubbles: true, cancelable: true })
  dropEvent.dataTransfer = {
    getData: (type) => (type === 'text/plain' ? 'deal-101' : null)
  }
  dropzone.dispatchEvent(dropEvent)
  await new Promise(resolve => setTimeout(resolve, 200))

  if (!patchCalled || patchedBody?.pipeline_column_id !== 'col-2') {
    throw new Error('PATCH /api/deals/deal-101 was not called with col-2')
  }

  const meetingCount = document.getElementById('column-count-col-2')?.textContent.trim()
  const meetingTotal = document.getElementById('column-total-col-2')?.textContent.trim()
  if (meetingCount !== '1' || meetingTotal !== 'Rp 15.000.000') {
    throw new Error(`Meeting totals mismatch after drop: count=${meetingCount}, total=${meetingTotal}`)
  }

  // Simulate refresh
  appEl.innerHTML = ''
  appEl.removeAttribute('data-v-app')
  AlurVue.mountApp()
  await new Promise(resolve => setTimeout(resolve, 200))

  const reloadedMeeting = document.getElementById('column-col-2')
  if (!reloadedMeeting || !reloadedMeeting.textContent.includes('Cloud Migration Opportunity')) {
    throw new Error('Deal did not persist in Meeting after refresh')
  }

  console.log('Verification passed successfully: all checks confirmed.')
}

run()
