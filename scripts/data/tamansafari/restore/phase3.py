from restore_lib import *
m=idmap()
OWN={'005Bh000006MpN0IAK':'00571000009vRntAAE','005Bh000006LFYbIAO':'00571000009wHXxAAM'}
m.update(OWN); save_idmap(m)
rt=query("SELECT Id FROM RecordType WHERE SobjectType='Opportunity' AND DeveloperName='Taman_Safari'")[0]['Id']
ops=load('Opportunity'); final={}
for o in ops:
    final[o['Id']]=dict(o)
    o['RecordTypeId']=rt; o['AccountId']=m[o['AccountId']]; o['OwnerId']=OWN[o['OwnerId']]
    o['StageName']='Qualification'; o['Payment_Terms__c']=None; o['PO_Number__c']=None; o.pop('ForecastCategoryName',None)
print('Opp',len(tree_insert('Opportunity',ops,m)))
li=load('OpportunityLineItem')
for l in li:
    l['OpportunityId']=m[l['OpportunityId']]; l['PricebookEntryId']=m[l['PricebookEntryId']]; l['Product2Id']=None
    l['TotalPrice']=None  # UnitPrice dan TotalPrice tidak boleh bersamaan
print('OLI',len(tree_insert('OpportunityLineItem',li,m)))
json.dump(final,open('final_opps.json','w'))
