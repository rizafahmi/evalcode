export interface Contact {
  id: string
  name: string
  email?: string | null
  phone?: string | null
}

export interface Deal {
  id: string
  title: string
  amount: number
  notes?: string | null
  pipeline_column_id: string
  contact_id?: string
  contact?: Contact | null
  inserted_at?: string
  updated_at?: string
}

export interface PipelineColumn {
  id: string
  name: string
  order: number
}
