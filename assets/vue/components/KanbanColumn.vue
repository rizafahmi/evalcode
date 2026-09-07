<script setup lang="ts">
import { ref } from 'vue'
import type { Deal, PipelineColumn } from '../types'
import { formatIdr, stageBadgeClass } from '../utils'
import DealCard from './DealCard.vue'

const props = defineProps<{
  column: PipelineColumn
  deals: Deal[]
  totalAmount: number
}>()

const emit = defineEmits<{
  (e: 'drop-deal', payload: { dealId: string; targetColumn: PipelineColumn }): void
}>()

const isDragOver = ref(false)

function onDragEnter() {
  isDragOver.value = true
}

function onDragOver(e: DragEvent) {
  if (e.dataTransfer) {
    e.dataTransfer.dropEffect = 'move'
  }
}

function onDragLeave(e: DragEvent) {
  const currentTarget = e.currentTarget as HTMLElement
  if (!currentTarget || !currentTarget.contains(e.relatedTarget as Node)) {
    isDragOver.value = false
  }
}

function onDrop(e: DragEvent) {
  isDragOver.value = false
  const dealId = e.dataTransfer?.getData('text/plain')
  if (dealId) {
    emit('drop-deal', { dealId, targetColumn: props.column })
  }
}
</script>

<template>
  <div
    :id="'column-' + column.id"
    :data-column-id="column.id"
    :data-column-name="column.name"
    :class="[
      'kanban-column rounded-md bg-graphite border border-basalt p-3.5 flex flex-col min-h-[520px] transition-colors shadow-subtle',
      isDragOver ? 'ring-1 ring-signal-green/40 bg-obsidian/70' : ''
    ]"
    @dragenter.prevent="onDragEnter"
    @dragover.prevent="onDragOver"
    @dragleave="onDragLeave"
    @drop.prevent="onDrop"
  >
    <div class="flex items-center justify-between pb-3 border-b border-basalt mb-3">
      <div class="flex items-center gap-2">
        <span
          :class="[
            'inline-flex items-center rounded-xs px-2 py-0.5 text-xs font-mono tracking-[0.025em] border font-medium',
            stageBadgeClass(column.name)
          ]"
        >
          {{ column.name }}
        </span>
        <span
          class="text-xs font-mono text-fog font-medium"
          data-role="column-count"
          :id="'column-count-' + column.id"
        >
          {{ deals.length }}
        </span>
      </div>
      <div class="text-right">
        <span
          class="font-mono text-xs font-semibold text-silver"
          data-role="column-total"
          :id="'column-total-' + column.id"
        >
          {{ formatIdr(totalAmount) }}
        </span>
      </div>
    </div>

    <div
      :id="'dropzone-' + column.id"
      class="kanban-drop-zone flex-1 flex flex-col gap-2.5 min-h-[200px]"
    >
      <DealCard
        v-for="deal in deals"
        :key="deal.id"
        :deal="deal"
      />

      <div
        v-if="deals.length === 0"
        class="empty-column-placeholder flex-1 min-h-[140px] rounded-md border border-dashed border-basalt/50 flex flex-col items-center justify-center text-xs font-mono text-fog/50 p-4 text-center select-none"
      >
        <span>Drop deals here</span>
      </div>
    </div>
  </div>
</template>
