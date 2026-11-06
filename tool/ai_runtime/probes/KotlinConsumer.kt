// Compiles against JavaProbe.class only, without the AAR on this classpath.
fun throughJava(config: Any): String = JavaProbe.modelPath(config)
