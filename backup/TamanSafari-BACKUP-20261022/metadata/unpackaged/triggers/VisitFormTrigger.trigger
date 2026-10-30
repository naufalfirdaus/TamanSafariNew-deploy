trigger VisitFormTrigger on Visit_Form__c(before update, after update) {
  if (Trigger.isBefore) {
    VisitFormTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
  } else {
    VisitFormTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
  }
}