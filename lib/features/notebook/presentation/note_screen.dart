import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/presentation/note_canvas.dart';
import 'package:open_note/features/canvas/presentation/painters/page_background_painter.dart';
import 'package:open_note/features/notebook/controllers/notebook_controller.dart';
import 'package:open_note/features/notebook/presentation/notebook_drawer.dart';
import 'package:open_note/features/notebook/presentation/widgets/export_pdf_dialog.dart';

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  late final CanvasController _canvasController;
  late final NotebookController _notebookController;
  PageTemplate _pageTemplate = PageTemplate.ruled;
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _canvasController = CanvasController();
    _notebookController =
        NotebookController(canvasController: _canvasController);
    _titleController =
        TextEditingController(text: _notebookController.currentNote.title);

    _notebookController.addListener(_onNotebookChanged);
  }

  void _onNotebookChanged() {
    if (_titleController.text != _notebookController.currentNote.title) {
      _titleController.text = _notebookController.currentNote.title;
    }
  }

  @override
  void dispose() {
    _notebookController.removeListener(_onNotebookChanged);
    _titleController.dispose();
    _notebookController.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_notebookController, _canvasController]),
      builder: (context, _) {
        final totalPages = _notebookController.currentNote.pages.length;
        final isDark = _canvasController.isDarkMode;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: isDark
              ? AppColors.pasteboardBackgroundDark
              : const Color(0xFFF3F3F5),
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Note Title',
                      hintStyle: TextStyle(color: Colors.white70),
                    ),
                    onChanged: (val) => _notebookController.updateNoteTitle(val),
                    onSubmitted: (val) => _notebookController.updateNoteTitle(val),
                  ),
                ),
                const SizedBox(width: 8),
                _buildSaveStatusIndicator(_notebookController.saveStatus),
              ],
            ),
            actions: [
              // Page Count badge & Add Page button
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$totalPages ${totalPages == 1 ? 'Page' : 'Pages'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_box_outlined, color: Colors.white),
                tooltip: 'Add Page',
                onPressed: _notebookController.addPage,
              ),

              // Page Template Picker (Blank, Ruled, Grid)
              PopupMenuButton<PageTemplate>(
                icon: const Icon(Icons.layers_outlined, color: Colors.white),
                tooltip: 'Page Template',
                initialValue: _pageTemplate,
                onSelected: (template) {
                  setState(() => _pageTemplate = template);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: PageTemplate.ruled,
                    child: Row(
                      children: [
                        Icon(Icons.format_line_spacing),
                        SizedBox(width: 8),
                        Text('Ruled Paper'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: PageTemplate.grid,
                    child: Row(
                      children: [
                        Icon(Icons.grid_on),
                        SizedBox(width: 8),
                        Text('Grid Paper'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: PageTemplate.blank,
                    child: Row(
                      children: [
                        Icon(Icons.crop_portrait),
                        SizedBox(width: 8),
                        Text('Blank Paper'),
                      ],
                    ),
                  ),
                ],
              ),

              // Dark Mode Toggle
              IconButton(
                icon: Icon(
                  _canvasController.isDarkMode
                      ? Icons.dark_mode
                      : Icons.light_mode_outlined,
                  color: Colors.white,
                ),
                tooltip: _canvasController.isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
                onPressed: _canvasController.toggleDarkMode,
              ),

              // Export Note as PDF
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
                tooltip: 'Export as PDF',
                onPressed: () {
                  _notebookController.syncCurrentNote();
                  ExportPdfDialog.show(
                    context,
                    document: _notebookController.currentNote,
                    initialTemplate: _pageTemplate,
                  );
                },
              ),

              // Save Note
              IconButton(
                icon: const Icon(Icons.save_outlined, color: Colors.white),
                tooltip: 'Save Note',
                onPressed: () async {
                  await _notebookController.saveCurrentNote();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note saved successfully!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          drawer: NotebookDrawer(controller: _notebookController),
          body: NoteCanvas(
            controller: _canvasController,
            template: _pageTemplate,
          ),
        );
      },
    );
  }

  Widget _buildSaveStatusIndicator(SaveStatus status) {
    return switch (status) {
      SaveStatus.saving => Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
            SizedBox(width: 5),
            Text(
              'Saving...',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      SaveStatus.saved => Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.cloud_done_outlined, size: 14, color: Colors.white70),
            SizedBox(width: 4),
            Text(
              'Saved',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      SaveStatus.hasUnsavedChanges => Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.edit_note, size: 14, color: Colors.white70),
            SizedBox(width: 4),
            Text(
              'Unsaved',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
    };
  }
}
