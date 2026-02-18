import 'package:flutter/material.dart';
import 'package:ble_app/core/app_theme.dart';

class FilesSelectionBar extends StatelessWidget {
  const FilesSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalItems,
    required this.allSelected,
    required this.hasSelectedFiles,
    required this.onToggleSelectAll,
    this.onUploadSelected,
    this.onShareSelected,
    required this.onDeleteSelected,
  });

  final int selectedCount;
  final int totalItems;
  final bool allSelected;
  final bool hasSelectedFiles;

  final VoidCallback onToggleSelectAll;
  final VoidCallback? onUploadSelected;
  final VoidCallback? onShareSelected;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.backgroundSurface,
          border: const Border(
            top: BorderSide(color: AppTheme.borderSubtle),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              'Выбрано: $selectedCount',
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: totalItems == 0 ? null : onToggleSelectAll,
              icon: Icon(
                allSelected ? Icons.deselect : Icons.select_all,
                color: AppTheme.accentSecondary,
              ),
              label: Text(
                allSelected ? 'Снять все' : 'Выбрать все',
                style: const TextStyle(color: AppTheme.accentSecondary),
              ),
            ),
            if (onShareSelected != null) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: hasSelectedFiles ? onShareSelected : null,
                icon: const Icon(Icons.share),
                label: const Text('Поделиться'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentSecondary,
                  foregroundColor: AppTheme.textPrimary,
                ),
              ),
            ],
            if (onUploadSelected != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Отправить',
                child: IconButton.filled(
                  onPressed: hasSelectedFiles ? onUploadSelected : null,
                  icon: const Icon(Icons.cloud_upload),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.accentPrimary,
                    foregroundColor: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Tooltip(
              message: 'Удалить',
              child: IconButton.filled(
                onPressed: selectedCount == 0 ? null : onDeleteSelected,
                icon: const Icon(Icons.delete),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.statusFailed,
                  foregroundColor: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

