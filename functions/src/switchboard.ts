import * as admin from "firebase-admin";

import { VendorConfig } from "./models/vendor_config";

// ── Constants ─────────────────────────────────────────────────────────────────

/** Maximum number of 429-retry attempts per vendor before failing over. */
const MAX_RETRIES = 3;

/**
 * Base delay for exponential backoff in milliseconds.
 *
 * Schedule:
 *   Attempt 1 → 2 000 ms
 *   Attempt 2 → 4 000 ms
 *   Attempt 3 → 8 000 ms
 */
const BASE_BACKOFF_MS = 2_000;

// ── Types ─────────────────────────────────────────────────────────────────────

export interface SearchRequest {
  query: string;
}

export interface SearchResult {
  matchFound: boolean;
  /** Confidence score 0–100 assigned by the vendor. */
  confidence: number;
  /** URL where the match was detected. */
  url: string;
  /** Vendor-supplied thumbnail reference (URL or placeholder). */
  thumbnail: string;
  /** Which vendor produced this result. */
  vendorUsed: string;
  /** ISO-8601 UTC timestamp of when the scan completed. */
  timestamp: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Returns a promise that resolves after [ms] milliseconds. */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Calculates the exponential backoff delay for a given attempt number.
 *
 * @param attempt - 1-based attempt index (1, 2, 3 …)
 * @returns Delay in milliseconds.
 */
function backoffDelay(attempt: number): number {
  return BASE_BACKOFF_MS * Math.pow(2, attempt - 1);
}

// ── Vendor Loader ─────────────────────────────────────────────────────────────

/**
 * Fetches all enabled vendor documents from the `switchboard_config` Firestore
 * collection and returns them sorted by `priority` ascending.
 *
 * Adding a new vendor requires only a new Firestore document — no code deploy.
 */
async function loadVendors(): Promise<VendorConfig[]> {
  const snapshot = await admin
    .firestore()
    .collection("switchboard_config")
    .where("enabled", "==", true)
    .get();

  const vendors: VendorConfig[] = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...(doc.data() as Omit<VendorConfig, "id">),
  }));

  // Sort ascending: lower priority number = higher routing priority.
  return vendors.sort((a, b) => a.priority - b.priority);
}

// ── Mock Vendor Caller ────────────────────────────────────────────────────────

/**
 * Simulates calling a vendor's search API.
 *
 * In production: replace this function with real HTTP calls to each vendor's
 * REST endpoint. The interface and error conventions remain the same.
 *
 * Error conventions:
 *   • error.code === 429  → rate-limited; caller should retry with backoff.
 *   • error.code === "ASYNC" → vendor started async scan; return immediately.
 *   • any other error → vendor failed; caller should fail over.
 */
async function callVendor(
  vendor: VendorConfig,
  request: SearchRequest
): Promise<SearchResult> {
  // Simulate vendor API latency.
  await sleep(vendor.mockDelayMs ?? 300);

  if (vendor.mockAsyncScan) {
    // Vendor initiated an async scan — return "Scan in progress" signal.
    const asyncErr = new Error("Vendor initiated async scan") as any;
    asyncErr.code = "ASYNC";
    throw asyncErr;
  }

  if (vendor.mockShouldReturn429) {
    // Simulate HTTP 429 Too Many Requests.
    const rateLimitErr = new Error("Too Many Requests") as any;
    rateLimitErr.code = 429;
    throw rateLimitErr;
  }

  if (vendor.mockShouldFail) {
    // Simulate a generic vendor-side error.
    throw new Error(`Vendor "${vendor.name}" returned a server error`);
  }

  // ── Success: return mock match result ──────────────────────────────────────
  // In production, parse the vendor's real API response here.
  const confidence = Math.floor(Math.random() * 20) + 75; // 75–94%
  const slug = request.query.replace(/\s+/g, "-").toLowerCase();

  return {
    matchFound: true,
    confidence,
    url: `https://example-content-site.com/media/${slug}-match`,
    thumbnail: `https://via.placeholder.com/150x150.png?text=${vendor.name}`,
    vendorUsed: vendor.name,
    timestamp: new Date().toISOString(),
  };
}

// ── Main Switchboard ──────────────────────────────────────────────────────────

/**
 * Routes a search request through configured vendors in priority order.
 *
 * For each vendor:
 *   1. Calls [callVendor].
 *   2. On HTTP 429: waits [backoffDelay(attempt)] then retries (max [MAX_RETRIES]).
 *   3. On other errors: immediately fails over to the next vendor.
 *   4. On async signal: returns `"Scan in progress"` immediately.
 *   5. On success: returns the [SearchResult].
 *
 * If all vendors are exhausted without a result, returns `"Scan in progress"`.
 *
 * @param request - The search parameters.
 * @returns A [SearchResult] on success or the string `"Scan in progress"`.
 */
export async function runSwitchboard(
  request: SearchRequest
): Promise<SearchResult | "Scan in progress"> {
  const vendors = await loadVendors();

  if (vendors.length === 0) {
    console.warn("[Switchboard] No enabled vendors found in switchboard_config.");
    return "Scan in progress";
  }

  for (const vendor of vendors) {
    console.log(
      `[Switchboard] Trying vendor: "${vendor.name}" (priority: ${vendor.priority})`
    );

    let attempt = 0;

    while (attempt < MAX_RETRIES) {
      attempt++;

      try {
        const result = await callVendor(vendor, request);
        console.log(
          `[Switchboard] Success — vendor: "${vendor.name}", attempt: ${attempt}`
        );
        return result;
      } catch (err: any) {
        // ── Async scan signal ──────────────────────────────────────────────
        if (err.code === "ASYNC") {
          console.log(
            `[Switchboard] Vendor "${vendor.name}" started async scan.`
          );
          return "Scan in progress";
        }

        // ── 429 Too Many Requests — exponential backoff ──────────────────
        if (err.code === 429) {
          if (attempt < MAX_RETRIES) {
            const delay = backoffDelay(attempt);
            console.warn(
              `[Switchboard] Vendor "${vendor.name}" 429 on attempt ${attempt}. ` +
                `Retrying in ${delay}ms…`
            );
            await sleep(delay);
            continue; // retry same vendor
          } else {
            console.warn(
              `[Switchboard] Vendor "${vendor.name}" exhausted ${MAX_RETRIES} retries ` +
                `after repeated 429s. Failing over.`
            );
            break; // exit while-loop → try next vendor
          }
        }

        // ── Other error — immediate failover ─────────────────────────────
        console.warn(
          `[Switchboard] Vendor "${vendor.name}" failed on attempt ${attempt}: ` +
            `${err.message}. Failing over to next vendor.`
        );
        break; // exit while-loop → try next vendor
      }
    }
  }

  // All vendors exhausted without a result.
  console.warn("[Switchboard] All vendors failed. Returning 'Scan in progress'.");
  return "Scan in progress";
}
