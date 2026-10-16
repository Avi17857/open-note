import 'package:flutter/material.dart';
import 'package:open_note/core/theme/app_colors.dart';
import 'package:open_note/features/notebook/controllers/notebook_controller.dart';

class NotebookDrawer extends StatelessWidget {
  final NotebookController controller;

  const NotebookDrawer({super.key, required this.controller});

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
                        'Notebooks & Sections',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              // New Note Button
              ListTile(
                leading: const Icon(Icons.note_add_outlined, color: AppColors.primary),
                title: const Text(
                  'New Note',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  controller.createNewNote();
                  Navigator.pop(context);
                },
              ),

              const Divider(height: 1),

              // Notebook / Notes List
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: controller.notes.length,
                  itemBuilder: (context, index) {
                    final note = controller.notes[index];
                    final isSelected = note.id == controller.currentNote.id;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                      leading: Icon(
                        isSelected ? Icons.description : Icons.description_outlined,
                        color: isSelected ? AppColors.primary : Colors.grey.shade600,
                      ),
                      title: Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        '${note.pages.length} page${note.pages.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
