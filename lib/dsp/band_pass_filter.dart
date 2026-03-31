class BandPassFilter {
  final double lowCutoff; // 0.8 Hz (~48 BPM)
  final double highCutoff; // 3.0 Hz (~180 BPM)

  BandPassFilter({this.lowCutoff = 0.8, this.highCutoff = 3.0});

  List<double> process(List<double> input, double sampleRate) {
    if (input.isEmpty || sampleRate <= 0) return [];

    final double dt = 1.0 / sampleRate;

    // --- High-Pass Filter ---
    // Removes DC offset (gravity) and slow breathing waves.
    final double rcHigh = 1.0 / (2 * 3.14159265359 * lowCutoff);
    final double alphaHigh = rcHigh / (rcHigh + dt);

    List<double> highPassed = List.filled(input.length, 0.0);
    highPassed[0] = input[0]; // Initialize first value

    for (int i = 1; i < input.length; i++) {
      // High-pass formula: $y[i] = \alpha \times (y[i-1] + x[i] - x[i-1])$
      highPassed[i] = alphaHigh * (highPassed[i - 1] + input[i] - input[i - 1]);
    }

    // --- Low-Pass Filter ---
    // Takes the high-passed data and removes high-frequency jitter.
    final double rcLow = 1.0 / (2 * 3.14159265359 * highCutoff);
    final double alphaLow = dt / (rcLow + dt);

    List<double> bandPassed = List.filled(input.length, 0.0);
    bandPassed[0] = highPassed[0]; // Initialize first value

    for (int i = 1; i < highPassed.length; i++) {
      // Low-pass formula: $y[i] = y[i-1] + \alpha \times (x[i] - y[i-1])$
      bandPassed[i] =
          bandPassed[i - 1] + alphaLow * (highPassed[i] - bandPassed[i - 1]);
    }

    return bandPassed;
  }
}
