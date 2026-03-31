import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/heart_rate_cubit.dart';

class HeartRateScreen extends StatelessWidget {
  const HeartRateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCG/GCG Heart Rate Monitor'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: BlocBuilder<HeartRateCubit, HeartRateState>(
            builder: (context, state) {
              // --- Initial / Ready ---
              if (state is HeartRateInitial) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Lie down and place the phone flat over your heart.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () {
                        context.read<HeartRateCubit>().startMeasurement();
                      },
                      child: const Text(
                        'Start Measurement',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                );
              }

              // --- Gathering Data ---
              if (state is HeartRateGathering) {
                // Convert our list of doubles into FlChart Spots (X, Y coordinates)
                List<FlSpot> spots = [];
                for (int i = 0; i < state.waveData.length; i++) {
                  spots.add(FlSpot(i.toDouble(), state.waveData[i]));
                }

                // Find the dynamic min/max so the chart auto-scales beautifully
                double minY = state.waveData.reduce(min);
                double maxY = state.waveData.reduce(max);
                // Add a tiny bit of padding so the line doesn't touch the edges
                if (maxY - minY < 0.1) maxY = minY + 0.1;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Recording... ${state.progressPercent}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Please hold completely still.',
                      style: TextStyle(fontSize: 18, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 40),

                    // --- The fl_chart Waveform ---
                    SizedBox(
                      height: 200, // Height of the chart
                      width: double.infinity,
                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: spots.length.toDouble() - 1,
                          minY: minY - 0.5,
                          maxY: maxY + 0.5,

                          // Hide all the grid lines, borders, and numbers for a clean look
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),

                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved:
                                  true, // Smooths out the sensor jitter slightly
                              color: Colors.redAccent,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: false,
                              ), // Hide individual dots
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.redAccent.withValues(
                                  alpha: 0.1,
                                ), // Nice subtle gradient
                              ),
                            ),
                          ],
                        ),
                        // Swap animation duration to 0 so it updates instantly with the stream
                        duration: Duration.zero,
                      ),
                    ),
                  ],
                );
              }

              // --- Motion Detected (Error) ---
              if (state is HeartRateMotionDetected) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 80,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Too Much Movement',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'We detected motion that interfered with the reading. Please breathe normally and avoid talking or moving.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        // Reset to initial state to try again
                        context.read<HeartRateCubit>().startMeasurement();
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                );
              }

              if (state is HeartRateNoSignal) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.speaker_notes_off_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Pulse Detected',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The signal is completely flat. Make sure the phone is resting directly on your chest, not a table or thick mattress.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        context.read<HeartRateCubit>().startMeasurement();
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                );
              }

              // --- Poor Signal (No Harmonics Found) ---
              if (state is HeartRatePoorSignal) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.waves, size: 80, color: Colors.orange),
                    const SizedBox(height: 24),
                    const Text(
                      'Signal Unclear',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'We detected vibrations, but could not lock onto a clear rhythmic heartbeat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 32),

                    // Try Again Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                      onPressed: () {
                        context.read<HeartRateCubit>().startMeasurement();
                      },
                      child: const Text('Try Again'),
                    ),
                    const SizedBox(height: 16),

                    // --- Export Button for Debugging ---
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Export Debug Data'),
                      onPressed: () {
                        context.read<HeartRateCubit>().exportData(
                          state.resultData,
                        );
                      },
                    ),
                  ],
                );
              }

              // --- Success! ---
              if (state is HeartRateCalculated) {
                // Extract the BPM
                final double bpm = state.resultData['bpm'];

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite,
                      size: 80,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Estimated Heart Rate',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    Text(
                      bpm.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'BPM',
                      style: TextStyle(fontSize: 24, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),

                    // The Measure Again button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                      onPressed: () {
                        context.read<HeartRateCubit>().startMeasurement();
                      },
                      child: const Text('Measure Again'),
                    ),
                    const SizedBox(height: 16),

                    // --- The Export Button ---
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('Export CSV Data'),
                      onPressed: () {
                        // Pass the rich data map to the export function
                        context.read<HeartRateCubit>().exportData(
                          state.resultData,
                        );
                      },
                    ),
                  ],
                );
              }

              // Fallback (shouldn't be reached)
              return const CircularProgressIndicator();
            },
          ),
        ),
      ),
    );
  }
}
