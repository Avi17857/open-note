# Storage, Auto-Save & Cloud-Ready Architecture

## Overview
OpenNote implements a **Local-First, Auto-Saving Storage System** designed to safeguard user notes in real-time without perceptible latency, UI freezes, or data loss. The persistence architecture is tiered across platforms (Desktop/Mobile filesystem, Web local storage, in-memory testing fallback) and structured with conflict-resolution metadata for future account-based cloud synchronization.

---

## 1. Core Persistence Model (`NoteDocument`)

Every note document encapsulates vector inking strokes, rich text spans, and embedded media across one or more pages:

```dart
class NoteDocument {
  String id;                   // Globally unique UUID/id
  String title;                // Note title
  List<CanvasPage> pages;      // Multi-page vector strokes, text, and images
  DateTime createdAt;          // Document creation timestamp
  DateTime updatedAt;          // Last modified timestamp
  int version;                 // Monotonically increasing version counter
  bool isDeleted;              // Soft-delete tombstone for future sync
}
```

### Future Cloud Synchronization Preparation:
- **`version`:** Monotonically incremented on significant edits or server reconciliation to facilitate three-way merges or Last-Write-Wins (LWW) conflict resolution.
- **`isDeleted`:** Tombstone flag ensuring deletions propagate correctly across multiple offline devices without resurrecting deleted notes during synchronization.

---

## 2. Platform-Tiered Storage Service (`NoteStorageService`)

Persistence automatically selects the optimal platform target:

1. **Native (Windows, macOS, Linux, iOS, Android):**
   - Notes are stored in `<ApplicationDocumentsDirectory>/open_note/notes/<note_id>.opennote`.
   - Files are standard UTF-8 JSON payloads with `.opennote` extension.
   - On app launch, `loadAllNotes()` automatically scans the notes directory and indexes existing files into the user's library drawer.

2. **Web (`kIsWeb`):**
   - Notes are persisted in browser storage via `SharedPreferences`.
   - A registry key `opennote_web_catalog` maintains the index of saved note IDs.

3. **In-Memory Testing Fallback:**
   - When channel plugins (e.g. `path_provider`) are unavailable (such as in headless Flutter unit and widget tests), `NoteStorageService` automatically routes reads and writes to an internal memory map without throwing exceptions or requiring complex mocks.

4. **File Import & Export:**
   - **Export (`exportNoteToFile`):** Prompts the user to save an external `.opennote` bundle to their local filesystem (e.g. Documents, Desktop, USB drive).
   - **Import (`importNoteFromFile`):** Reads any selected `.opennote` or `.json` file, parses the document, registers it in the local storage directory, and adds it to the user's library.

---

## 3. Reactive Auto-Save & Debounce Engine

Auto-save is managed by `NotebookController` through a non-blocking debounced timer.

### Debounce Lifecycle:
```
User Inks / Types / Adds Page / Renames
            │
            ▼
    markContentChanged()
            │
            ▼
_scheduleAutoSave() [Cancels existing timer, starts 1200ms debounce]
            │
            ├─► SaveStatus = hasUnsavedChanges (AppBar shows amber "Unsaved changes")
            │
(1200ms of inactivity)
            │
            ▼
   _executeAutoSave()
            │
            ├─► SaveStatus = saving (AppBar shows rotating indicator "Saving...")
            ├─► _syncCurrentNote() (Clones active canvas pages and content)
            ├─► _storageService.saveNote(id, json)
            ▼
     SaveStatus = saved (AppBar shows green check "Saved")
```

### Flush Triggers (`flushAutoSave`):
Any action that risks changing document context or closing the note immediately flushes pending changes:
- Switching active notes (`setCurrentNote`)
- Creating a new note (`createNewNote`)
- Disposing controller (`dispose`)
- Exporting to PDF or external `.opennote` file

---

## 4. UI Indicators & User Experience

- **AppBar Save Status Indicator:**
  - **Saved:** Subtle green cloud/check icon with "Saved" caption.
  - **Saving...:** Animated spinning progress indicator with "Saving..." caption.
  - **Unsaved Changes:** Amber dot indicator indicating a debounce countdown is currently active.
- **Notebook Drawer:**
  - Quick action to create new notes or import `.opennote` files.
  - Note list showing title, page count, and humanized relative edit times (e.g., `Just now`, `5m ago`, `2h ago`).
  - Context menu for each note: **Rename**, **Duplicate**, **Export File**, and **Delete**.
