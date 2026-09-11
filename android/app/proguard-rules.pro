# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn com.google.android.play.core.**

# SQLite3 / Drift Proguard Rules
-keep class com.simonbinder.sqlite3.** { *; }
-dontwarn com.simonbinder.sqlite3.**
