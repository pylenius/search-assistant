# Keep kotlinx.serialization-generated descriptors for our DTOs so JSON
# decoding survives R8 in release builds.
-keep class fi.eport.searchassistant.data.api.** { *; }
-keepclassmembers class **$$serializer { *; }
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}
-keepattributes *Annotation*, InnerClasses
