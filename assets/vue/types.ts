// The JSON shapes the `/api` endpoints serve to the Vue Kanban (milestone 8).
// `GET /api/pipeline` returns the fixed columns (with ids, which
// `/api/deals` does not include) plus the account's deals, so the board can
// render in one request and keep totals derived from the cards themselves.

export interface PipelineColumn {
  id: string
  name: string
  order: number
}

export interface DealContact {
  id: string
  name: string
}

export interface Deal {
  id: string
  title: string
  amount: number | null
  pipeline_column_id: string
  contact: DealContact
}

export interface PipelineData {
  columns: PipelineColumn[]
  deals: Deal[]
}
