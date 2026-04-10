# ML Kit — ignora scripts que não usamos (chinês, japonês, coreano, devanagari)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Mantém classes do ML Kit que usamos (latino)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
