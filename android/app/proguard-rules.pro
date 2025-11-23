# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Syncfusion classes
-keep class com.syncfusion.** { *; }

# Keep QR Flutter classes
-keep class net.touchcapture.qr.** { *; }

# Keep Mobile Scanner classes
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Keep file picker classes
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Keep image picker classes
-keep class io.flutter.plugins.imagepicker.** { *; }

# Keep share plus classes
-keep class dev.fluttercommunity.plus.share.** { *; }

# Keep url launcher classes
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep path provider classes
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep signature classes
-keep class com.nb.native_signature.** { *; }

# Keep sqflite classes
-keep class com.tekartik.sqflite.** { *; }

# Keep get_storage classes
-keep class com.getstorage.** { *; }

# Keep get classes
-keep class com.get.** { *; }

# Keep provider classes
-keep class provider.** { *; }

# General Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Don't warn about missing classes
-dontwarn io.flutter.embedding.**

