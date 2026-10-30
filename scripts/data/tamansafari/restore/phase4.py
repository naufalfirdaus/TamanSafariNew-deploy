from restore_lib import *
m=idmap(); final=json.load(open('final_opps.json'))
cur={r['Id']:r for r in query("SELECT Id,Amount FROM Opportunity")}
diff=[(final[o]['Name'][:30],final[o]['Amount'],cur[m[o]]['Amount']) for o in final if float(cur[m[o]]['Amount'] or 0)!=float(final[o]['Amount'] or 0)]
print('Amount berbeda:',len(diff),diff[:5])
# Termin pembayaran -> trigger buat Payment__c
rows=[{'Id':m[o],'Payment_Terms__c':f['Payment_Terms__c']} for o,f in final.items() if f.get('Payment_Terms__c')]
print('terms update',bulk_update('Opportunity',rows))
pay=query("SELECT Opportunity__c,COUNT(Id) c FROM Payment__c GROUP BY Opportunity__c")
print('opp dgn payment:',len(pay),'total payment:',sum(p['c'] for p in pay),'(backup 57)')
