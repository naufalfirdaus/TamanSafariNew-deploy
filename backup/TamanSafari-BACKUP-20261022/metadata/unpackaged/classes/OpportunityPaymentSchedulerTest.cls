@IsTest
private class OpportunityPaymentSchedulerTest {
  private static Opportunity mk(Decimal amt, Integer terms) {
    Opportunity o = new Opportunity(
      Name = 'Pay Test',
      StageName = 'Qualification',
      CloseDate = Date.today().addDays(30),
      Amount = amt,
      Payment_Terms__c = terms
    );
    insert o;
    return o;
  }

  @IsTest
  static void splitsEquallyWithRemainderOnLastTerm() {
    Opportunity o = mk(100, 3);
    List<Payment__c> p = [
      SELECT Term_Number__c, Percentage__c, Amount__c
      FROM Payment__c
      WHERE Opportunity__c = :o.Id
      ORDER BY Term_Number__c
    ];
    Assert.areEqual(3, p.size());
    Assert.areEqual(33.33, p[0].Amount__c);
    Assert.areEqual(33.34, p[2].Amount__c);
    Assert.areEqual(100.00, p[0].Percentage__c + p[1].Percentage__c + p[2].Percentage__c);
    Opportunity r = [SELECT Total_Payment_Scheduled__c, Payment_Gap__c FROM Opportunity WHERE Id = :o.Id];
    Assert.areEqual(100, r.Total_Payment_Scheduled__c);
    Assert.areEqual(0, r.Payment_Gap__c);
  }

  @IsTest
  static void regeneratesWhenTermsChange() {
    Opportunity o = mk(1000, 2);
    o.Payment_Terms__c = 4;
    update o;
    Assert.areEqual(4, [SELECT COUNT() FROM Payment__c WHERE Opportunity__c = :o.Id]);
  }

  @IsTest
  static void keepsScheduleOnceAPaymentIsPaid() {
    Opportunity o = mk(1000, 2);
    Payment__c first = [SELECT Id FROM Payment__c WHERE Opportunity__c = :o.Id AND Term_Number__c = 1];
    first.Status__c = 'Paid';
    update first;
    o.Amount = 2000;
    update o;
    Assert.areEqual(2, [SELECT COUNT() FROM Payment__c WHERE Opportunity__c = :o.Id]);
    Assert.areEqual(500, [SELECT Total_Paid__c FROM Opportunity WHERE Id = :o.Id].Total_Paid__c);
  }

  @IsTest
  static void noTermsMeansNoPayments() {
    Opportunity o = mk(1000, null);
    Assert.areEqual(0, [SELECT COUNT() FROM Payment__c WHERE Opportunity__c = :o.Id]);
  }
}