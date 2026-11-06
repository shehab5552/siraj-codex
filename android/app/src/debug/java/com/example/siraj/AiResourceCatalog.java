package com.example.siraj;
import java.io.File;
import java.util.HashMap;
import java.util.Map;
import com.example.siraj.ai_runtime.TrustedResourceResolver;
/** Owner-pinned engineering fixtures only; Apache2 review/provenance recorded
 * in docs/qa/b08-runtime/model-license-review.json. No release source set,
 * production catalog, model URL, override or model binary is supplied here. */
public final class AiResourceCatalog {
  public static TrustedResourceResolver create(File files) {
    try {
      // Context.filesDir is trusted and may include an OS-managed alias. Pin
      // that canonical base before appending the fixed, untrusted fixture child.
      Map<String,TrustedResourceResolver.Pin> pins=new HashMap<>();
      pins.put("b08-qwen3-staging-v1",new TrustedResourceResolver.Pin("Qwen3-0.6B.litertlm","c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108",613722264L,false));
      pins.put("b08-embedding-staging-v1",new TrustedResourceResolver.Pin("embeddinggemma-2-text-270m.litertlm","2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb",164626432L,true));
      return new TrustedResourceResolver(new File(files.getCanonicalFile(),"ai-runtime-fixtures"),pins);
    } catch(java.io.IOException error) {
      throw new com.example.siraj.ai_runtime.RuntimeFailure(com.example.siraj.ai_runtime.RuntimeFailure.Code.unsafeResourcePath);
    }
  }
}
