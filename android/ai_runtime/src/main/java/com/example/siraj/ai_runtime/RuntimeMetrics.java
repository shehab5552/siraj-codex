package com.example.siraj.ai_runtime;
import java.util.*;

/** Actual SDK benchmark counters only; never token estimates or model text. */
public final class RuntimeMetrics {
  public final double initializeSeconds,firstTokenSeconds,prefillTokensPerSecond,decodeTokensPerSecond;
  public final int prefillTokens,decodeTokens;
  public RuntimeMetrics(double initializeSeconds,double firstTokenSeconds,int prefillTokens,int decodeTokens,double prefillTokensPerSecond,double decodeTokensPerSecond) {
    for(double value:new double[]{initializeSeconds,firstTokenSeconds,prefillTokensPerSecond,decodeTokensPerSecond}) {
      if(!Double.isFinite(value) || value<0)throw new IllegalArgumentException("Invalid benchmark");
    }
    if(prefillTokens<0 || decodeTokens<=0 || decodeTokensPerSecond<=0)throw new IllegalArgumentException("Invalid benchmark");
    this.initializeSeconds=initializeSeconds;this.firstTokenSeconds=firstTokenSeconds;this.prefillTokens=prefillTokens;this.decodeTokens=decodeTokens;
    this.prefillTokensPerSecond=prefillTokensPerSecond;this.decodeTokensPerSecond=decodeTokensPerSecond;
  }
  public Map<String,Object> toMap() {
    Map<String,Object> value=new HashMap<>();value.put("initializeSeconds",initializeSeconds);value.put("firstTokenSeconds",firstTokenSeconds);
    value.put("prefillTokens",prefillTokens);value.put("decodeTokens",decodeTokens);value.put("prefillTokensPerSecond",prefillTokensPerSecond);value.put("decodeTokensPerSecond",decodeTokensPerSecond);return value;
  }
}
