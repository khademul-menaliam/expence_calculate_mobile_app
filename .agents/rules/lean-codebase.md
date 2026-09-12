# Development & Architecture Rules

When implementing features, refactoring, or maintaining code in this repository:

1. **Production-Grade Code First**:
   - Always prioritize clean architecture, robust error handling, Riverpod state patterns, and testability.
   - **Never** write fragile, obscure, or unmaintainable code just to minimize size. Code quality and best practices are top priority.

2. **Feature Growth & Size Discipline**:
   - App size naturally scales as new features are added. Do not artificially limit functionality.
   - Prevent waste: avoid redundant dependencies, never bundle unneeded fonts/icon packs, and compress all image assets before adding them.

3. **Clean Code & Zero Lints**:
   - All changes must pass `flutter analyze` with 0 issues.
   - Guard async BuildContext calls with `if (!context.mounted) return;`.

4. **Preserve Build Toolchain**:
   - Retain `useLegacyPackaging = true` in `android/app/build.gradle.kts` and R8 full mode in `android/gradle.properties`.

5. **No Junk Files**:
   - Never commit or leave temporary files such as `*.iml`, `.idea/`, `.widget_preview/`, `*.tmp`, or scratch scripts.
