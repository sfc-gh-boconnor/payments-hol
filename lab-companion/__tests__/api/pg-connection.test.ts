import { describe, it, expect, vi, beforeEach } from "vitest"
import { POST } from "../../app/api/de3/pg-connection/route"

vi.mock("../../lib/snowflake", () => ({
  querySnowflake: vi.fn(),
}))

import { querySnowflake } from "../../lib/snowflake"

describe("POST /api/de3/pg-connection", () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it("returns the connection from the procedure's JSON result, uncached", async () => {
    vi.mocked(querySnowflake).mockResolvedValueOnce([
      { PG_CONNECTION_INFO: JSON.stringify({ ready: true, host: "h.postgres.snowflake.app", port: 5432, user: "snowflake_admin", password: "pw" }) },
    ])
    const response = await POST()
    expect(response.status).toBe(200)
    expect(response.headers.get("Cache-Control")).toBe("no-store")
    expect(await response.json()).toMatchObject({ ready: true, host: "h.postgres.snowflake.app", password: "pw" })
    expect(querySnowflake).toHaveBeenCalledWith("CALL BARCLAYS_HOL.LAB.PG_CONNECTION_INFO()")
  })

  it("passes through the not-created-yet message", async () => {
    vi.mocked(querySnowflake).mockResolvedValueOnce([{ PG_CONNECTION_INFO: { ready: false, message: "HOL_PAYMENTS_PG doesn't exist yet" } }])
    const json = await (await POST()).json()
    expect(json).toEqual({ ready: false, message: "HOL_PAYMENTS_PG doesn't exist yet" })
  })

  it("explains a missing procedure without leaking the error", async () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => {})
    vi.mocked(querySnowflake).mockRejectedValueOnce(new Error("Procedure PG_CONNECTION_INFO does not exist or not authorized"))
    const response = await POST()
    expect(response.status).toBe(500)
    expect((await response.json()).error).toMatch(/rerun setup\/00_admin_provision.sql/)
    expect(JSON.stringify(log.mock.calls)).not.toMatch(/PG_CONNECTION_INFO does not exist/)
    log.mockRestore()
  })
})
