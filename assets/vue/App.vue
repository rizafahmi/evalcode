<script setup lang="ts">
import { computed, onMounted, ref } from "vue"
import { fetchPipeline, moveDeal } from "./api"
import { formatIdr } from "./formatIdr"
import type { Deal, PipelineColumn } from "./types"

// The milestone-8 Kanban: the same five-column pipeline as the LiveView board
// at `/`, but rendered by Vue and fed by the account-scoped JSON API. The
// page-level chrome lives on the /app controller template; this component
// only owns the board itself.

type BoardState = "loading" | "ready" | "error"

const state = ref<BoardState>("loading")
const loadError = ref<string | null>(null)
const columns = ref<PipelineColumn[]>([])
const deals = ref<Deal[]>([])
const draggingDealId = ref<string | null>(null)
const dropTargetColumnId = ref<string | null>(null)
const moveError = ref<string | null>(null)
const moving = ref(false)

interface ColumnView {
  column: PipelineColumn
  columnDeals: Deal[]
  count: number
  total: number
}

const columnViews = computed<ColumnView[]>(() =>
  columns.value.map((column) => {
    const columnDeals = deals.value.filter((deal) => deal.pipeline_column_id === column.id)

    return {
      column,
      columnDeals,
      count: columnDeals.length,
      total: columnDeals.reduce((sum, deal) => sum + (deal.amount ?? 0), 0)
    }
  })
)

const dealCount = computed(() => deals.value.length)

// Won and Lost get a tiny status marker so the two end states read
// differently at a glance; the other three use a neutral dot.
function markerClass(name: string): string {
  if (name === "Won") return "bg-signal-green"
  if (name === "Lost") return "bg-fog"
  return "bg-iron"
}

async function loadBoard() {
  state.value = "loading"
  loadError.value = null
  moveError.value = null

  try {
    const data = await fetchPipeline()
    columns.value = data.columns
    deals.value = data.deals
    state.value = "ready"
  } catch (error) {
    state.value = "error"
    loadError.value =
      error instanceof Error ? error.message : "The pipeline could not be loaded."
  }
}

onMounted(loadBoard)

function clearDrag() {
  draggingDealId.value = null
  dropTargetColumnId.value = null
}

function onCardDragStart(event: DragEvent, deal: Deal) {
  draggingDealId.value = deal.id
  dropTargetColumnId.value = null

  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = "move"
    // text/plain lets Firefox actually start the drag.
    event.dataTransfer.setData("text/plain", deal.id)
  }
}

function onCardDragEnd() {
  clearDrag()
}

function onColumnDragOver(event: DragEvent) {
  if (draggingDealId.value === null) return
  event.preventDefault()
  if (event.dataTransfer) event.dataTransfer.dropEffect = "move"
}

function onColumnDragEnter(event: DragEvent, columnId: string) {
  if (draggingDealId.value === null) return
  event.preventDefault()
  dropTargetColumnId.value = columnId
}

async function onColumnDrop(event: DragEvent, columnId: string) {
  const dealId = draggingDealId.value
  clearDrag()
  if (dealId === null || moving.value) return

  event.preventDefault()

  const deal = deals.value.find((candidate) => candidate.id === dealId)
  // Dropping a card back on its own column is a no-op (no PATCH fires), and
  // the server writes no activity line for it either.
  if (!deal || deal.pipeline_column_id === columnId) return

  moving.value = true
  moveError.value = null

  try {
    await moveDeal(deal.id, columnId)
    // Only after the server confirms the move does the card change column;
    // a refresh then keeps it there because PATCH went through move_deal.
    deal.pipeline_column_id = columnId
  } catch (error) {
    moveError.value =
      error instanceof Error ? error.message : "The move could not be saved."
  } finally {
    moving.value = false
  }
}

function retry() {
  void loadBoard()
}
</script>

