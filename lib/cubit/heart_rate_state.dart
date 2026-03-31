part of 'heart_rate_cubit.dart';

abstract class HeartRateState {}

class HeartRateInitial extends HeartRateState {}

class HeartRateGathering extends HeartRateState {
  final int progressPercent;
  final List<double> waveData; // The data for our chart

  HeartRateGathering(this.progressPercent, this.waveData);
}

class HeartRateMotionDetected extends HeartRateState {}

class HeartRateNoSignal extends HeartRateState {}

class HeartRatePoorSignal extends HeartRateState {
  final Map<String, dynamic> resultData; // Hold the data
  HeartRatePoorSignal(this.resultData);
}

class HeartRateCalculated extends HeartRateState {
  final Map<String, dynamic> resultData;
  HeartRateCalculated(this.resultData);
}
