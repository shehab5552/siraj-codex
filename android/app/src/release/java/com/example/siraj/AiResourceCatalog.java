package com.example.siraj;
import java.io.File;
import java.util.Collections;
import com.example.siraj.ai_runtime.TrustedResourceResolver;
/** Production remains closed without an approved resource catalog. */
public final class AiResourceCatalog {
  public static TrustedResourceResolver create(File files) {
    return new TrustedResourceResolver(new File(files,"ai-runtime-fixtures"),Collections.emptyMap());
  }
}
