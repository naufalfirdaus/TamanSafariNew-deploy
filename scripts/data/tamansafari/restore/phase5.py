from restore_lib import *
m=idmap(); final=json.load(open('final_opps.json'))
new={(r['Opportunity__c'],int(r['Term_Number__c'])):r for r in query("SELECT Id,Opportunity__c,Term_Number__c,Amount__c,Due_Date__c,Status__c FROM Payment__c")}
rows=[];diff=0
for p in load('Payment__c'):
    k=(m[p['Opportunity__c']],int(p['Term_Number__c'])); n=new[k]
    if float(n['Amount__c'])!=float(p['Amount__c']) or n['Due_Date__c']!=p['Due_Date__c'] or n['Status__c']!=p['Status__c']: diff+=1
    rows.append({'Id':n['Id'],'Amount__c':p['Amount__c'],'Due_Date__c':p['Due_Date__c'],'Status__c':p['Status__c']})
print('payment beda dari backup:',diff,'dari',len(rows))
print('payments',bulk_update('Payment__c',rows))
# stage non-Closed Won dulu
st=[{'Id':m[o],'StageName':f['StageName'],'CloseDate':f['CloseDate']} for o,f in final.items() if f['StageName']!='Closed Won']
print('stage',bulk_update('Opportunity',st))
cw=[{'Id':m[o],'StageName':'Closed Won','CloseDate':f['CloseDate'],'PO_Number__c':f['PO_Number__c']} for o,f in final.items() if f['StageName']=='Closed Won']
print('closed won',len(cw),bulk_update('Opportunity',cw))
