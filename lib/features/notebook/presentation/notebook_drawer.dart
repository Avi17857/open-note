import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/canvas/models/canvas_mode.dart';
import 'package:open_note/features/notebook/controllers/notebook_controller.dart';
import 'package:open_note/features/notebook/models/note_document.dart';

class NotebookDrawer extends StatelessWidget {
  final NotebookController controller;

  const NotebookDrawer({super.key, required this.controller});

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  void _showRenameDialog(BuildContext context, NoteDocument note) {
    final textController = TextEditingController(text: note.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Note'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Note Title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final trimmed = val.trim();
            if (trimmed.isNotEmpty) {
              controller.renameNote(note.id, trimmed);
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = textController.text.trim();
              if (trimmed.isNotEmpty) {
                controller.renameNote(note.id, trimmed);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, NoteDocument note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text(
          'Are you sure you want to delete "${note.title.isEmpty ? 'Untitled Note' : note.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              controller.deleteNote(note.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Drawer(
          child: Column(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      Icon(Icons.auto_stories, color: Colors.white, size: 36),
                      SizedBox(height: 8),
                      Text(
                        'OpenNote',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Saved Notes & Storage',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons: New Note & Import File
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: PopupMenuButton<CanvasMode>(
                        tooltip: 'Create New Note',
                        offset: const Offset(0, 44),
                        onSelected: (mode) {
                          controller.createNewNote(
                            title: mode.isInfinite
                                ? 'Infinite Canvas Note'
                                : 'New Note',
                            canvasMode: mode,
                          );
                          Navigator.pop(context);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: CanvasMode.paged,
                            child: Row(
                              children: [
                                Icon(Icons.description_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('Standard Paged Note'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: CanvasMode.infinite,
                            child: Row(
                              children: [
                                Icon(Icons.all_out_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Infinite Canvas Note'),
                              ],
                            ),
                          ),
                        ],
                        child: IgnorePointer(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('New Note'),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, size: 18),
                              ],
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Open / Import Note File',
                      icon: const Icon(Icons.file_open_outlined, size: 20),
                      onPressed: () async {
                        Navigator.pop(context);
                        final imported = await controller.importNoteFromFile();
                        if (context.mounted && imported) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Note imported successfully!'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Notes List
              Expanded(
                child: controller.notes.isEmpty
                    ? Center(
                        child: Text(
                          'No saved notes yet',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: controller.notes.length,
                        itemBuilder: (context, index) {
                          final note = controller.notes[index];
                          final isSelected = note.id == controller.currentNote.id;

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            leading: Icon(
                              note.canvasMode.isInfinite
                                  ? Icons.all_out_rounded
                                  : (isSelected
                                      ? Icons.description
                                      : Icons.description_outlined),
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                            ),
                            title: Text(
                              note.title.isEmpty ? 'Untitled Note' : note.title,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${note.canvasMode.isInfinite ? '∞ Infinite' : '${note.pages.length} page${note.pages.length == 1 ? '' : 's'}'} • ${_formatRelativeTime(note.updatedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              tooltip: 'Note Options',
                              onSelected: (action) async {
                                switch (action) {
                                  case 'rename':
                                    _showRenameDialog(context, note);
                                    break;
                                  case 'duplicate':
                                    await controller.duplicateNote(note);
                                    break;
                                  case 'export':
                                    final path =
                                        await controller.exportNoteToFile(note);
                                    if (context.mounted && path != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Exported to $path'),
                                          backgroundColor: AppColors.primary,
                                        ),
                                      );
                                    }
                                    break;
                                  case 'delete':
                                    _showDeleteDialog(context, note);
                                    break;
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Rename'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'duplicate',
                                  child: Row(
                                    children: [
                                      Icon(Icons.copy_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Duplicate'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'export',
                                  child: Row(
                                    children: [
                                      Icon(Icons.file_download_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Export Note File (.opennote)'),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: Colors.red, size: 18),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              controller.setCurrentNote(note);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
