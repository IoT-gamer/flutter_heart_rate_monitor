# 🫀 SCG & GCG Heart Rate Monitor (Flutter)

![Work in Progress](https://img.shields.io/badge/status-work%20in%20progress-yellow)

An experimental Flutter application that measures a user's resting heart rate using a smartphone's built-in accelerometer and gyroscope. 

This project leverages **Seismocardiography (SCG)** (measuring linear chest vibrations) and **Gyrocardiography (GCG)** (measuring angular cardiac motion) to detect the mechanical "lub-dub" of the heart without needing external hardware or a camera.

---

## 🔬 How It Works

The app captures micro-vibrations from the user's chest and processes them using a custom Digital Signal Processing (DSP) pipeline:

1. **Sensor Fusion:** Captures synchronized data from the Z-axis accelerometer and X/Y-axis gyroscope at ~50Hz.
2. **Band-Pass Filtering:** Removes baseline gravity (DC offset), slow breathing waves (< 0.8 Hz), and high-frequency noise (> 3.0 Hz).
3. **Motion Artifact Rejection:** Detects macroscopic body movements and invalidates tainted data to prevent false readings.
4. **Fast Fourier Transform (FFT):** Converts the time-domain waveform into the frequency domain to identify the dominant cardiac frequency.
5. **Harmonic Verification:** Analyzes the frequency bins to prevent "double counting" caused by the sharp mechanical nature of heart valves closing.
6. **Export Functionality:** Allows users to export raw time-series data and frequency spectra as CSV files for further analysis.

---

## 🛠 Tech Stack & Packages

This app is built with Flutter and relies on the following core packages:

* [`sensors_plus`](https://pub.dev/packages/sensors_plus): Streams raw hardware accelerometer and gyroscope data.
* [`fftea`](https://pub.dev/packages/fftea): Performs highly optimized Fast Fourier Transforms (FFT) in Dart.
* [`integral_isolates`](https://pub.dev/packages/integral_isolates): Offloads the heavy DSP math to a background thread to prevent UI jank.
* [`circular_buffer`](https://pub.dev/packages/circular_buffer): Manages the rolling 10-second window of sensor data efficiently.
* [`flutter_bloc`](https://pub.dev/packages/flutter_bloc): Manages the application state (`Initial`, `Gathering`, `MotionDetected`, `Calculated`).
* [`fl_chart`](https://pub.dev/packages/fl_chart): Renders the real-time cardiac energy waveform during data collection.
* [`wakelock_plus`](https://pub.dev/packages/wakelock_plus): Prevents the device screen from sleeping during the 10-15 second measurement window.

---

## 📂 Architecture

To maintain performance and scalability, the UI, State Management, and Signal Processing are strictly decoupled:

```text
lib/
 ├── main.dart
 ├── ui/
 │    └── heart_rate_screen.dart    # UI and fl_chart waveform
 ├── cubit/
 │    ├── heart_rate_cubit.dart     # State management & sensor streams
 │    └── heart_rate_state.dart
 └── dsp/
      ├── band_pass_filter.dart     # Pure Dart math (Unit-testable)
      └── bpm_calculator.dart       # Top-level Isolate function (FFT & Logic)

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0 or higher)
- A physical iOS or Android device (Sensors cannot be fully simulated in standard emulators).

### Installation
1. Clone the repository:
```bash
git clone https://github.com/IoT-gamer/flutter_heart_rate_monitor.git
```
2. Navigate to the project directory:
```bash
cd flutter_heart_rate_monitor
```
3. Install dependencies:
```bash
flutter pub get
```
4. Run the app on a physical device:
```bash
flutter run
```

## 📖 Usage Instructions

Because SCG/GCG measures microscopic vibrations, strict adherence to posture is required:

1. Lie completely flat on your back on a stable surface (bed or floor).
2. Place the smartphone flat directly over your sternum/heart.
3. Tap "Start Measurement".
4. **Breathe normally and remain perfectly still** for approximately 10-15 seconds. Talking, adjusting your grip, or deep sighs could trigger the Motion Rejection protocol.
5.View your calculated BPM.

## 🧪 Future Work
- **Machine Learning Integration:** Train a lightweight neural network (1D CNN) on labeled SCG/GCG datasets to improve accuracy and robustness against noise.
- **Sitting and/or Standing Capability:** Explore advanced motion compensation algorithms to allow measurements in non-supine postures.

## ⚠️ Disclaimer
**This application is for educational and experimental purposes only.** It is not a medical device. It has not been evaluated by the FDA or any other regulatory body. Do not use this application to diagnose, treat, mitigate, or prevent any disease or health condition. Always consult a qualified healthcare professional for medical advice.

## 📄 LICENSE
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.