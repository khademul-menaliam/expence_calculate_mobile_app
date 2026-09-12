---
name: lean-flutter-dev
description: >-
  Use this skill when developing new features, refactoring, adding dependencies,
  or building ANY Flutter mobile application. Ensures production-grade clean architecture,
  robust best practices first, followed by zero-waste size optimization and junk prevention.
---

# Lean Flutter Development & Production Best Practices

This runbook provides universal, production-grade guidelines and size-optimization practices for developing high-quality **Flutter** mobile applications.

---

## 🎯 Core Philosophy: Production Quality First, Zero-Waste Second

1. **Best Practices & Production-Grade Code are Top Priority**:
   - Prioritize clean architecture, maintainability, testability, strong typing, and idiomatic Flutter state management patterns (e.g., Riverpod, Bloc, or Provider).
   - **Never** compromise code readability, safety, error handling, or clean architecture just to shave off a few bytes.
   - Separate concerns cleanly: Presentation (UI), Business Logic (Providers/Blocs), and Data (Repositories/Database).
2. **App Size Scales Naturally with Features**:
   - As new capabilities (e.g., charts, PDF/CSV export, push notifications, offline sync) are added, the binary size will naturally grow. That is expected and healthy.
   - Size optimization is about **preventing unnecessary bloat, redundant dependencies, uncompressed binaries, and junk files**—not capping feature growth or writing obscure code.
3. **Universal Usage**:
   - This skill is designed to work in any Flutter project repository.
   - Simply check `.agents/skills/lean-flutter-dev/SKILL.md` into your Git repository so team members or GitHub contributors can use it.
   - You can invoke it explicitly in any prompt: `"Use lean-flutter-dev to implement [feature]"`.

---

## 1. Production Architecture & Code Standards

- **State Management**: Keep UI widgets purely declarative. Delegate business logic to dedicated state controllers/providers.
- **Data Layer**: Decouple database/API calls behind repository interfaces.
- **Async Safety**: Always guard `BuildContext` across async gaps using:
  ```dart
  if (!context.mounted) return;
  ```
- **Testing**: Maintain test coverage for business logic and critical UI flows (`test/` directory).

---

## 2. Dependency Management Guidelines

- **Vet Before Adding**:
  - Before adding a package to `pubspec.yaml`, verify whether standard Dart/Flutter SDK features or existing dependencies already meet the requirement.
  - Avoid packages that introduce heavy uncompressed native C/C++ libraries (`.so` files) unless necessary for core features.
  - Avoid redundant UI icon packages (e.g., avoid importing `cupertino_icons` if only Material icons are used).
- **Audit**:
  - Periodically run `flutter pub outdated` to keep dependencies modern and secure.

---

## 3. Asset & Resource Optimization

- **Runtime vs. Development Assets**:
  - Only declare assets under `flutter: assets:` in `pubspec.yaml` if they are actively rendered in the app at runtime.
  - Development assets (such as raw 1024x1024 logos used for icon generation) should be kept outside runtime bundle paths (e.g., in `assets/icon/` with `pubspec.yaml` `assets:` undeclared, or generated via `flutter_launcher_icons`).
- **Format & Compression**:
  - Use compressed WebP or optimized PNG for image assets.
  - Keep icon tree-shaking active (`--tree-shake-icons`, enabled by default in release mode).

---

## 4. Android Build & Compacting Configuration

To keep Android release binaries compact, ensure the following build configurations are set in `android/app/build.gradle.kts` and `android/gradle.properties`:

### Native Library Deflate Compression
In `android/app/build.gradle.kts`:
```kotlin
android {
    ...
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
}
```
*Why?* Gradle uncompresses native `.so` files (Flutter engine, Dart runtime, SQLite) by default. Setting `useLegacyPackaging = true` compresses them with DEFLATE inside the APK, saving ~10–15 MB.

### ProGuard / R8 Full Mode
In `android/gradle.properties`:
```properties
android.enableR8.fullMode=true
```
In `android/app/build.gradle.kts` (`buildTypes.release`):
```kotlin
isMinifyEnabled = true
isShrinkResources = true
proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
```

---

## 5. Building Compact Release Binaries

### Architecture-Specific Release APKs (Recommended for direct APK distribution)
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```
- Generates separate APKs per target architecture (`arm64-v8a`, `armeabi-v7a`, `x86_64`) instead of a single bloated fat APK.

### Google Play Store App Bundle
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

---

## 6. Verification & Cleanliness Checklist

Before finishing any task:
1. **Static Analysis**: `flutter analyze` must pass with **0 issues**.
2. **Automated Tests**: `flutter test` must pass all test suites.
3. **Junk & Scratch File Cleanup**: Ensure temporary files (`*.iml`, `.widget_preview/`, `.idea/`, `*.tmp`, scratch scripts) are never committed or left around.
