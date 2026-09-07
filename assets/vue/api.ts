import type { PipelineData } from "./types"

// Thin client for the account-scoped JSON API the Vue Kanban talks to.
//
// The requests ride the browser session cookie (same-origin `fetch` sends it
// automatically), so no token or CORS setup exists — exactly like the rest of
// the milestone-8 REST surface. Non-2xx answers throw so the board can show
// its error state instead of silently rendering nothing.

export async function fetchPipeline(): Promise<PipelineData> {
  const response = await fetch("/api/pipeline", {
    credentials: "same-origin",
    headers: { accept: "application/json" }
  })

  if (!response.ok) {
    throw new Error(`Pipeline request failed (${response.status})`)
  }

  return (await response.json()) as PipelineData
}

export async function moveDeal(dealId: string, pipelineColumnId: string): Promise<void> {
  const response = await fetch(`/api/deals/${encodeURIComponent(dealId)}`, {
    method: "PATCH",
    credentials: "same-origin",
    headers: { accept: "application/json", "content-type": "application/json" },
    body: JSON.stringify({ pipeline_column_id: pipelineColumnId })
  })

  if (!response.ok) {
    throw new Error(`Move request failed (${response.status})`)
  }
}
