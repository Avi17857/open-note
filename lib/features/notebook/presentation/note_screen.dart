import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/controllers/canvas_controller.dart';
import 'package:open_note/features/canvas/presentation/note_canvas.dart';
import 'package:open_note/features/canvas/presentation/painters/page_background_painter.dart';
import 'package:open_note/features/notebook/controllers/notebook_controller.dart';
import 'package:open_note/features/notebook/presentation/notebook_drawer.dart';

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
      listenable: _notebookController,
      builder: (context, _) {
        final totalPages = _notebookController.currentNote.pages.length;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: const Color(0xFFF3F3F5),
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            title: SizedBox(
              width: 220,
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
                onSubmitted: (val) => _notebookController.updateNoteTitle(val),
              ),
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
}
