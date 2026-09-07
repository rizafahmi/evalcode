import { afterEach, describe, expect, it, vi } from "vitest"
import { flushPromises, mount, type VueWrapper } from "@vue/test-utils"
import App from "./App.vue"
import type { PipelineData } from "./types"

// The JSON shapes `/api/pipeline` serves (columns in board order + deals).
// Column and deal ids are stand-ins for the binary ids the server sends; the
// board never interprets them.
const columns = [
  { id: "col-lead", name: "Lead", order: 1 },
  { id: "col-meeting", name: "Meeting", order: 2 },
  { id: "col-proposal", name: "Proposal", order: 3 },
  { id: "col-won", name: "Won", order: 4 },
  { id: "col-lost", name: "Lost", order: 5 }
]

const sampleDeals = [
  {
    id: "deal-1",
    title: "Website redesign",
    amount: 15_000_000,
    pipeline_column_id: "col-lead",
    contact: { id: "contact-1", name: "Sari Wijaya" }
  },
  {
    id: "deal-2",
    title: "Logo refresh",
    amount: 10_000_000,
    pipeline_column_id: "col-meeting",
    contact: { id: "contact-2", name: "Budi Santoso" }
  }
]

const samplePipeline: PipelineData = { columns, deals: sampleDeals }

// Stub the global fetch the api.ts client uses. GET /api/pipeline serves the
// board payload; PATCH /api/deals/:id answers patchStatus and returns the
// matching deal on success. Every call is recorded for assertions.
function stubApi(pipeline: PipelineData, opts: { failPipeline?: boolean; patchStatus?: number } = {}) {
  const calls: Array<{ url: string; init?: RequestInit }> = []
  const { failPipeline = false, patchStatus = 200 } = opts

  const fetchMock = vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input)
    calls.push({ url, init })

    if (!failPipeline && url === "/api/pipeline") {
      return { ok: true, status: 200, json: async () => pipeline }
    }

    if (init?.method === "PATCH" && url.startsWith("/api/deals/")) {
      if (patchStatus >= 400) {
        return { ok: false, status: patchStatus, json: async () => ({}) }
      }

      const dealId = decodeURIComponent(url.slice("/api/deals/".length))
      const deal = pipeline.deals.find((candidate) => candidate.id === dealId)
      if (!deal) return { ok: false, status: 404, json: async () => ({}) }

      return { ok: true, status: 200, json: async () => ({ deal }) }
    }

    return { ok: false, status: 404, json: async () => ({}) }
  })

  vi.stubGlobal("fetch", fetchMock)
  return { calls, fetchMock }
}

async function mountReady(pipeline: PipelineData) {
  stubApi(pipeline)
  const wrapper = mount(App)
  await flushPromises()
  expect(wrapper.get("[data-board]").attributes("data-state")).toBe("ready")
  return wrapper
}

function column(wrapper: VueWrapper, columnId: string) {
  return wrapper.get(`[data-column-id="${columnId}"]`)
}

function card(wrapper: VueWrapper, dealId: string) {
  return wrapper.get(`[data-deal-id="${dealId}"]`)
}

function freshPipeline(): PipelineData {
  return structuredClone(samplePipeline)
}

afterEach(() => {
  vi.unstubAllGlobals()
  document.body.innerHTML = ""
})

