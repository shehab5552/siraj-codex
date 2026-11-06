import com.google.ai.edge.litertlm.EngineConfig;

// Plain public Java boundary: the Kotlin consumer never receives an AAR type.
public final class JavaProbe {
  public static String modelPath(Object config) {
    return ((EngineConfig) config).getModelPath();
  }
}
