import 'dart:math' as math;

// simple 50 hz notch filter for polysomnography model; two-sample average
// kept for backward compatibility; prefer EegDisplayFilter for chart/CSV
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

/// Pure-Dart EEG filter chain: DC removal, lowpass ~40 Hz, notch 50 Hz.
/// No native dependencies - avoids crashes on some Android devices.
class EegDisplayFilter {
  final int samplingFreqHz;
  bool _disposed = false;

  // DC removal (highpass ~1 Hz): y = x - dc_est; dc_est = alpha*dc_est + (1-alpha)*x
  double _dcEst = 0.0;
  bool _dcInitialized = false;
  static const double _dcAlpha = 0.995; // ~1 Hz at 100 Hz

  // Lowpass ~40 Hz: simple IIR y = alpha*y_prev + (1-alpha)*x
  double _lpPrev = 0.0;
  bool _lpHasPrev = false;
  double _lpAlpha = 0.0;

  // Notch 50 Hz at 100 Hz: y[n] = (x[n] + x[n-2])/2 - null at 50 Hz (2 samples/cycle)
  double _nPrev1 = 0.0;
  double _nPrev2 = 0.0;
  int _nCount = 0;

  EegDisplayFilter({this.samplingFreqHz = 100}) {
    // LPF ~40 Hz: alpha = exp(-2*pi*fc/fs)
    final fc = 40.0;
    _lpAlpha = math.exp(-2 * math.pi * fc / samplingFreqHz);
  }

  double process(double x) {
    if (_disposed) return x;

    // 1. DC removal (highpass) — инициализируем первым сэмплом, чтобы избежать резкого скачка
    if (!_dcInitialized) {
      _dcEst = x;
      _dcInitialized = true;
    } else {
      _dcEst = _dcAlpha * _dcEst + (1 - _dcAlpha) * x;
    }
    double v = x - _dcEst;

    // 2. Lowpass ~40 Hz
    if (!_lpHasPrev) {
      _lpHasPrev = true;
      _lpPrev = v;
    } else {
      v = _lpAlpha * _lpPrev + (1 - _lpAlpha) * v;
      _lpPrev = v;
    }

    // 3. Notch 50 Hz (at 100 Hz: 2 samples per cycle)
    if (_nCount < 2) {
      _nPrev2 = _nPrev1;
      _nPrev1 = v;
      _nCount++;
      return v;
    }
    final out = (v + _nPrev2) * 0.5;
    _nPrev2 = _nPrev1;
    _nPrev1 = v;
    return out;
  }

  void reset() {
    if (_disposed) return;
    _dcEst = 0.0;
    _dcInitialized = false;
    _lpPrev = 0.0;
    _lpHasPrev = false;
    _nPrev1 = 0.0;
    _nPrev2 = 0.0;
    _nCount = 0;
  }

  void dispose() {
    _disposed = true;
  }
}
