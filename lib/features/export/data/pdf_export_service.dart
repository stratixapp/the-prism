// lib/features/export/data/pdf_export_service.dart
// Phase 17 — PDF Export Engine
//
// Generates a branded Stratix / The Prism PDF report from any
// completed AnalysisModel. Runs entirely on-device using the
// `pdf` package — no server round-trip needed.
//
// Layout:
//   Page 1  — Cover (Prism logo, file name, date, agent count, AI provider)
//   Page 2  — Executive Summary (Chen synthesis — purple highlight)
//   Pages 3+ — One page per agent output (colour-coded per agent)
//   Last    — Footer: "Powered by The Prism · Stratix"

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/models/analysis_model.dart';

// ── Brand Colors (PdfColor) ───────────────────────────────────────────────────
const _kPurple    = PdfColor.fromInt(0xFF7F77DD);
const _kPurpleDk  = PdfColor.fromInt(0xFF3C3489);
const _kPurpleBg  = PdfColor.fromInt(0xFFEEEDFE);
const _kDark      = PdfColor.fromInt(0xFF1A1A2E);
const _kMid       = PdfColor.fromInt(0xFF444441);
const _kLight     = PdfColor.fromInt(0xFFF8F7FF);
const _kBorder    = PdfColor.fromInt(0xFFD8D6F0);
const _kSuccess   = PdfColor.fromInt(0xFF1D9E75);
const _kAmber     = PdfColor.fromInt(0xFFBA7517);
const _kCoral     = PdfColor.fromInt(0xFFD85A30);
const _kBlue      = PdfColor.fromInt(0xFF378ADD);
const _kWhite     = PdfColors.white;

// Agent color map (agentId → PdfColor)
const _agentColors = <String, PdfColor>{
  'priya':  _kPurple,
  'marcus': PdfColor.fromInt(0xFF1D9E75),
  'zara':   PdfColor.fromInt(0xFFBA7517),
  'leon':   PdfColor.fromInt(0xFFD85A30),
  'aiko':   PdfColor.fromInt(0xFF378ADD),
  'sofia':  PdfColor.fromInt(0xFFD4537E),
  'ravi':   PdfColor.fromInt(0xFF639922),
  'vex':    PdfColor.fromInt(0xFFE24B4A),
  'morgan': PdfColor.fromInt(0xFF888780),
  'chen':   _kPurpleDk,
};

class PdfExportService {
  // ── Public API ──────────────────────────────────────────────────────────
  /// Generate PDF bytes from a completed analysis.
  Future<Uint8List> generateReport(AnalysisModel analysis) async {
    final doc = pw.Document(
      title: 'The Prism Report — ${analysis.fileMetadata.name}',
      author: 'The Prism by Stratix',
      creator: 'The Prism v${AppConstants.appVersion}',
    );

    final font       = await PdfGoogleFonts.interRegular();
    final fontBold   = await PdfGoogleFonts.interBold();
    final fontMedium = await PdfGoogleFonts.interMedium();

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
    );

    // ── Page 1: Cover ─────────────────────────────────────────────────
    doc.addPage(_buildCoverPage(analysis, theme, fontBold, fontMedium));

    // ── Page 2: Chen Synthesis ────────────────────────────────────────
    if (analysis.synthesis != null) {
      doc.addPage(
        _buildSynthesisPage(analysis, theme, fontBold, fontMedium));
    }

    // ── Pages 3+: Agent outputs ───────────────────────────────────────
    for (final output in analysis.agentOutputs) {
      if (output.content.trim().isEmpty) continue;
      // Skip Chen here — already on page 2
      if (output.agentId == AppConstants.agentChen) continue;

      doc.addPage(
        _buildAgentPage(output, analysis, theme, fontBold, fontMedium));
    }

