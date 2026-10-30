trigger OpportunityPaymentTrigger on Opportunity(after insert, after update) {
  OpportunityPaymentScheduler.sync(Trigger.new, Trigger.oldMap);
}
