package com.example.siraj.ai_runtime;
public final class RequestOwnershipTest {
  public static void main(String[] args) {
    RequestOwnership owners=new RequestOwnership();RequestOwnership.Lease first=owners.claim("same",1);
    try { owners.claim("same",1);throw new AssertionError("duplicate must not replace active lease"); }
    catch(RuntimeFailure expected) {if(expected.code!=RuntimeFailure.Code.invalidRequest)throw new AssertionError();}
    if(owners.current("same")!=first)throw new AssertionError();
    owners.release("same",new RequestOwnership.Lease(1));if(owners.current("same")!=first)throw new AssertionError();
    owners.release("same",first);if(owners.current("same")!=null)throw new AssertionError();
    RequestOwnership.Lease next=owners.claim("same",2);owners.release("same",first);if(owners.current("same")!=next)throw new AssertionError();
    owners.clear();if(owners.current("same")!=null)throw new AssertionError();
    System.out.println("RequestOwnershipTest: 5 passed");
  }
}
