<script setup lang="ts">
import { ref, onMounted } from 'vue'
import type { Deal, PipelineColumn } from './types'
import { DEFAULT_COLUMNS } from './utils'
import KanbanColumn from './components/KanbanColumn.vue'

const columns = ref<PipelineColumn[]>(DEFAULT_COLUMNS)
const deals = ref<Deal[]>([])
const loading = ref<boolean>(true)
const errorMessage = ref<string | null>(null)

function getColumnDeals(column: PipelineColumn): Deal[] {
  return deals.value.filter(
    d => d.pipeline_column_id === column.id || d.pipeline_column_id === column.name
  )
}

function getColumnTotal(columnDeals: Deal[]): number {
  return columnDeals.reduce((sum, d) => sum + (d.amount || 0), 0)
}

async function loadData() {
  loading.value = true
  errorMessage.value = null
  try {
    const [pipelineRes, dealsRes] = await Promise.all([
      fetch('/api/pipeline', { credentials: 'same-origin' }),
      fetch('/api/deals', { credentials: 'same-origin' })
    ])

    if (pipelineRes.ok) {
      const pipelineData = await pipelineRes.json()
      if (pipelineData.columns && Array.isArray(pipelineData.columns) && pipelineData.columns.length > 0) {
        columns.value = pipelineData.columns
          .map((c: any) => ({
            id: c.id,
            name: c.name,
            order: c.order
          }))
          .sort((a: PipelineColumn, b: PipelineColumn) => a.order - b.order)
      }
    }

    if (dealsRes.ok) {
      const dealsData = await dealsRes.json()
      deals.value = Array.isArray(dealsData) ? dealsData : (dealsData.deals || [])
    } else if (dealsRes.status === 401) {
      window.location.href = '/users/log-in'
      return
    }
  } catch (err) {
    console.error('Failed to load board data:', err)
    errorMessage.value = 'Failed to load pipeline data.'
  } finally {
    loading.value = false
  }
}

async function handleDropDeal(payload: { dealId: string; targetColumn: PipelineColumn }) {
  const { dealId, targetColumn } = payload
  const deal = deals.value.find(d => d.id === dealId)
  if (!deal) return

  if (deal.pipeline_column_id === targetColumn.id || deal.pipeline_column_id === targetColumn.name) {
    return
  }

  const previousColumnId = deal.pipeline_column_id
  deal.pipeline_column_id = targetColumn.id
  errorMessage.value = null

  try {
    const res = await fetch(`/api/deals/${dealId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      credentials: 'same-origin',
      body: JSON.stringify({
        pipeline_column_id: targetColumn.id
      })
    })

    if (res.ok) {
      const updatedDeal = await res.json()
      const idx = deals.value.findIndex(d => d.id === dealId)
      if (idx !== -1) {
        deals.value[idx] = { ...deals.value[idx], ...updatedDeal }
      }
    } else {
      deal.pipeline_column_id = previousColumnId
      errorMessage.value = 'Unable to move deal.'
    }
  } catch (err) {
    deal.pipeline_column_id = previousColumnId
    errorMessage.value = 'Unable to move deal.'
  }
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div>
        <h1 class="text-2xl sm:text-3xl font-semibold tracking-[-0.025em] text-chalk font-display">
          Pipeline
        </h1>
        <p class="mt-1 text-sm text-fog font-text tracking-[0.025em]">
          Deal flow and stage tracking across your sales pipeline
        </p>
      </div>

      <div>
        <a
          href="/deals/new"
          class="inline-flex items-center justify-center gap-2 rounded-md bg-signal-green px-4 py-2 text-sm font-medium font-text tracking-[0.025em] text-carbon border border-led-green hover:brightness-105 active:brightness-95 transition-all shadow-subtle"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2.5"
            stroke="currentColor"
            class="size-4 shrink-0"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          <span>New deal</span>
        </a>
      </div>
    </div>

    <div
      v-if="errorMessage"
      class="rounded-md border border-rose-900/50 bg-rose-950/40 p-3 text-xs font-mono text-rose-400"
      data-testid="error-banner"
    >
      {{ errorMessage }}
    </div>

    <div
      id="kanban-board"
      class="grid grid-cols-1 md:grid-cols-5 gap-4 items-start"
    >
      <KanbanColumn
        v-for="column in columns"
        :key="column.id"
        :column="column"
        :deals="getColumnDeals(column)"
        :total-amount="getColumnTotal(getColumnDeals(column))"
        @drop-deal="handleDropDeal"
      />
    </div>
  </div>
</template>
