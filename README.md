# Expense & Goals Tracker

A lightweight, minimal mobile expense and goals tracker built with Flutter and Drift.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## Build Release Commands

### 1. Recommended (Smallest Size ~8.5 MB per phone architecture)
Splits the APK for specific CPU architectures (e.g. 64-bit phones, 32-bit phones):

```bash
flutter build apk --release --split-per-abi
```

### 2. Universal Release APK (Single APK for all phones)
Builds a single APK that works on any Android phone architecture:

```bash
flutter build apk --release
```
**Generated APK location:**
`build/app/outputs/flutter-apk/app-release.apk`

### 3. Google Play Store Release (Android App Bundle - AAB)
If you are publishing to the Google Play Store:

```bash
flutter build appbundle --release
```
**Generated Bundle location:**
`build/app/outputs/bundle/release/app-release.aab`