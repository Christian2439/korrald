import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/scan_result.dart';
import '../services/pdf_service.dart';
import '../services/switchboard_service.dart';

/// Main evaluation screen for the Korrald Switchboard Test.
///
/// Demonstrates the full flow:
///   1. User taps [Start Scout Search] → calls [SwitchboardService]
///      which invokes the Firebase Cloud Function switchboard.
///   2. Result card displays: match status, confidence score, URL, and a
///      privacy-blurred thumbnail placeholder.
///   3. User taps [Generate Evidence PDF] → calls [PdfService] to render
///      and save an on-device PDF (never uploaded to any server).
///   4. Success card shows the local file path.
class ScoutScreen extends StatefulWidget {
  const ScoutScreen({super.key});

  @override
  State<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends State<ScoutScreen> {
  // ── Services ────────────────────────────────────────────────────────────────
  final _switchboard = SwitchboardService();
  final _pdfService = PdfService();

  // ── UI State ─────────────────────────────────────────────────────────────────
  bool _isSearching = false;
  bool _isGeneratingPdf = false;

  ScanResult? _scanResult;         // Non-null when a match result is received
  bool _scanInProgress = false;    // True when CF returned "Scan in progress"
  String? _pdfPath;                // Local path after successful PDF generation
  String? _errorMessage;           // Non-null on any error

  // ── Actions ───────────────────────────────────────────────────────────────────

  /// Calls the [scoutSearch] Cloud Function via [SwitchboardService].
  Future<void> _startSearch() async {
    setState(() {
      _isSearching = true;
      _scanResult = null;
      _scanInProgress = false;
      _pdfPath = null;
      _errorMessage = null;
    });

    try {
      final result = await _switchboard.runScoutSearch(
        searchQuery: 'korrald_demo_identity',
      );

      setState(() {
        if (result == null) {
          // Cloud Function signalled that a vendor started an async scan.
          _scanInProgress = true;
        } else {
          _scanResult = result;
        }
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = 'Cloud Function error [${e.code}]: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
      });
    } finally {
      setState(() => _isSearching = false);
    }
  }

  /// Generates an on-device Evidence PDF from the current [_scanResult].
  Future<void> _generatePdf() async {
    if (_scanResult == null) return;

    setState(() {
      _isGeneratingPdf = true;
      _pdfPath = null;
      _errorMessage = null;
    });

    try {
      final path = await _pdfService.generateEvidencePdf(_scanResult!);
      setState(() => _pdfPath = path);
    } catch (e) {
      setState(() {
        _errorMessage = 'PDF generation failed: $e';
      });
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.background,
      appBar: AppBar(
        backgroundColor: _Palette.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'KORRALD',
          style: TextStyle(
            color: _Palette.amber,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.5,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _Palette.amber.withValues(alpha: 0.25)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchHeader(onSearch: _isSearching ? null : _startSearch),
            const SizedBox(height: 24),

            // Loading indicator during Cloud Function call
            if (_isSearching) _LoadingCard(message: 'Running Scout Search...'),

            // Match result card
            if (_scanResult != null) ...[
              _ResultCard(result: _scanResult!),
              const SizedBox(height: 16),

              // PDF generation button / loading
              if (_isGeneratingPdf)
                _LoadingCard(message: 'Generating PDF on-device...')
              else
                _PdfButton(onPressed: _generatePdf),
            ],

            // Async scan state
            if (_scanInProgress) const _AsyncScanCard(),

            // Error display
            if (_errorMessage != null) _ErrorCard(message: _errorMessage!),

            // PDF success — show local file path
            if (_pdfPath != null) _SuccessCard(filePath: _pdfPath!),
          ],
        ),
      ),
    );
  }
}

// ── Palette ───────────────────────────────────────────────────────────────────

/// App-wide colour constants for the Korrald dark theme.
class _Palette {
  static const background = Color(0xFF0F1923);
  static const surface = Color(0xFF1A2533);
  static const amber = Color(0xFFE8B84B);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF8899AA);
}

// ── Widgets ───────────────────────────────────────────────────────────────────

