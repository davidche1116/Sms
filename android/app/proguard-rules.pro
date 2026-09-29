# Keep all classes in the app package (MethodChannel handlers, reflection targets)
-keep class com.dc16.sms.** { *; }

# Keep Flutter plugin classes
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# SystemProperties is accessed via reflection in SmsAccess.kt
-keep class android.os.SystemProperties { *; }
