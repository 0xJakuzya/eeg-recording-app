// simple 50 hz notch filter for polysomnography model; two-sample average
class Notch50HzFilter {
  double prevInput = 0.0;
  bool hasPrev = false;
  double process(double x) {
    if (!hasPrev) {
      hasPrev = true;
      prevInput = x;
      return x;
    }
    final y = 0.5 * x + 0.5 * prevInput;
    prevInput = x;
    return y;
  }
  void reset() {
    prevInput = 0.0;
    hasPrev = false;
  }
}

// batch apply notch filter to list; returns new list
List<double> applyNotch50Hz(List<double> samples) {
  final filter = Notch50HzFilter();
  return samples.map(filter.process).toList();
}
