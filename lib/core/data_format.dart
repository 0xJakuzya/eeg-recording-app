enum DataFormat {
  int8,
  uint12Le,
}
extension DataFormatX on DataFormat {
  int get bytesPerChannel {
    switch (this) {
      case DataFormat.int8:
        return 1;
      case DataFormat.uint12Le:
        return 2;
    }
  }
  double get displayRange {
    switch (this) {
      case DataFormat.int8:
        return 128.0; 
      case DataFormat.uint12Le:
        return 4095.0; 
    }
  }
}

