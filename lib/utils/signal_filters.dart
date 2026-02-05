import 'dart:math' as math;

// Simple real-time bandpass filter for visualization
// first-order high-pass + first-order low-pass in cascade.
class BandpassFilter1D {

  final double fs; // sampling frequency (Hz)
  final double lowCut; // high-pass cutoff (Hz)
  final double highCut; // low-pass cutoff (Hz)

  late final double dt; // time step
  late final double alphaHp; // high-pass alpha
  late final double alphaLp; // low-pass alpha

  double hpPrevY = 0.0; // high-pass previous y
  double hpPrevX = 0.0; // high-pass previous x
  double lpPrevY = 0.0; // low-pass previous y

  BandpassFilter1D({
    required this.fs,
    required this.lowCut,
    required this.highCut,
  }) {
    dt = 1.0 / fs;
    alphaHp = computeAlpha(lowCut);
    alphaLp = computeAlpha(highCut);
  }

  // compute alpha
  double computeAlpha(double cutoff) {
    final rc = 1.0 / (2 * math.pi * cutoff);
    return dt / (rc + dt);
  }

  // process single sample and return filtered value
  double process(double x) {
    // high-pass stage
      final hpY = alphaHp * (hpPrevY + x - hpPrevX);
    hpPrevY = hpY;
    hpPrevX = x;

    // low-pass stage on high-passed signal
    final lpY = lpPrevY + alphaLp * (hpY - lpPrevY);
    lpPrevY = lpY;

    return lpY;
  }

  // reset internal state
  void reset() {
    hpPrevY = 0.0;
    hpPrevX = 0.0;
    lpPrevY = 0.0;
  }
}

