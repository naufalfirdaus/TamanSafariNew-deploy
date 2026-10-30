trigger LeadTrigger on Lead (after insert, after update) {
  if (Trigger.isAfter) {
    if (Trigger.isInsert) {
      TargetAddressGeocodeHandler.handleLeadAfterInsert(Trigger.new);
    } else if (Trigger.isUpdate) {
      TargetAddressGeocodeHandler.handleLeadAfterUpdate(Trigger.new, Trigger.oldMap);
    }
  }
}