import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mountApp } from '../main'
import { flushPromises } from '@vue/test-utils'

describe('mountApp', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="app"></div>'
    vi.restoreAllMocks()
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ status: 'ok' })
    })
  })

  it('mounts the Vue app onto #app and sets data-v-app', async () => {
    const el = document.getElementById('app')!
    expect(el.hasAttribute('data-v-app')).toBe(false)

    const app = mountApp()
    expect(app).not.toBeNull()
    await flushPromises()

    expect(el.hasAttribute('data-v-app')).toBe(true)
    expect(el.textContent).toContain('Pipeline')
    expect(el.textContent).toContain('Deal flow and stage tracking')
  })

  it('does not re-mount if data-v-app already exists', () => {
    const el = document.getElementById('app')!
    el.setAttribute('data-v-app', '')

    const app = mountApp()
    expect(app).toBeNull()
  })

  it('returns null if #app is missing', () => {
    document.body.innerHTML = '<div>No app element</div>'
    const app = mountApp()
    expect(app).toBeNull()
  })
})
