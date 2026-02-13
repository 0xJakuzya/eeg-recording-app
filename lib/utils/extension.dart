extension DurationHmsFormatX on Duration {
  String toHms() {
    final hours = inHours.toString().padLeft(2, '0');
    final minutes = (inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

extension DurationExtension on Duration {
  String format() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}ч ${minutes}м ${seconds}с';
    } else if (minutes > 0) {
      return '${minutes}м ${seconds}с';
    } else {
      return '${seconds}с';
    }
  }
}

extension DateTimeExtension on DateTime {
  String format([String format = 'dd.MM.yyyy HH:mm']) {
    final dayStr = day.toString().padLeft(2, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final yearStr = year.toString();
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = minute.toString().padLeft(2, '0');
    return format
        .replaceAll('dd', dayStr)
        .replaceAll('MM', monthStr)
        .replaceAll('yyyy', yearStr)
        .replaceAll('HH', hourStr)
        .replaceAll('mm', minuteStr);
  }
}

extension IntExtension on int {
  String formatBytes() {
    if (this < 1024) {
      return '$this B';
    } else if (this < 1024 * 1024) {
      return '${(this / 1024).toStringAsFixed(1)} KB';
    } else if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

extension DoubleHzFormatX on double {
  String toHz({int fractionDigits = 1}) {
    return '${toStringAsFixed(fractionDigits)} Гц';
  }
}

extension DataFormatX on DataFormat {
  int get bytesPerChannel {
    switch (this) {
      case DataFormat.int8:
        return 1;
      case DataFormat.eeg24BitVolt:
        return 3;
    }
  }
  double get displayRange {
    switch (this) {
      case DataFormat.int8:
        return 128.0;
      case DataFormat.eeg24BitVolt:
        return 128.0; // график всегда использует масштаб int8
    }
  }
}
enum DataFormat {
  int8,
  eeg24BitVolt,
}