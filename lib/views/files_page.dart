import 'package:flutter/material.dart';

class FilesPage extends StatelessWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Файлы записи'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        itemCount: 5, 
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
              title: Text('Запись ${index + 1}'),
              subtitle: Text('Дата: ${DateTime.now().toString().substring(0, 16)}'),
              trailing: IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                    // ...
                },
              ),
              onTap: () {
                // TODO: open details files
              },
            ),
          );
        },
      ),
    );
  }
}