/// Header section with title, description, and the search trigger button.
class _SearchHeader extends StatelessWidget {
  final VoidCallback? onSearch;
  const _SearchHeader({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Scout Search',
          style: TextStyle(
            color: _Palette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Triggers the Firebase Cloud Function switchboard. Vendor routing, '
          '429 exponential backoff, and failover are handled server-side.',
          style: TextStyle(color: _Palette.textSecondary, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onSearch,
          icon: const Icon(Icons.search_rounded),
          label: const Text('Start Scout Search'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _Palette.amber,
            foregroundColor: Colors.black,
            disabledBackgroundColor: _Palette.amber.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

/// Spinner card shown while an async operation is running.
class _LoadingCard extends StatelessWidget {
  final String message;
  const _LoadingCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Palette.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: _Palette.amber,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            message,
            style: const TextStyle(color: _Palette.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Displays the scan result with confidence score, URL, and blurred thumbnail.
class _ResultCard extends StatelessWidget {
  final ScanResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final matchColor =
        result.matchFound ? const Color(0xFFEF5350) : const Color(0xFF66BB6A);
    final confidenceColor = result.confidence >= 90
        ? const Color(0xFFEF5350)
        : result.confidence >= 75
            ? const Color(0xFFFFA726)
            : const Color(0xFF66BB6A);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: matchColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Icon(
                result.matchFound
                    ? Icons.warning_rounded
                    : Icons.check_circle_rounded,
                color: matchColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                result.matchFound ? 'Match Found' : 'No Match Found',
                style: TextStyle(
                  color: matchColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Thumbnail + details row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Privacy-blurred thumbnail simulation
              // In production this would use an ImageFilter.blur on the real thumbnail.
              _BlurredThumbnail(),
              const SizedBox(width: 16),

              // Scan details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailItem(
                      label: 'Confidence',
                      value: '${result.confidence}%',
                      valueColor: confidenceColor,
                    ),
                    const SizedBox(height: 10),
                    _DetailItem(label: 'URL', value: result.url),
                    const SizedBox(height: 10),
                    _DetailItem(label: 'Vendor', value: result.vendorUsed),
                    const SizedBox(height: 10),
                    _DetailItem(
                      label: 'Scanned',
                      value: _shortDate(result.timestamp),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime dt) {
    final d = dt.toUtc();
    return '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)} UTC';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

/// Simulated privacy-blurred thumbnail placeholder.
///
/// In production, replace with [BackdropFilter] + [ImageFilter.blur] over
/// the actual vendor thumbnail image.
class _BlurredThumbnail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF253545),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.image_rounded, color: Colors.white12, size: 36),
        ),
        // Blur overlay (privacy simulation)
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.black.withValues(alpha: 0.55),
          ),
          child: const Center(
            child: Text('🔒', style: TextStyle(fontSize: 22)),
          ),
        ),
      ],
    );
  }
}

/// Label + value pair used inside [_ResultCard].
class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _Palette.textSecondary,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? _Palette.textPrimary,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }
}

/// Button to trigger on-device PDF generation.
class _PdfButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _PdfButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.picture_as_pdf_rounded),
      label: const Text('Generate Evidence PDF'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

/// Card shown when the Cloud Function returns `"Scan in progress"`.
class _AsyncScanCard extends StatelessWidget {
  const _AsyncScanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Scan in Progress',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'The vendor initiated an async scan. '
                  'You will be notified when results are ready.',
                  style: TextStyle(
                    color: _Palette.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Error card for Cloud Function or PDF failures.
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Success card shown after the PDF is saved locally.
class _SuccessCard extends StatelessWidget {
  final String filePath;
  const _SuccessCard({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14532D).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'PDF Ready',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (kIsWeb) ...
            const [
              Text(
                'Your browser download has started. Check your Downloads folder.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ]
          else ...
            [
              const Text(
                'Location',
                style: TextStyle(
                  color: _Palette.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                filePath,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          const SizedBox(height: 10),
          const Text(
            '⚠️  This file exists only on this device and is never '
            'uploaded to any server.',
            style: TextStyle(color: _Palette.textSecondary, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}
