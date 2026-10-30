trigger AccountTrigger on Account (after insert, after update) {
  if (Trigger.isAfter) {
    if (Trigger.isInsert) {
      TargetAddressGeocodeHandler.handleAccountAfterInsert(Trigger.new);
    } else if (Trigger.isUpdate) {
      TargetAddressGeocodeHandler.handleAccountAfterUpdate(Trigger.new, Trigger.oldMap);
    }
  }
}