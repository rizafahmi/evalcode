<script setup lang="ts">
import { ref } from 'vue'
import type { Deal } from '../types'
import { formatIdr } from '../utils'

const props = defineProps<{
  deal: Deal
}>()

const isDragging = ref(false)

function onDragStart(e: DragEvent) {
  isDragging.value = true
  if (e.dataTransfer) {
    e.dataTransfer.setData('text/plain', props.deal.id)
    e.dataTransfer.effectAllowed = 'move'
  }
}

function onDragEnd() {
  setTimeout(() => {
    isDragging.value = false
  }, 100)
}

function onClick(e: MouseEvent) {
  if (isDragging.value) {
    e.preventDefault()
    e.stopImmediatePropagation()
  }
}
</script>

<template>
  <a
    :id="'deal-card-' + deal.id"
    :href="'/deals/' + deal.id"
    :data-deal-id="deal.id"
    draggable="true"
    :class="[
      'deal-card block rounded-md bg-obsidian border border-basalt p-3.5 hover:border-pewter transition-all shadow-subtle group cursor-grab active:cursor-grabbing',
      isDragging ? 'opacity-40 scale-[0.98]' : ''
    ]"
    @dragstart="onDragStart"
    @dragend="onDragEnd"
    @click="onClick"
  >
    <div class="flex flex-col gap-2">
      <h3 class="font-display font-medium text-chalk text-sm tracking-[-0.015em] group-hover:text-ash line-clamp-2">
        {{ deal.title }}
      </h3>

      <div class="flex items-center gap-1.5 text-xs text-fog font-text tracking-[0.025em]">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class="size-3.5 shrink-0 text-fog/60"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z"
          />
        </svg>
        <span class="truncate">{{ deal.contact?.name || 'No contact' }}</span>
      </div>

      <div class="mt-1 pt-2 border-t border-basalt/60 flex items-center justify-between">
        <span class="font-mono text-xs font-semibold text-signal-green">
          {{ formatIdr(deal.amount) }}
        </span>
      </div>
    </div>
  </a>
</template>
