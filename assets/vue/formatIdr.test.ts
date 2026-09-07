import { describe, expect, it } from "vitest"
import { formatIdr } from "./formatIdr"

describe("formatIdr", () => {
  it("formats whole rupiah amounts with Indonesian grouping", () => {
    expect(formatIdr(15_000_000)).toBe("Rp 15.000.000")
    expect(formatIdr(0)).toBe("Rp 0")
    expect(formatIdr(1_000)).toBe("Rp 1.000")
    expect(formatIdr(1_000_000_000)).toBe("Rp 1.000.000.000")
    expect(formatIdr(999)).toBe("Rp 999")
  })

  it("renders a dash for a missing amount", () => {
    expect(formatIdr(null)).toBe("—")
    expect(formatIdr(undefined)).toBe("—")
  })
})
