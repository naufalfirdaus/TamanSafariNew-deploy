trigger ContentDocumentTrigger on ContentDocument (before delete) {
  ContentDocumentTriggerHandler.beforeDelete(Trigger.oldMap);
}