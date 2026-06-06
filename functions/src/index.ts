import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

import { runSwitchboard } from "./switchboard";

// Initialize Firebase Admin SDK.
// In Cloud Functions, this automatically uses the project's service account.
admin.initializeApp();

/**
 * scoutSearch — Callable Cloud Function
 *
 * Accepts:  `{ query: string }`
 * Returns:  `SearchResult` (JSON) | `"Scan in progress"` (string)
 *
 * Flow:
 *   1. Validates the incoming [query] parameter.
 *   2. Passes the request to [runSwitchboard].
 *   3. The switchboard loads vendor config from Firestore (`switchboard_config`),
 *      routes through vendors by priority, applies 429 exponential backoff,
 *      and fails over to the next vendor on error.
 *   4. Returns either a match result JSON or `"Scan in progress"`.
 *
 * Call from Flutter:
 * ```dart
 * final result = await FirebaseFunctions.instance
 *     .httpsCallable('scoutSearch')
 *     .call({ 'query': 'user_identity_token' });
 * ```
 */
export const scoutSearch = functions.https.onCall(async (data, _context) => {
  // ── Input validation ───────────────────────────────────────────────────────
  const query =
    typeof data?.query === "string" ? (data.query as string).trim() : "";

  if (!query) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      'The function must be called with a non-empty "query" string.'
    );
  }

  console.log(`[scoutSearch] Received query: "${query}"`);

  // ── Run switchboard ────────────────────────────────────────────────────────
  try {
    const result = await runSwitchboard({ query });
    console.log(`[scoutSearch] Returning result type: ${typeof result}`);
    return result;
  } catch (err: any) {
    // Catchall — switchboard errors should be handled internally,
    // but we guard against unexpected throws here.
    console.error("[scoutSearch] Unhandled error in switchboard:", err);
    throw new functions.https.HttpsError(
      "internal",
      "An unexpected error occurred while processing the search request."
    );
  }
});
