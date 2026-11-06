import com.google.ai.edge.litertlm.EngineConfig

// Compile-only metadata probe; does not instantiate or execute the model.
fun stagedModelPath(config: EngineConfig): String = config.modelPath
