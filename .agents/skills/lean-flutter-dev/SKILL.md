---
name: lean-flutter-dev
description: >-
  Use this skill when developing new features, refactoring, adding dependencies,
  or building this Flutter mobile app. Ensures production-grade clean architecture,
  robust best practices first, followed by zero-waste size optimization and junk prevention.
---

# Lean Flutter Development & Best Practices Runbook

This runbook guides all future development on **Expense & Goals Tracker**.

---

## 🎯 Core Philosophy: Production Quality First, Size Efficiency Second

1. **Best Practices & Production-Grade Code are Top Priority**:
   - Always prioritize clean architecture, maintainability, testability, strong typing, and idiomatic Flutter/Riverpod patterns.
   - **Never** compromise code readability, safety, error handling, or architecture just to shave a few bytes.
   - Build on the existing clean architecture: Drift for persistence, Riverpod for state management, and clear Repository abstraction layers.
2. **App Size Scales Naturally with Features**:
   - When new capabilities (e.g., visual charts, CSV/PDF exports, advanced filters) are added, the app size will naturally grow. That is expected and healthy.
   - Size optimization is about **preventing unnecessary bloat, redundant dependencies, and junk files**—not capping feature growth or writing obscure code.
3. **Skill Identification**:
   - You can invoke this runbook explicitly by name in any prompt:
     `"Use lean-flutter-dev to implement [feature]"`
   - The agent also automatically loads this skill when planning and building new features or modifying dependencies.

---

## 1. Production-Grade Architecture & Code Standards

- **State Management**: Use `flutter_riverpod` providers for reactive UI updates and clear separation of business logic from presentation.
- **Data Layer**: Use the established `AppDatabase` (Drift) and repository classes (`ExpenseRepository`, `GoalRepository`). Keep database logic decoupled from UI widgets.
- **Async Safety**: Always guard `BuildContext` across async gaps with `if (!context.mounted) return;`.
- **Testing**: Maintain test coverage. Add unit/repository tests for new business logic and widget tests for new UI flows in `test/`.

---

## 2. Dependency Management Guidelines

- **Evaluate Before Adding**:
  - Before adding any package to `pubspec.yaml`, check whether existing libraries (`drift`, `flutter_riverpod`, `intl`) or standard Dart SDK capabilities can fulfill the requirement cleanly.
  - Avoid packages that introduce heavy native C/C++ libraries (`.so` files) unless essential for the feature.
  - Avoid redundant UI icon packages (e.g., avoid `cupertino_icons` if Material icons suffice).
- **Audit & Maintain**:
  - Run `flutter pub outdated` periodically to keep dependencies modern and secure.

---

## 3. Asset & Resource Optimization

- **Runtime vs. Development Assets**:
  - Only declare assets in `pubspec.yaml` under `flutter: assets:` if they are actively rendered in the UI at runtime.
  - Store source logos or design mockups in `assets/icon/` or outside the bundled path so they are not packaged into the release APK.
- **Format & Compression**:
  - Use WebP or lossless compressed PNG for raster images.
  - Maintain `--tree-shake-icons` (default in release mode) to strip unused Material icon glyphs.

---

## 4. Android Build & Packaging Configuration

Maintain these build settings so new features don't inadvertently inflate the binary:

### Native Library Deflate Compression
Keep `useLegacyPackaging = true` in `android/app/build.gradle.kts`:
```kotlin
packaging {
    jniLibs {
        useLegacyPackaging = true
    }
    resources {
        excludes += listOf(
            "META-INF/*.version",
            "META-INF/LICENSE*",
            "META-INF/NOTICE*",
            "/META-INF/{AL2.0,LGPL2.1}"
        )
    }
}
```
*Impact*: Compresses native `.so` files (Flutter engine, Dart runtime, SQLite) with DEFLATE, saving ~11+ MB.

### ProGuard / R8 Full Mode
Keep `android.enableR8.fullMode=true` in `android/gradle.properties`:
```properties
android.enableR8.fullMode=true
```
In `buildTypes.release`:
```kotlin
isMinifyEnabled = true
isShrinkResources = true
proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
```

---

## 5. Building Binaries for Distribution

### Architecture-Specific Release APKs (Recommended for direct APK installation)
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```
- Produces targeted APKs per ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`) rather than bundling all native ABIs into one fat APK.

### Google Play Store App Bundle
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

---

## 6. Verification Checklist

Before finishing any task:
1. **Static Analysis**: `flutter analyze` must pass with **0 issues**.
2. **Automated Tests**: `flutter test` must pass all test suites.
3. **Workspace Hygiene**: Remove any temporary files (`*.iml`, `.widget_preview`, `.idea/`, `.tmp`, scratch scripts).
