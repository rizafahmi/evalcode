// Formats a deal amount the way the rest of Alur shows rupiah: the `Rp`
// prefix with Indonesian dot grouping (`Rp 15.000.000`). This mirrors
// `Alur.Deals.format_idr/1` server-side so the board, totals, and card
// values always read identically to the LiveView pipeline.
export function formatIdr(amount: number | null | undefined): string {
  if (amount === null || amount === undefined || Number.isNaN(amount) || amount < 0) {
    return "—"
  }

  const grouped = String(amount).replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  return `Rp ${grouped}`
}
