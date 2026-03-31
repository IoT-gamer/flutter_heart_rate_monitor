import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:circular_buffer/circular_buffer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:integral_isolates/integral_isolates.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../dsp/bpm_calculator.dart';

part 'heart_rate_state.dart';

class HeartRateCubit extends Cubit<HeartRateState> {
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;

  final int _bufferSize = 512;

  // Buffers for all three axes
  late CircularBuffer<double> _zBuffer;
  late CircularBuffer<double> _gyroXBuffer;
  late CircularBuffer<double> _gyroYBuffer;

  final StatefulIsolate _isolate = StatefulIsolate();
  DateTime? _startTime;
  int _sampleCount = 0;

  // Variables to hold the latest gyro readings
  double _latestGyroX = 0.0;
  double _latestGyroY = 0.0;

  // A smaller buffer just for the UI chart (150 points = ~3 seconds)
  final int _uiBufferSize = 150;
  late CircularBuffer<double> _uiWaveBuffer;

  HeartRateCubit() : super(HeartRateInitial()) {
    _zBuffer = CircularBuffer<double>(_bufferSize);
    _gyroXBuffer = CircularBuffer<double>(_bufferSize);
    _gyroYBuffer = CircularBuffer<double>(_bufferSize);

    // Initialize the UI buffer
    _uiWaveBuffer = CircularBuffer<double>(_uiBufferSize);

    _isolate.init();
  }

  void startMeasurement() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();

    _zBuffer.clear();
    _gyroXBuffer.clear();
    _gyroYBuffer.clear();

    // Fill the UI buffer with zeros so the chart starts flat
    _uiWaveBuffer.clear();
    for (int i = 0; i < _uiBufferSize; i++) {
      _uiWaveBuffer.add(0.0);
    }

    _sampleCount = 0;
    _startTime = DateTime.now();

    // 1. Start listening to the Gyroscope (constantly updating the latest values)
    _gyroSubscription =
        gyroscopeEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen((GyroscopeEvent event) {
          _latestGyroX = event.x;
          _latestGyroY = event.y;
        });

    // 2. Start listening to the Accelerometer (This drives our buffer logic)
    _accelSubscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen((AccelerometerEvent event) {
          // Add all three synchronized points to their buffers
          _zBuffer.add(event.z);
          _gyroXBuffer.add(_latestGyroX);
          _gyroYBuffer.add(_latestGyroY);

          _sampleCount++;

          // --- Calculate a quick raw preview for the chart ---
          // We strip a rough gravity estimate (9.8) from Z so it fits on screen
          double rawFused =
              (event.z - 9.8).abs() + _latestGyroX.abs() + _latestGyroY.abs();
          _uiWaveBuffer.add(rawFused);

          if (_zBuffer.isFilled) {
            _processData();
          } else {
            int progress = ((_zBuffer.length / _bufferSize) * 100).toInt();
            // Pass the UI buffer to the state
            emit(HeartRateGathering(progress, _uiWaveBuffer.toList()));
          }
        });
  }

  Future<void> _processData() async {
    await _accelSubscription?.cancel();
    await _gyroSubscription?.cancel();

    final elapsedSeconds =
        DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
    final actualSampleRate = _sampleCount / elapsedSeconds;

    try {
      // Expect a Map back from the isolate now
      final Map<String, dynamic> result = await _isolate
          .compute(calculateBpmFromFft, {
            'zData': _zBuffer.toList(),
            'gyroXData': _gyroXBuffer.toList(),
            'gyroYData': _gyroYBuffer.toList(),
            'sampleRate': actualSampleRate,
          });

      if (result['status'] == 'motion_error') {
        emit(HeartRateMotionDetected());
      } else if (result['status'] == 'no_signal') {
        emit(HeartRateNoSignal());
      } else if (result['status'] == 'poor_signal') {
        emit(HeartRatePoorSignal(result)); // Pass the map here
      } else {
        emit(HeartRateCalculated(result));
      }
    } catch (e) {
      emit(HeartRateInitial());
    }
  }

  Future<void> exportData(Map<String, dynamic> data) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Create Time-Series CSV String
      List<double> timeSeries = data['timeSeries'];
      String timeCsv = "Index,Amplitude\n";
      for (int i = 0; i < timeSeries.length; i++) {
        timeCsv += "$i,${timeSeries[i]}\n";
      }

      // Create Frequency Spectrum CSV String
      List<double> frequencies = data['frequencies'];
      List<double> magnitudes = data['magnitudes'];
      String freqCsv = "Frequency_Hz,Magnitude\n";
      for (int i = 0; i < magnitudes.length; i++) {
        freqCsv += "${frequencies[i]},${magnitudes[i]}\n";
      }

      // Share directly from memory
      final params = ShareParams(
        text: 'SCG Heart Rate Data - ${data['bpm'].toStringAsFixed(1)} BPM',
        files: [
          XFile.fromData(utf8.encode(timeCsv), mimeType: 'text/csv'),
          XFile.fromData(utf8.encode(freqCsv), mimeType: 'text/csv'),
        ],
        fileNameOverrides: [
          'time_series_$timestamp.csv',
          'spectrum_$timestamp.csv',
        ],
      );

      await SharePlus.instance.share(params);
    } catch (e) {
      print("Error sharing files: $e");
    }
  }

  @override
  Future<void> close() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _isolate.dispose();
    return super.close();
  }
}
