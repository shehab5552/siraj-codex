package com.example.siraj;
import java.io.File;
import java.util.Collections;
import com.example.siraj.ai_runtime.TrustedResourceResolver;
/** Isolated engineering fixtures. Remains closed until exact weights license
 * provenance has been reviewed; no paths or catalog overrides via Flutter. */
public final class AiResourceCatalog {
  public static TrustedResourceResolver create(File files) {
    return new TrustedResourceResolver(new File(files,"ai-runtime-fixtures"),Collections.emptyMap());
  }
}
