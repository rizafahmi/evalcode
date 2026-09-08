import { mount } from "@vue/test-utils"
import { App } from "./main"
import { describe, expect, it, vi } from "vitest"

describe("Alur Vue Kanban", () => {
  it("loads deals into their pipeline columns", async () => {
    vi.stubGlobal("fetch", vi.fn(() => Promise.resolve({
      ok: true,
      json: async () => ({ deals: [{ id: "1", title: "Website redesign", amount: 15000000, pipeline_column_id: "lead", contact: { id: "c1", name: "Ada Lovelace" } }] }),
    })))

    const wrapper = mount(App)
    await vi.waitFor(() => expect(wrapper.text()).toContain("Website redesign"))
    expect(wrapper.text()).toContain("Lead")
    expect(wrapper.text()).toContain("Rp 15.000.000")
  })

  it("patches a deal when it is dropped in another column", async () => {
    const fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => ({ deals: [{ id: "1", title: "Website redesign", amount: 100, pipeline_column_id: "lead", contact: { id: "c1", name: "Ada" } }] }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({}) })
    vi.stubGlobal("fetch", fetch)

    const wrapper = mount(App)
    await vi.waitFor(() => expect(wrapper.text()).toContain("Website redesign"))
    const meeting = wrapper.find('[data-drop-target="meeting"]')
    await meeting.trigger("drop", { dataTransfer: { getData: () => "1" } })

    expect(fetch).toHaveBeenLastCalledWith("/api/deals/1", expect.objectContaining({ method: "PATCH" }))
    expect(fetch.mock.calls[1][1].body).toBe(JSON.stringify({ pipeline_column_id: "meeting" }))
  })
})
