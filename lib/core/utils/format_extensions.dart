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
      return '$hoursч $minutesм $secondsс';
    } else if (minutes > 0) {
      return '$minutesм $secondsс';
    } else {
      return '$secondsс';
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
<<<<<<< HEAD:lib/utils/extension.dart
      case DataFormat.eeg24BitVolt:
=======
      case DataFormat.uint12Le:
        return 2;
      case DataFormat.int24Be:
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/core/utils/format_extensions.dart
        return 3;
    }
  }
  double get displayRange {
    switch (this) {
      case DataFormat.int8:
        return 128.0;
<<<<<<< HEAD:lib/utils/extension.dart
      case DataFormat.eeg24BitVolt:
        return 128.0; // график всегда использует масштаб int8
=======
      case DataFormat.uint12Le:
        return 4095.0;
      case DataFormat.int24Be:
        return 1.2; // volts, ±Vref
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/core/utils/format_extensions.dart
    }
  }
  bool get outputsVolts => this == DataFormat.int24Be;
}

enum DataFormat {
  int8,
<<<<<<< HEAD:lib/utils/extension.dart
  eeg24BitVolt,
}
=======
  uint12Le,
  int24Be,
}
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/core/utils/format_extensions.dart
