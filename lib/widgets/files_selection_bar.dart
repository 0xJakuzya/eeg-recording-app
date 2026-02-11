import 'package:flutter/material.dart';

class FilesSelectionBar extends StatelessWidget {
  const FilesSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalItems,
    required this.allSelected,
    required this.hasSelectedFiles,
    required this.onToggleSelectAll,
    required this.onUploadSelected,
    required this.onDeleteSelected,
  });

  final int selectedCount;
  final int totalItems;
  final bool allSelected;
  final bool hasSelectedFiles;

  final VoidCallback onToggleSelectAll;
  final VoidCallback? onUploadSelected;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text('Выбрано: $selectedCount'),
            const Spacer(),
            TextButton.icon(
              onPressed: totalItems == 0 ? null : onToggleSelectAll,
              icon: Icon(
                allSelected ? Icons.deselect : Icons.select_all,
              ),
              label: Text(allSelected ? 'Снять все' : 'Выбрать все'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: hasSelectedFiles ? onUploadSelected : null,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Отправить'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: selectedCount == 0 ? null : onDeleteSelected,
              icon: const Icon(Icons.delete),
              label: const Text('Удалить'),
            ),
          ],
        ),
      ),
    );
  }
}

