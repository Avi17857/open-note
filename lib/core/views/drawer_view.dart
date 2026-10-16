import 'package:flutter/material.dart';
import 'package:open_note/core/models/note_model.dart';
import 'package:open_note/core/viewModels/drawer_viewModel.dart';
import 'package:open_note/core/viewModels/note_viewModel.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key, required this.notes});

  final List<NoteModel> notes;

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: 100,
              child: DrawerHeader(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 196, 20, 231),
                ),
                child: const Text(
                  'OpenNote',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            InkWell(
              onTap:
                  () => Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (Route<dynamic> route) => false,
                  ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 3.0, horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.house),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 3)),
                    Text(
                      "Home Page",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(thickness: 2, height: 20),
            InkWell(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NotePage()),
                  ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.add),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 3)),
                    Text(
                      "New Note",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(thickness: 2, height: 20),
            for (var note in widget.notes)
              ListTile(
                title: Text(note.title),
                style: ListTileStyle.drawer,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NotePage()),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