describe("the /app Vue Kanban", () => {
  it("boots on the #app mount node (Vue sets data-v-app) and renders the board", async () => {
    const { calls } = stubApi(freshPipeline())

    const host = document.createElement("div")
    host.id = "app"
    document.body.appendChild(host)

    // The real entry point: importing it mounts the app exactly like the
    // <script src="/assets/vue/app.js"> tag on the /app controller page.
    await import("./main")
    await flushPromises()

    // Vue 3 marks the element it mounted on with data-v-app.
    expect(host.getAttribute("data-v-app")).toBe("")
    expect(host.querySelector("[data-board]")?.getAttribute("data-state")).toBe("ready")
    expect(host.textContent).toContain("Website redesign")

    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe("/api/pipeline")
  })

  it("shows the five columns in order with deals, rupiah totals, and click-through cards", async () => {
    const wrapper = await mountReady(freshPipeline())

    // Columns render Lead → Lost left to right.
    expect(
      wrapper.findAll("[data-column-id]").map((node) => node.attributes("data-column-id"))
    ).toEqual(["col-lead", "col-meeting", "col-proposal", "col-won", "col-lost"])

    const lead = column(wrapper, "col-lead")
    expect(lead.text()).toContain("Lead")
    expect(lead.text()).toContain("Website redesign")
    expect(lead.text()).toContain("Sari Wijaya")
    expect(lead.text()).toContain("Rp 15.000.000")
    // Column total matches its single card.
    expect(lead.text()).toContain("Rp 15.000.000")

    const meeting = column(wrapper, "col-meeting")
    expect(meeting.text()).toContain("Logo refresh")
    expect(meeting.text()).toContain("Rp 10.000.000")

    // A column with no deals says so and totals Rp 0.
    const proposal = column(wrapper, "col-proposal")
    expect(proposal.text()).toContain("No deals")
    expect(proposal.text()).toContain("Rp 0")

    // The whole card is a link to the LiveView deal page (click-through).
    expect(card(wrapper, "deal-1").attributes("href")).toBe("/deals/deal-1")

    // The board is fetched with JSON accept over the session cookie.
    const fetchMock = vi.mocked(fetch)
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit | undefined]
    expect(url).toBe("/api/pipeline")
    expect(init?.credentials).toBe("same-origin")
    expect(init?.headers).toMatchObject({ accept: "application/json" })
  })

  it("dragging a card to another column issues PATCH /api/deals/:id and re-renders it there", async () => {
    const { calls } = stubApi(freshPipeline())
    const wrapper = mount(App)
    await flushPromises()

    await card(wrapper, "deal-1").trigger("dragstart")
    await column(wrapper, "col-meeting").trigger("drop")
    await flushPromises()

    // The drop issued exactly one PATCH to the deal endpoint.
    const patchCalls = calls.filter((call) => call.init?.method === "PATCH")
    expect(patchCalls).toHaveLength(1)
    expect(patchCalls[0].url).toBe("/api/deals/deal-1")
    expect(patchCalls[0].init?.method).toBe("PATCH")
    expect(patchCalls[0].init?.credentials).toBe("same-origin")
    expect(patchCalls[0].init?.headers).toMatchObject({
      accept: "application/json",
      "content-type": "application/json"
    })
    expect(JSON.parse(String(patchCalls[0].init?.body))).toEqual({
      pipeline_column_id: "col-meeting"
    })

    // The card now lives in Meeting, Lead is empty, and both column totals
    // recomputed from the cards.
    const meeting = column(wrapper, "col-meeting")
    expect(card(wrapper, "deal-1").text()).toContain("Website redesign")
    expect(meeting.text()).toContain("Rp 25.000.000")

    const lead = column(wrapper, "col-lead")
    expect(lead.text()).toContain("No deals")
    expect(lead.text()).toContain("Rp 0")
  })

  it("dropping a card back on its own column issues no PATCH", async () => {
    const { calls } = stubApi(freshPipeline())
    const wrapper = mount(App)
    await flushPromises()

    await card(wrapper, "deal-1").trigger("dragstart")
    await column(wrapper, "col-lead").trigger("drop")
    await flushPromises()

    expect(calls.filter((call) => call.init?.method === "PATCH")).toHaveLength(0)
    expect(card(wrapper, "deal-1").text()).toContain("Website redesign")
  })

  it("keeps the card on its column when the move PATCH fails and shows the error", async () => {
    stubApi(freshPipeline(), { patchStatus: 500 })
    const wrapper = mount(App)
    await flushPromises()

    await card(wrapper, "deal-1").trigger("dragstart")
    await column(wrapper, "col-meeting").trigger("drop")
    await flushPromises()

    expect(wrapper.text()).toContain("Move request failed (500)")
    expect(column(wrapper, "col-lead").text()).toContain("Website redesign")
    expect(column(wrapper, "col-meeting").text()).not.toContain("Website redesign")
  })

  it("shows an error state when the pipeline request fails", async () => {
    stubApi(freshPipeline(), { failPipeline: true })
    const wrapper = mount(App)
    await flushPromises()

    expect(wrapper.get("[data-board]").attributes("data-state")).toBe("error")
    expect(wrapper.text()).toContain("Pipeline request failed (404)")
  })
})
