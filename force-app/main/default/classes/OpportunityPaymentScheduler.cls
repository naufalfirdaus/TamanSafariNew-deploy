public with sharing class OpportunityPaymentScheduler {
  public static void sync(
    List<Opportunity> newOpps,
    Map<Id, Opportunity> oldMap
  ) {
    List<Opportunity> candidates = new List<Opportunity>();
    for (Opportunity o : newOpps) {
      if (o.IsClosed) {
        continue;
      }
      Opportunity old = oldMap == null ? null : oldMap.get(o.Id);
      Boolean changed =
        old == null ||
        o.Payment_Terms__c != old.Payment_Terms__c ||
        o.Amount != old.Amount;
      if (changed && (o.Payment_Terms__c != null || old != null)) {
        candidates.add(o);
      }
    }
    if (candidates.isEmpty()) {
      return;
    }

    Set<Id> ids = new Map<Id, Opportunity>(candidates).keySet();
    Set<Id> hasPaid = new Set<Id>();
    for (AggregateResult ar : [
      SELECT Opportunity__c opp
      FROM Payment__c
      WHERE Opportunity__c IN :ids AND Status__c = 'Paid'
      GROUP BY Opportunity__c
    ]) {
      hasPaid.add((Id) ar.get('opp'));
    }

    List<Payment__c> toDelete = [
      SELECT Id
      FROM Payment__c
      WHERE
        Opportunity__c IN :ids
        AND Opportunity__c NOT IN :hasPaid
        AND Status__c != 'Paid'
    ];
    delete toDelete;

    List<Payment__c> toInsert = new List<Payment__c>();
    for (Opportunity o : candidates) {
      if (hasPaid.contains(o.Id)) {
        continue;
      }
      Integer n = o.Payment_Terms__c == null ? 0 : o.Payment_Terms__c.intValue();
      if (n < 1 || n > 12) {
        continue;
      }
      toInsert.addAll(build(o, n));
    }
    insert toInsert;
  }

  // Equal split: every term gets round(100/n, 2) percent; the last term takes
  // the rounding remainder so percentages sum to 100 and amounts sum to Amount.
  @TestVisible
  private static List<Payment__c> build(Opportunity o, Integer n) {
    List<Payment__c> res = new List<Payment__c>();
    Decimal basePct = (100.0 / n).setScale(2);
    Decimal total = o.Amount == null ? 0 : o.Amount;
    Decimal pctSum = 0;
    Decimal amtSum = 0;
    for (Integer i = 1; i <= n; i++) {
      Decimal pct = i == n ? 100 - pctSum : basePct;
      Decimal amt = i == n ? total - amtSum : (total * pct / 100).setScale(2);
      pctSum += pct;
      amtSum += amt;
      res.add(
        new Payment__c(
          Opportunity__c = o.Id,
          Term_Number__c = i,
          Percentage__c = pct,
          Amount__c = amt,
          Due_Date__c = Date.today().addDays(30 * (i - 1)),
          Status__c = 'Pending'
        )
      );
    }
    return res;
  }
}
