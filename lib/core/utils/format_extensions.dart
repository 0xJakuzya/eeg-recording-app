// duration as hh:mm:ss string for recording display
extension DurationHmsFormatX on Duration {
  String toHms() {
    final hours = inHours.toString().padLeft(2, '0');
    final minutes = (inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

// duration as localized short format (e.g. "5м 30с")
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

// datetime format tokens: dd, MM, yyyy, HH, mm
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

// byte count as human-readable string (B, KB, MB, GB)
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

// double as hz suffix string for settings display
extension DoubleHzFormatX on double {
  String toHz({int fractionDigits = 1}) {
    return '${toStringAsFixed(fractionDigits)} Гц';
  }
}

// bytes per channel, display range, outputs volt flag for parser/chart
extension DataFormatX on DataFormat {
  int get bytesPerChannel {
    switch (this) {
      case DataFormat.int24Be:
        return 3;
    }
  }
  double get displayRange {
    switch (this) {
      case DataFormat.int24Be:
        return 1.2; // volts, ±Vref
    }
  }
  bool get outputsVolts => true;
}

// single format supported: int24 big-endian 8-channel
enum DataFormat {
  int24Be,
}
