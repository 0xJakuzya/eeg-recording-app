// Largest Triangle Three Buckets downsampling for time series data.
// Preserves the visual shape of the signal better than uniform sampling.
// threshold: desired number of output points (clamped to data.length if smaller).
// getX / getY: accessors for the time and value dimensions of each element.
List<T> lttbDownsample<T>({
  required List<T> data,
  required int threshold,
  required double Function(T) getX,
  required double Function(T) getY,
}) {
  final n = data.length;
  if (n <= threshold || threshold < 3) return List.of(data);

  final result = <T>[];
  result.add(data.first);

  final bucketSize = (n - 2) / (threshold - 2);
  int selected = 0;

  for (int bucket = 0; bucket < threshold - 2; bucket++) {
    // Compute the average point of the next bucket (used as the far vertex).
    final nextStart = ((bucket + 1) * bucketSize + 1).floor();
    final nextEnd = ((bucket + 2) * bucketSize + 1).floor().clamp(0, n);
    final nextCount = nextEnd - nextStart;
    double avgX = 0;
    double avgY = 0;
    for (int j = nextStart; j < nextEnd; j++) {
      avgX += getX(data[j]);
      avgY += getY(data[j]);
    }
    avgX /= nextCount;
    avgY /= nextCount;

    // Within the current bucket find the point that forms the largest triangle
    // with the already-selected point and the next-bucket average.
    final rangeStart = (bucket * bucketSize + 1).floor();
    final rangeEnd = ((bucket + 1) * bucketSize + 1).floor().clamp(0, n);
    final ax = getX(data[selected]);
    final ay = getY(data[selected]);

    double maxArea = -1;
    int maxIdx = rangeStart;
    for (int j = rangeStart; j < rangeEnd; j++) {
      final area =
          ((ax - avgX) * (getY(data[j]) - ay) - (ax - getX(data[j])) * (avgY - ay)).abs() *
              0.5;
      if (area > maxArea) {
        maxArea = area;
        maxIdx = j;
      }
    }

    result.add(data[maxIdx]);
    selected = maxIdx;
  }

  result.add(data.last);
  return result;
}