<template>
  <div data-board class="flex flex-col gap-4" :data-state="state">
    <div
      v-if="state === 'loading'"
      class="flex items-center gap-3 rounded-md border border-basalt bg-graphite px-4 py-6 shadow-subtle"
    >
      <span class="inline-block size-2 animate-pulse rounded-xs bg-fog" aria-hidden="true" />
      <p class="font-mono text-xs uppercase tracking-[0.025em] text-fog">Loading board…</p>
    </div>

    <div
      v-else-if="state === 'error'"
      class="flex flex-col gap-4 rounded-md border border-basalt bg-graphite px-4 py-6 shadow-subtle"
    >
      <p class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
        Board unavailable
      </p>
      <p class="text-sm font-text tracking-[0.025em] text-ash">
        {{ loadError }}
      </p>
      <div>
        <button
          type="button"
          class="inline-flex items-center justify-center gap-2 rounded-md border border-basalt px-3 py-1.5 text-sm font-medium font-text tracking-[0.025em] text-ash transition-colors duration-150 hover:border-pewter hover:text-chalk"
          @click="retry"
        >
          Try again
        </button>
      </div>
    </div>

    <template v-else>
      <div
        v-if="dealCount === 0"
        class="flex flex-wrap items-center justify-between gap-3 rounded-md border border-basalt bg-graphite px-4 py-3 shadow-subtle"
      >
        <p class="text-sm font-text tracking-[0.025em] text-fog">
          No deals yet — create one from a contact's page and it will appear on this board.
        </p>
        <a
          href="/contacts"
          class="inline-flex shrink-0 items-center justify-center gap-1.5 rounded-md border border-basalt px-3 py-1.5 text-sm font-medium font-text tracking-[0.025em] text-ash transition-colors duration-150 hover:border-pewter hover:text-chalk"
        >
          Browse contacts
        </a>
      </div>

      <div
        v-if="moveError"
        class="flex items-center justify-between gap-3 rounded-md border border-basalt bg-graphite px-4 py-3 shadow-subtle"
      >
        <p class="text-sm font-text tracking-[0.025em] text-ash">
          {{ moveError }}
        </p>
        <button
          type="button"
          class="shrink-0 rounded-xs border border-basalt bg-obsidian px-2 py-1 font-mono text-[10px] uppercase tracking-[0.025em] text-fog transition-colors duration-150 hover:border-pewter hover:text-ash"
          @click="moveError = null"
        >
          Dismiss
        </button>
      </div>

      <div class="flex items-stretch gap-4 overflow-x-auto pb-1">
        <section
          v-for="view in columnViews"
          :key="view.column.id"
          :data-column-id="view.column.id"
          :class="[
            'flex min-w-52 flex-1 flex-col overflow-hidden rounded-md border bg-graphite shadow-subtle transition-colors duration-150',
            dropTargetColumnId === view.column.id ? 'kanban-drop-target' : 'border-basalt'
          ]"
          @dragover="onColumnDragOver"
          @dragenter="onColumnDragEnter($event, view.column.id)"
          @drop="onColumnDrop($event, view.column.id)"
        >
          <header class="space-y-1 border-b border-basalt bg-obsidian/60 px-3 py-2.5">
            <div class="flex items-center justify-between gap-2">
              <div class="flex min-w-0 items-center gap-2">
                <span
                  :class="['size-1.5 shrink-0 rounded-xs', markerClass(view.column.name)]"
                  aria-hidden="true"
                />
                <h2 class="truncate font-mono text-xs font-medium uppercase tracking-[0.025em] text-ash">
                  {{ view.column.name }}
                </h2>
              </div>
              <span
                class="shrink-0 rounded-xs border border-basalt bg-obsidian px-1.5 py-0.5 font-mono text-[10px] tracking-[0.025em] text-fog"
              >
                {{ view.count }}
              </span>
            </div>
            <p class="font-mono text-sm tracking-[0.025em] text-chalk">
              {{ formatIdr(view.total) }}
            </p>
          </header>

          <div class="flex flex-1 flex-col gap-2 p-2">
            <a
              v-for="deal in view.columnDeals"
              :key="deal.id"
              :href="`/deals/${deal.id}`"
              draggable="true"
              :data-deal-id="deal.id"
              :class="[
                'group flex cursor-grab select-none flex-col gap-1 rounded-md border border-basalt bg-obsidian px-3 py-2.5 shadow-subtle transition-colors duration-150 hover:border-pewter active:cursor-grabbing',
                draggingDealId === deal.id ? 'is-dragging' : ''
              ]"
              @dragstart="onCardDragStart($event, deal)"
              @dragend="onCardDragEnd"
            >
              <span class="min-w-0 truncate text-sm font-medium font-text tracking-[0.025em] text-ash">
                {{ deal.title }}
              </span>
              <span class="flex items-center justify-between gap-2">
                <span class="min-w-0 truncate text-xs font-text tracking-[0.025em] text-fog">
                  {{ deal.contact.name }}
                </span>
                <span class="shrink-0 font-mono text-xs tracking-[0.025em] text-silver">
                  {{ formatIdr(deal.amount) }}
                </span>
              </span>
            </a>

            <div
              v-if="view.columnDeals.length === 0"
              class="flex flex-1 items-center justify-center rounded-xs border border-dashed border-basalt px-3 py-6 text-center font-mono text-xs tracking-[0.025em] text-fog"
            >
              No deals
            </div>
          </div>
        </section>
      </div>

      <p class="font-mono text-xs tracking-[0.025em] text-fog">
        This board shows deals from your account only. New deals start on the column you pick
        when you create them from a contact.
      </p>
    </template>
  </div>
</template>
