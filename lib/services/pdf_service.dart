import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/scan_result.dart';

/// Generates Evidence PDF dossiers entirely on-device.
///
/// SECURITY NOTE:
///   PDFs are saved to the app's private documents directory and are
///   NEVER transmitted to any server. Per the Korrald spec:
///   "Generated PDF dossiers — local storage only. Never uploaded."
///   Users must export/share the file before switching devices.
class PdfService {
  /// Generates an Evidence PDF for [result] and writes it to local storage.
  ///
  /// Returns the absolute file path of the saved PDF.
  ///
  /// The PDF includes a SHA-256 document fingerprint computed from the
  /// result's key fields — any post-generation modification will invalidate
  /// this fingerprint.
  Future<String> generateEvidencePdf(ScanResult result) async {
    // ── 1. Compute SHA-256 fingerprint ──────────────────────────────────────
    // Fingerprint binds the document to its core facts. If any field changes
    // after generation, the hash will not match and the document is invalidated.
    final fingerprintSource =
        '${result.url}|${result.confidence}|'
        '${result.timestamp.toIso8601String()}|${result.vendorUsed}';
    final fingerprint =
        sha256.convert(utf8.encode(fingerprintSource)).toString();

    // ── 2. Load Unicode-capable fonts (Roboto via Google Fonts) ─────────────
    // The default Helvetica has no Unicode support. Roboto covers full Latin
    // and common Unicode ranges needed for evidence content.
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    // ── 3. Build PDF document ────────────────────────────────────────────────
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        build: (pw.Context context) => [
          // ── Header ──────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 14),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.amber700, width: 2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'KORRALD',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.Text(
                      'Evidence Dossier',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.blueGrey600,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'CONFIDENTIAL',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.red700,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 28),

          // ── Case Summary ─────────────────────────────────────────────────
          _sectionHeader('Case Summary'),
          pw.SizedBox(height: 10),
          _detailRow('Status', result.matchFound ? 'Match Confirmed' : 'No Match Found'),
          _detailRow('Confidence Score', '${result.confidence}%'),
          _detailRow('Matched URL', result.url),
          _detailRow('Vendor Used', result.vendorUsed),
          _detailRow('Generated', _formatUtc(result.timestamp)),

          pw.SizedBox(height: 28),

          // ── Document Integrity ───────────────────────────────────────────
          _sectionHeader('Document Integrity'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SHA-256 Document Fingerprint',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey700,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  fingerprint,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Any modification to this document will invalidate the fingerprint above. '
            'A new dossier must be generated if changes are required.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red700),
          ),

          pw.SizedBox(height: 28),

          // ── Legal Disclaimer ─────────────────────────────────────────────
          _sectionHeader('Disclaimer'),
          pw.SizedBox(height: 10),
          pw.Text(
            'This document was generated by the Korrald application as a preliminary '
            'evidence dossier. It is intended solely to assist users in documenting '
            'potential unauthorized use of their likeness or personal identity. This '
            'document does not constitute legal advice. Users are strongly advised to '
            'consult qualified legal counsel before taking any enforcement action. '
            'Korrald and Bar 6 LLC accept no liability for actions taken based solely '
            'on this document.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
          ),

          pw.SizedBox(height: 28),

          // ── Footer ───────────────────────────────────────────────────────
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
              ),
            ),
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Korrald · Bar 6 LLC · Evaluation Build',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Generated: ${_formatUtc(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // ── 4. Save / deliver the PDF ─────────────────────────────────────────────
    final fileName =
        'korrald_evidence_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await doc.save();

    if (kIsWeb) {
      // On web there is no local filesystem. Trigger a browser download instead.
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return fileName; // Return the filename as a logical identifier.
    }

    // Native (Android / iOS / desktop): write to the app-private documents dir.
    // Other apps cannot access this path without explicit user sharing.
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Renders a bold section heading with letter-spacing.
  pw.Widget _sectionHeader(String title) => pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey900,
          letterSpacing: 1.5,
        ),
      );

  /// Renders a label + value row used in the case summary table.
  pw.Widget _detailRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 130,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.blueGrey900,
                ),
              ),
            ),
          ],
        ),
      );

  /// Formats a [DateTime] as a human-readable UTC string.
  String _formatUtc(DateTime dt) {
    final d = dt.toUtc();
    return '${d.year}-${_pad(d.month)}-${_pad(d.day)} '
        '${_pad(d.hour)}:${_pad(d.minute)} UTC';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