    return doc.save();
  }

  /// Save PDF to temp directory and return the File.
  Future<File> saveToFile(AnalysisModel analysis) async {
    final bytes = await generateReport(analysis);
    final dir   = await getTemporaryDirectory();
    final safe  = analysis.fileMetadata.name
        .replaceAll(RegExp(r'[^\w\-.]'), '_');
    final path  = '${dir.path}/prism_report_$safe.pdf';
    final file  = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Share PDF via system share sheet.
  Future<void> shareReport(AnalysisModel analysis) async {
    final file = await saveToFile(analysis);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'The Prism Analysis — ${analysis.fileMetadata.name}',
    );
  }

  /// Open system print dialog.
  Future<void> printReport(AnalysisModel analysis) async {
    final bytes = await generateReport(analysis);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  // ── Cover Page ────────────────────────────────────────────────────────────
  pw.Page _buildCoverPage(
    AnalysisModel analysis,
    pw.ThemeData theme,
    pw.Font fontBold,
    pw.Font fontMedium,
  ) {
    final dateStr = DateFormat('MMMM d, yyyy').format(analysis.createdAt);

    return pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(0),
      ),
      build: (ctx) => pw.Stack(
        children: [
          // Dark background top half
          pw.Positioned(
            top: 0, left: 0, right: 0,
            child: pw.Container(
              height: PdfPageFormat.a4.height * 0.55,
              color: _kDark,
            ),
          ),

          // Light background bottom half
          pw.Positioned(
            bottom: 0, left: 0, right: 0,
            child: pw.Container(
              height: PdfPageFormat.a4.height * 0.45,
              color: _kLight,
            ),
          ),

          // Content
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 48, vertical: 40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Stratix badge
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: _kPurple,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'STRATIX',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 9,
                          color: _kWhite,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    pw.Text(
                      'CONFIDENTIAL',
                      style: pw.TextStyle(
                        font: fontMedium,
                        fontSize: 9,
                        color: PdfColor.fromInt(0xFF6E6C8A),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 48),

                // Prism triangle icon (drawn as polygon)
                pw.CustomPaint(
                  size: const PdfPoint(60, 52),
                  painter: (canvas, size) {
                    final path = PdfGraphics(canvas, size);
                    canvas
                      ..setFillColor(_kPurple)
                      ..moveTo(30, 0)
                      ..lineTo(60, 52)
                      ..lineTo(0, 52)
                      ..closePath()
                      ..fillPath();
                  },
                ),

                pw.SizedBox(height: 20),

                // Title
                pw.Text(
                  'THE PRISM',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 42,
                    color: _kWhite,
                    letterSpacing: 4,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Multi-Agent Deep Research Report',
                  style: pw.TextStyle(
                    font: fontMedium,
                    fontSize: 14,
                    color: _kPurple,
                  ),
                ),

                pw.SizedBox(height: 40),

                // Divider
                pw.Divider(color: PdfColor.fromInt(0xFF2A2840), thickness: 0.5),
                pw.SizedBox(height: 24),

                // File metadata
                _metaRow('File', analysis.fileMetadata.name,
                    fontBold, fontMedium),
                pw.SizedBox(height: 8),
                _metaRow('Size', analysis.fileMetadata.sizeLabel,
                    fontBold, fontMedium),
                pw.SizedBox(height: 8),
                _metaRow('Date', dateStr, fontBold, fontMedium),
                pw.SizedBox(height: 8),
                _metaRow('AI Engine',
                    _providerLabel(analysis.aiProvider),
                    fontBold, fontMedium),
                pw.SizedBox(height: 8),
                _metaRow('Agents',
                    '${analysis.agentOutputs.length} specialists activated',
                    fontBold, fontMedium),

                pw.SizedBox(height: 48),

                // Stats chips row
                pw.Row(
                  children: [
                    _statChip(
                        '${analysis.agentOutputs.length}',
                        'Agents', fontBold, fontMedium),
                    pw.SizedBox(width: 12),
                    _statChip(
                        analysis.totalTokensUsed > 0
                            ? _fmtNum(analysis.totalTokensUsed)
                            : '—',
                        'Tokens', fontBold, fontMedium),
                    pw.SizedBox(width: 12),
                    _statChip(
                        analysis.durationMs != null
                            ? '${(analysis.durationMs! / 1000).toStringAsFixed(1)}s'
                            : '—',
                        'Duration', fontBold, fontMedium),
                  ],
                ),

                pw.Spacer(),

                // Footer
                pw.Divider(
                    color: PdfColor.fromInt(0xFF2A2840), thickness: 0.5),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'The Prism by Stratix',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 9, color: _kPurple),
                    ),
                    pw.Text(
                      'theprism.app',
                      style: pw.TextStyle(
                          font: fontMedium,
                          fontSize: 9,
                          color: PdfColor.fromInt(0xFF6E6C8A)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chen Synthesis Page ────────────────────────────────────────────────────
  pw.Page _buildSynthesisPage(
    AnalysisModel analysis,
    pw.ThemeData theme,
    pw.Font fontBold,
    pw.Font fontMedium,
  ) {
    final synth = analysis.synthesis!;
    return pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 40),
      ),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _pageHeader('Executive Summary', fontBold, fontMedium,
              pageNum: ctx.pageNumber),
          pw.SizedBox(height: 20),

          // Chen card
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF130F2A),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(
                  color: _kPurpleDk, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(children: [
                  pw.Container(
                    width: 28,
                    height: 28,
                    decoration: pw.BoxDecoration(
                      color: _kPurpleDk,
                      borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(14)),
                    ),
                    child: pw.Center(
                      child: pw.Text('CH',
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 9,
                              color: _kWhite)),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Chen · Master Synthesizer',
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 11,
                                color: _kPurple)),
                        pw.Text('Final Verdict',
                            style: pw.TextStyle(
                                font: fontMedium,
                                fontSize: 9,
                                color: PdfColor.fromInt(0xFF6E6C8A))),
                      ]),
                ]),

                pw.SizedBox(height: 14),
                pw.Divider(
                    color: PdfColor.fromInt(0xFF2A2840), thickness: 0.5),
                pw.SizedBox(height: 14),

                // Three verdict sections
                _synthSection('#1 INSIGHT', synth.topInsight,
                    _kBlue, fontBold, fontMedium),
                if (synth.topGap.isNotEmpty) ...[
                  pw.SizedBox(height: 14),
                  _synthSection('#1 GAP', synth.topGap,
                      PdfColor.fromInt(0xFF1D9E75), fontBold, fontMedium),
                ],
                if (synth.topOpportunity.isNotEmpty) ...[
                  pw.SizedBox(height: 14),
                  _synthSection('#1 OPPORTUNITY', synth.topOpportunity,
                      _kAmber, fontBold, fontMedium),
                ],
              ],
            ),
          ),

          if (analysis.focusQuestion != null &&
              analysis.focusQuestion!.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF2F1FC),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: _kBorder, width: 0.5),
              ),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FOCUS QUESTION',
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 8,
                            color: PdfColor.fromInt(0xFF6E6C8A),
                            letterSpacing: 1)),
                    pw.SizedBox(height: 6),
                    pw.Text(analysis.focusQuestion!,
                        style: pw.TextStyle(
                            font: fontMedium,
                            fontSize: 11,
                            color: _kDark)),
                  ]),
            ),
          ],

          pw.Spacer(),
          _pageFooter(fontMedium),
        ],
      ),
    );
  }

  // ── Agent Output Page ──────────────────────────────────────────────────────
  pw.Page _buildAgentPage(
    AgentOutput output,
    AnalysisModel analysis,
    pw.ThemeData theme,
    pw.Font fontBold,
    pw.Font fontMedium,
  ) {
    AgentModel? agent;
    try {
      agent = AgentRegistry.get(output.agentId);
    } catch (_) {}

    final color = _agentColors[output.agentId] ?? _kPurple;
    final agentName = agent?.name ?? output.agentId;
    final agentRole = agent?.role ?? 'Specialist';

    return pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 40),
      ),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _pageHeader(
              '$agentName · $agentRole', fontBold, fontMedium,
              pageNum: ctx.pageNumber, accentColor: color),

          pw.SizedBox(height: 16),

          // Agent avatar + name bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: pw.BoxDecoration(
              color: _colorWithOpacity(color, 0.06),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
              border:
                  pw.Border.all(color: _colorWithOpacity(color, 0.3)),
            ),
            child: pw.Row(children: [
              pw.Container(
                width: 28,
                height: 28,
                decoration: pw.BoxDecoration(
                  color: _colorWithOpacity(color, 0.15),
                  borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(14)),
                  border: pw.Border.all(
                      color: _colorWithOpacity(color, 0.5),
                      width: 0.5),
                ),
                child: pw.Center(
                  child: pw.Text(
                    agent?.initials ?? output.agentId.substring(0, 2).toUpperCase(),
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 9, color: color),
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(agentName,
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 11, color: color)),
                    pw.Text(agentRole,
                        style: pw.TextStyle(
                            font: fontMedium,
                            fontSize: 9,
                            color: PdfColor.fromInt(0xFF6E6C8A))),
                  ]),
              if (output.tokensUsed != null &&
                  output.tokensUsed! > 0) ...[
                pw.Spacer(),
                pw.Text(
                  '${_fmtNum(output.tokensUsed!)} tokens',
                  style: pw.TextStyle(
                      font: fontMedium,
                      fontSize: 9,
                      color: PdfColor.fromInt(0xFF6E6C8A)),
                ),
              ],
            ]),
          ),

          pw.SizedBox(height: 16),

          // Content
          pw.Expanded(
            child: pw.Text(
              output.content,
              style: pw.TextStyle(
                font: fontMedium,
                fontSize: 10.5,
                color: _kMid,
                lineSpacing: 5,
              ),
            ),
          ),

          pw.SizedBox(height: 12),
          _pageFooter(fontMedium),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  pw.Widget _pageHeader(
    String title,
    pw.Font fontBold,
    pw.Font fontMedium, {
    required int pageNum,
    PdfColor? accentColor,
  }) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'THE PRISM · STRATIX',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 8,
                  color: _kPurple,
                  letterSpacing: 1.5,
                ),
              ),
              pw.Text(
                'Page $pageNum',
                style: pw.TextStyle(
                    font: fontMedium,
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFF6E6C8A)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(
              color: accentColor ?? _kPurple, thickness: 1.5),
          pw.SizedBox(height: 10),
          pw.Text(
            title,
            style: pw.TextStyle(
                font: fontBold,
                fontSize: 18,
                color: accentColor ?? _kDark),
          ),
        ]);
  }

  pw.Widget _pageFooter(pw.Font fontMedium) {
    return pw.Column(children: [
      pw.Divider(color: _kBorder, thickness: 0.5),
      pw.SizedBox(height: 6),
      pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'The Prism by Stratix · Refract your files into intelligence',
              style: pw.TextStyle(
                  font: fontMedium,
                  fontSize: 8,
                  color: PdfColor.fromInt(0xFF6E6C8A)),
            ),
            pw.Text(
              'theprism.app',
              style: pw.TextStyle(
                  font: fontMedium,
                  fontSize: 8,
                  color: _kPurple),
            ),
          ]),
    ]);
  }

  pw.Widget _metaRow(
      String label, String value, pw.Font fontBold, pw.Font fontMedium) {
    return pw.Row(children: [
      pw.SizedBox(
        width: 80,
        child: pw.Text(label,
            style: pw.TextStyle(
                font: fontBold,
                fontSize: 10,
                color: PdfColor.fromInt(0xFF6E6C8A))),
      ),
      pw.Text(value,
          style: pw.TextStyle(
              font: fontMedium, fontSize: 10, color: _kWhite)),
    ]);
  }

  pw.Widget _statChip(
      String value, String label, pw.Font fontBold, pw.Font fontMedium) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _kPurpleBg,
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(children: [
        pw.Text(value,
            style: pw.TextStyle(
                font: fontBold, fontSize: 16, color: _kPurpleDk)),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style: pw.TextStyle(
                font: fontMedium,
                fontSize: 9,
                color: PdfColor.fromInt(0xFF6E6C8A))),
      ]),
    );
  }

  pw.Widget _synthSection(
    String label,
    String text,
    PdfColor color,
    pw.Font fontBold,
    pw.Font fontMedium,
  ) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: color,
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 5),
          pw.Text(text,
              style: pw.TextStyle(
                font: fontMedium,
                fontSize: 11,
                color: PdfColor.fromInt(0xFFD0CFEE),
                lineSpacing: 4,
              )),
        ]);
  }

  // Blend a PdfColor with white to simulate opacity
  PdfColor _colorWithOpacity(PdfColor color, double opacity) {
    return PdfColor(
      color.red * opacity + 1.0 * (1 - opacity),
      color.green * opacity + 1.0 * (1 - opacity),
      color.blue * opacity + 1.0 * (1 - opacity),
    );
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case AppConstants.aiProviderClaude:
        return 'Claude (Anthropic)';
      case AppConstants.aiProviderOpenAI:
        return 'GPT-4o (OpenAI)';
      case AppConstants.aiProviderBoth:
        return 'Claude + GPT-4o';
      default:
        return provider;
    }
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// Note: pw.CustomPaint painter receives a PdfGraphics canvas from the pdf package.
// No stub needed — the pdf package provides PdfGraphics natively.
