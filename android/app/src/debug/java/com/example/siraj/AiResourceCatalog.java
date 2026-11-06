package com.example.siraj;
import java.io.File;
import java.util.Collections;
import com.example.siraj.ai_runtime.TrustedResourceResolver;
/** Isolated engineering fixtures. Remains closed until exact weights license
 * provenance has been reviewed; no paths or catalog overrides via Flutter. */
public final class AiResourceCatalog {
  public static TrustedResourceResolver create(File files) {
    try {
      // Context.filesDir is trusted and may include an OS-managed alias. Pin
      // that canonical base before appending the fixed, untrusted fixture child.
      return new TrustedResourceResolver(new File(files.getCanonicalFile(),"ai-runtime-fixtures"),Collections.emptyMap());
    } catch(java.io.IOException error) {
      throw new com.example.siraj.ai_runtime.RuntimeFailure(com.example.siraj.ai_runtime.RuntimeFailure.Code.unsafeResourcePath);
    }
  }
}
