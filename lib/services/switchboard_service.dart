import 'package:cloud_functions/cloud_functions.dart';

import '../models/scan_result.dart';

/// Handles communication with the [scoutSearch] Firebase Cloud Function.
///
/// Responsibilities:
///   • Calls the Cloud Function via [FirebaseFunctions.httpsCallable].
///   • Parses the response into a [ScanResult] or returns `null` for async scans.
///   • Does NOT implement retry/backoff — that logic lives server-side
///     in the Cloud Function switchboard.
class SwitchboardService {
  final FirebaseFunctions _functions;

  /// Creates a [SwitchboardService].
  ///
  /// Accepts an optional [FirebaseFunctions] instance for unit testing.
  SwitchboardService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Calls the [scoutSearch] Cloud Function and returns a [ScanResult].
  ///
  /// Returns `null` when the function responds with `"Scan in progress"`,
  /// indicating the vendor initiated an async scan. The caller should show
  /// an appropriate "pending" state in the UI.
  ///
  /// Throws [FirebaseFunctionsException] on Cloud Function errors (4xx/5xx).
  /// Throws [Exception] if the response format is unexpected.
  Future<ScanResult?> runScoutSearch({
    required String searchQuery,
  }) async {
    // Reference the callable Cloud Function with a 60-second timeout
    // to allow for switchboard retries and backoff within the function.
    final callable = _functions.httpsCallable(
      'scoutSearch',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    final result = await callable.call<dynamic>({
      'query': searchQuery,
    });

    final data = result.data;

    // The Cloud Function returns either a String or a Map.
    if (data is String && data == 'Scan in progress') {
      // Vendor initiated an async scan — caller should show pending UI.
      return null;
    }

    if (data is Map) {
      // Cast to the correct generic type and deserialize.
      return ScanResult.fromMap(Map<String, dynamic>.from(data));
    }

    throw Exception(
      'Unexpected response format from scoutSearch Cloud Function: '
      '${data.runtimeType}',
    );
  }
}
