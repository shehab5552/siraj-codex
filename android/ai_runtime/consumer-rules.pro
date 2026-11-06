# The actual JNI implementation binds these public classes/methods by name.
# Keep this boundary and Kotlin reflection metadata; do not disable R8/D8 or
# suppress missing-class/metadata diagnostics.
-keep class com.google.ai.edge.litertlm.** { *; }
-keep class kotlin.Metadata { *; }
-keepattributes Signature,InnerClasses,EnclosingMethod,RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations
