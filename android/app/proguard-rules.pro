# Keep Error Prone Annotations
-keep class com.google.errorprone.annotations.** { *; }
-dontwarn com.google.errorprone.annotations.**

# Keep Javax Annotations
-keep class javax.annotation.** { *; }
-dontwarn javax.annotation.**

# Keep Crypto Tink Library
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
