/// Represents the search result returned by the [scoutSearch] Cloud Function.
///
/// The function returns either:
///   • A [ScanResult] JSON object when a vendor match is found.
///   • The string `"Scan in progress"` when a vendor initiates an async scan.
///     In this case [SwitchboardService] returns `null` to the caller.
class ScanResult {
  /// Whether the vendor found a potential match.
  final bool matchFound;

  /// Confidence percentage (0–100) assigned by the vendor's matching algorithm.
  final int confidence;

  /// The URL where the match was detected.
  final String url;

  /// Thumbnail reference returned by the vendor (URL or placeholder).
  /// Never stored on-device beyond the active session — displayed only.
  final String thumbnail;

  /// The vendor that produced this result (from Firestore switchboard_config).
  final String vendorUsed;

  /// UTC timestamp of when the scan result was generated.
  final DateTime timestamp;

  const ScanResult({
    required this.matchFound,
    required this.confidence,
    required this.url,
    required this.thumbnail,
    required this.vendorUsed,
    required this.timestamp,
  });

  /// Deserializes a [ScanResult] from the Cloud Function JSON response map.
  factory ScanResult.fromMap(Map<String, dynamic> map) {
    return ScanResult(
      matchFound: map['matchFound'] as bool? ?? false,
      confidence: map['confidence'] as int? ?? 0,
      url: map['url'] as String? ?? '',
      thumbnail: map['thumbnail'] as String? ?? '',
      vendorUsed: map['vendorUsed'] as String? ?? 'unknown',
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Serializes this result to a map (used for PDF generation input).
  Map<String, dynamic> toMap() => {
        'matchFound': matchFound,
        'confidence': confidence,
        'url': url,
        'thumbnail': thumbnail,
        'vendorUsed': vendorUsed,
        'timestamp': timestamp.toIso8601String(),
      };
}
