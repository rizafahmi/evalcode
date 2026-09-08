import { createApp, defineComponent, h, onMounted, ref } from "vue"

const columns = [
  { id: "lead", name: "Lead" },
  { id: "meeting", name: "Meeting" },
  { id: "proposal", name: "Proposal" },
  { id: "won", name: "Won" },
  { id: "lost", name: "Lost" },
] as const

type Deal = {
  id: string
  title: string
  amount: number
  pipeline_column_id: string
  contact: { id: string; name: string }
}

const formatIdr = (amount: number) => `Rp ${new Intl.NumberFormat("id-ID").format(amount)}`

export const App = defineComponent({
  name: "AlurApp",
  setup() {
    const deals = ref<Deal[]>([])
    const status = ref("loading")
    const moving = ref<string | null>(null)

    const loadDeals = async () => {
      status.value = "loading"
      try {
        const response = await fetch("/api/deals", { credentials: "same-origin" })
        if (!response.ok) throw new Error("Unable to load deals")
        const payload = await response.json()
        deals.value = payload.deals
        status.value = "ready"
      } catch (_error) {
        status.value = "error"
      }
    }

    const moveDeal = async (deal: Deal, columnId: string) => {
      if (deal.pipeline_column_id === columnId) return
      const previous = deal.pipeline_column_id
      moving.value = deal.id
      deal.pipeline_column_id = columnId
      try {
        const response = await fetch(`/api/deals/${deal.id}`, {
          method: "PATCH",
          credentials: "same-origin",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ pipeline_column_id: columnId }),
        })
        if (!response.ok) throw new Error("Unable to move deal")
      } catch (_error) {
        deal.pipeline_column_id = previous
        status.value = "error"
      } finally {
        moving.value = null
      }
    }

    onMounted(loadDeals)

    return () => h("main", { class: "mx-auto max-w-[1400px] px-4 py-8 sm:px-6 lg:px-8" }, [
      h("div", { class: "flex flex-wrap items-end justify-between gap-4" }, [
        h("div", [
          h("p", { class: "font-mono text-xs uppercase tracking-[0.025em] text-signal-green" }, "Workspace / pipeline"),
          h("h1", { class: "mt-2 font-display text-4xl font-semibold tracking-[-0.025em] text-chalk" }, "Deal pipeline"),
          h("p", { class: "mt-2 text-sm tracking-[0.025em] text-silver" }, "Move opportunities forward without losing the account context."),
        ]),
        h("span", { class: "font-mono text-xs uppercase tracking-[0.025em] text-fog" }, `${deals.value.length} deals / REST API`),
      ]),
      status.value === "loading" ? h("p", { class: "mt-8 rounded-md border border-basalt bg-graphite p-6 font-mono text-sm text-fog" }, "Loading pipeline…") : null,
      status.value === "error" ? h("p", { class: "mt-8 rounded-md border border-basalt bg-graphite p-6 font-mono text-sm text-signal-green" }, "Pipeline unavailable. Try refreshing the page.") : null,
      status.value === "ready" ? h("div", { class: "mt-8 grid min-w-0 grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-5" }, columns.map(column => {
        const columnDeals = deals.value.filter(deal => deal.pipeline_column_id === column.id)
        const total = columnDeals.reduce((sum, deal) => sum + deal.amount, 0)
        return h("section", {
          class: "min-w-0 rounded-md border border-basalt bg-graphite shadow-subtle",
          "data-drop-target": column.id,
          onDragover: (event: DragEvent) => event.preventDefault(),
          onDrop: (event: DragEvent) => {
            event.preventDefault()
            const id = event.dataTransfer?.getData("text/plain")
            const deal = deals.value.find(item => item.id === id)
            if (deal) void moveDeal(deal, column.id)
          },
        }, [
          h("header", { class: "border-b border-basalt bg-obsidian px-4 py-3" }, [
            h("div", { class: "flex items-center justify-between gap-2" }, [
              h("h2", { class: "font-display text-lg font-semibold tracking-[-0.015em] text-chalk" }, column.name),
              h("span", { class: "rounded-xs border border-basalt px-1.5 py-0.5 font-mono text-xs text-fog" }, String(columnDeals.length)),
            ]),
            h("p", { class: "mt-1 font-mono text-xs text-fog" }, formatIdr(total)),
          ]),
          h("div", { class: "min-h-40 space-y-2 p-3" }, columnDeals.length ? columnDeals.map(deal => h("a", {
            href: `/deals/${deal.id}`,
            draggable: true,
            class: `block rounded-md border border-basalt bg-obsidian p-3 transition-colors hover:border-pewter ${moving.value === deal.id ? "opacity-60" : ""}`,
            "data-deal-id": deal.id,
            onDragstart: (event: DragEvent) => event.dataTransfer?.setData("text/plain", deal.id),
          }, [
            h("p", { class: "font-text text-sm font-medium tracking-[0.025em] text-ash" }, deal.title),
            h("p", { class: "mt-2 text-xs tracking-[0.025em] text-silver" }, deal.contact.name),
            h("p", { class: "mt-3 font-mono text-xs text-signal-green" }, formatIdr(deal.amount)),
          ])) : [h("p", { class: "py-8 text-center font-mono text-xs text-fog" }, "Drop a deal here")]),
        ])
      })) : null,
    ])
  },
})

const mountNode = document.querySelector<HTMLElement>("#vue-app")

if (mountNode) {
  createApp(App).mount(mountNode)
}
