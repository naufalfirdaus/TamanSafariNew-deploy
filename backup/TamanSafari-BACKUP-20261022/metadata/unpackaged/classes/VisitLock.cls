/**
 * @description Lets system processes write to Completed and Cancelled visits past the lock in
 *              VisitFormTriggerHandler (visit-ai-scoring design D2). Only the services that own post-completion writes
 *              (AI scoring send, the score write-back endpoint, the sweep job, the stale job) call it. A user
 *              cannot set the flag: it is a static in this transaction, and no @AuraEnabled method exposes it.
 */
public without sharing class VisitLock {
  /** True only while runAsSystem is performing its DML. Read by the lock in VisitFormTriggerHandler. */
  public static Boolean systemWrite = false;

  /**
   * @description Updates visits in system mode with the completed-visit lock lifted for the duration of the DML. The flag
   *              is restored afterwards, even when the DML throws, so one call never leaves the lock open for the next.
   * @param visits Visits with the Id and the fields to write.
   * @param allOrNone True to roll back and throw when any record fails.
   * @return One save result per record.
   */
  public static List<Database.SaveResult> runAsSystem(List<Visit_Form__c> visits, Boolean allOrNone) {
    Boolean previous = systemWrite;
    systemWrite = true;
    try {
      return Database.update(visits, allOrNone, AccessLevel.SYSTEM_MODE);
    } finally {
      systemWrite = previous;
    }
  }
}