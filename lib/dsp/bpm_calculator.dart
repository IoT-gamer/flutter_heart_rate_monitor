import 'dart:math';

import 'package:fftea/fftea.dart';

import 'band_pass_filter.dart';

// Helper function to process a single axis (Mean subtraction + Filtering)
List<double> _processAxis(
  List<double> rawData,
  double sampleRate,
  BandPassFilter filter,
) {
  double sum = rawData.reduce((a, b) => a + b);
  double mean = sum / rawData.length;
  List<double> centered = rawData.map((v) => v - mean).toList();
  return filter.process(centered, sampleRate);
}

// Helper function to normalize an array to range [-1.0, 1.0]
List<double> _normalize(List<double> data) {
  double maxAbs = data.map((v) => v.abs()).reduce(max);
  if (maxAbs == 0) return data;
  return data.map((v) => v / maxAbs).toList();
}

Map<String, dynamic> calculateBpmFromFft(Map<String, dynamic> params) {
  final List<double> zData = params['zData'];
  final List<double> gyroXData = params['gyroXData'];
  final List<double> gyroYData = params['gyroYData'];
  final double sampleRate = params['sampleRate'];

  final filter = BandPassFilter(lowCutoff: 0.8, highCutoff: 3.0);

  // Process each axis independently
  List<double> cleanZ = _processAxis(zData, sampleRate, filter);
  List<double> cleanGyroX = _processAxis(gyroXData, sampleRate, filter);
  List<double> cleanGyroY = _processAxis(gyroYData, sampleRate, filter);

  // Motion Artifact Rejection (Check Z-axis as our primary movement indicator)
  int settleOffset = (cleanZ.length * 0.1).toInt();
  List<double> settledZ = cleanZ.sublist(settleOffset);
  double minZ = settledZ.reduce(min);
  double maxZ = settledZ.reduce(max);
  double peakToPeak = maxZ - minZ;

  // The exact threshold depends on your phone's sensor noise floor.
  // 0.02 to 0.04 is usually perfect for detecting a hard table.
  if (peakToPeak > 0.8) {
    return {'status': 'motion_error'};
  } else if (peakToPeak < 0.03) {
    return {'status': 'no_signal'};
  }

  // Normalize the settled data for all three axes
  List<double> normZ = _normalize(settledZ);
  List<double> normGyroX = _normalize(cleanGyroX.sublist(settleOffset));
  List<double> normGyroY = _normalize(cleanGyroY.sublist(settleOffset));

  // SENSOR FUSION: Combine the axes into one "Energy" signal
  // We take the absolute value so negative and positive swings don't cancel each other out
  List<double> fusedData = List.filled(normZ.length, 0.0);
  for (int i = 0; i < normZ.length; i++) {
    fusedData[i] = normZ[i].abs() + normGyroX[i].abs() + normGyroY[i].abs();
  }

  // Run FFT on the Fused Data
  final fft = FFT(fusedData.length);
  final magnitudes = fft.realFft(fusedData).magnitudes();

  // Find Peak and Handle Harmonics
  double maxMagnitude = 0;
  int peakIndex = 0;
  double freqResolution = sampleRate / fusedData.length;

  for (int i = 0; i < magnitudes.length; i++) {
    double currentFreq = i * freqResolution;
    if (currentFreq >= 0.8 && currentFreq <= 3.0) {
      if (magnitudes[i] > maxMagnitude) {
        maxMagnitude = magnitudes[i];
        peakIndex = i;
      }
    }
  }

  double peakFrequency = peakIndex * freqResolution;
  double calculatedBpm = peakFrequency * 60.0;

  // Harmonic Verification (The "Double Counting" Fix)
  if (calculatedBpm > 110.0) {
    int halfFreqIndex = (peakIndex / 2).round();
    double maxHalfMagnitude = 0;

    for (int i = halfFreqIndex - 2; i <= halfFreqIndex + 2; i++) {
      if (i > 0 && i < magnitudes.length) {
        if (magnitudes[i] > maxHalfMagnitude) {
          maxHalfMagnitude = magnitudes[i];
        }
      }
    }

    if (maxHalfMagnitude > (maxMagnitude * 0.40)) {
      calculatedBpm = calculatedBpm / 2.0;
    }
  }

  // Create an array of the exact frequencies for the CSV
  List<double> frequencies = [];
  for (int i = 0; i < magnitudes.length; i++) {
    frequencies.add(i * freqResolution);
  }

  // Return a Map with everything we want to save
  return {
    'status': 'success',
    'bpm': calculatedBpm,
    'timeSeries': fusedData, // The normalized, combined wave
    'magnitudes': magnitudes, // The raw FFT spike sizes
    'frequencies': frequencies, // The Hz labels for the spikes
  };
}
