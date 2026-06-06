/// Vendor configuration document shape stored in Firestore.
///
/// Collection path: `switchboard_config/{vendorId}`
///
/// Each document represents one search vendor the switchboard can route through.
/// Add, remove, or re-prioritize vendors in Firestore without redeploying.
export interface VendorConfig {
  /** Firestore document ID — set automatically by [loadVendors]. */
  id: string;

  /** Human-readable name displayed in logs and returned in results. */
  name: string;

  /**
   * Routing order. Lower number = higher priority.
   * The switchboard tries vendors in ascending priority order.
   */
  priority: number;

  /** Set to false to exclude this vendor from routing without deleting the document. */
  enabled: boolean;

  /** Vendor tier — used for future premium/standard rotation logic. */
  tier: "premium" | "standard";

  // ── Mock / test flags (remove in production) ─────────────────────────────

  /** When true, the mock vendor throws a 429 to trigger backoff testing. */
  mockShouldReturn429: boolean;

  /** When true, the mock vendor throws a generic error to trigger failover. */
  mockShouldFail: boolean;

  /** When true, the mock vendor signals an async scan ("Scan in progress"). */
  mockAsyncScan: boolean;

  /** Simulated vendor API response time in milliseconds. */
  mockDelayMs: number;
}
