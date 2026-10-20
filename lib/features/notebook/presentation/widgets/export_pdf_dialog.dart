import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/presentation/painters/page_background_painter.dart';
import 'package:open_note/features/notebook/models/note_document.dart';
import 'package:open_note/features/storage/pdf_export_service.dart';

/// Modal dialog allowing users to configure PDF export settings:
/// - Inbound Page Bounds (1:1 standard page) vs Infinite Canvas (shrink to fit)
/// - Background template (ruled, grid, blank)
class ExportPdfDialog extends StatefulWidget {
  final NoteDocument document;
  final PageTemplate initialTemplate;

  const ExportPdfDialog({
    super.key,
    required this.document,
    this.initialTemplate = PageTemplate.ruled,
  });

  /// Displays the dialog and triggers PDF export upon confirmation.
  static Future<void> show(
    BuildContext context, {
    required NoteDocument document,
    PageTemplate initialTemplate = PageTemplate.ruled,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => ExportPdfDialog(
        document: document,
        initialTemplate: initialTemplate,
      ),
    );
  }

  @override
  State<ExportPdfDialog> createState() => _ExportPdfDialogState();
}

class _ExportPdfDialogState extends State<ExportPdfDialog> {
  late PdfExportMode _selectedMode;
  late PageTemplate _selectedTemplate;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = PdfExportMode.pageBounds;
    _selectedTemplate = widget.initialTemplate;
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    try {
      final success = await PdfExportService.exportPdf(
        document: widget.document,
        template: _selectedTemplate,
        mode: _selectedMode,
      );

      if (mounted) {
        Navigator.of(context).pop();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note exported to PDF successfully!'),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.document.pages.length;
    final title = widget.document.title.trim().isEmpty
        ? 'Untitled Note'
        : widget.document.title;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Note as PDF',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$title • $pageCount ${pageCount == 1 ? 'Page' : 'Pages'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Export Mode Title
              const Text(
                'Canvas Framing Mode',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),

              // Mode 1: Inbound Page Bounds
              _ModeSelectionTile(
                title: 'Inbound Page Bounds (1:1)',
                subtitle:
                    'Exports whatever is inside the note page bounds at full 1:1 scale.',
                icon: Icons.crop_portrait_rounded,
                isSelected: _selectedMode == PdfExportMode.pageBounds,
                onTap: () {
                  setState(() => _selectedMode = PdfExportMode.pageBounds);
                },
              ),

              const SizedBox(height: 6),

              // Mode 2: Infinite Canvas (Shrink to Fit)
              _ModeSelectionTile(
                title: 'Infinite Canvas (Shrink to Fit)',
                subtitle:
                    'Includes all canvas drawings and notes outside the page margins, scaled to fit.',
                icon: Icons.fit_screen_rounded,
                isSelected: _selectedMode == PdfExportMode.shrinkToFit,
                onTap: () {
                  setState(() => _selectedMode = PdfExportMode.shrinkToFit);
                },
              ),

              const SizedBox(height: 14),

              // Background Template
              const Text(
                'Page Background',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),

              SegmentedButton<PageTemplate>(
                segments: const [
                  ButtonSegment(
                    value: PageTemplate.ruled,
                    icon: Icon(Icons.format_line_spacing, size: 16),
                    label: Text('Ruled'),
                  ),
                  ButtonSegment(
                    value: PageTemplate.grid,
                    icon: Icon(Icons.grid_on, size: 16),
                    label: Text('Grid'),
                  ),
                  ButtonSegment(
                    value: PageTemplate.blank,
                    icon: Icon(Icons.crop_portrait, size: 16),
                    label: Text('Blank'),
                  ),
                ],
                selected: {_selectedTemplate},
                onSelectionChanged: (set) {
                  setState(() => _selectedTemplate = set.first);
                },
              ),

              const SizedBox(height: 12),

              // Light-Mode Guarantee Notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.print_outlined, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Light-Mode Guarantee: Exports on clean white paper with black ink for printing.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade900,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _isExporting ? null : _handleExport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.file_download_outlined, size: 20),
                    label: Text(_isExporting ? 'Exporting...' : 'Export PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSelectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeSelectionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.28);
    final bgColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.05)
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              onChanged: (_) => onTap(),
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
