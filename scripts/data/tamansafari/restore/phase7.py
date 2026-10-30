from restore_lib import *
m=idmap()
B='/Users/macbooklks1/Downloads/TamanSafari-BACKUP-20260916/data/siap-impor/'
rt=query("SELECT Id FROM RecordType WHERE SobjectType='Account' AND DeveloperName='Account_Pertner_TS'")[0]['Id']
accs=[a for a in json.load(open(B+'Account.json'))['records'] if a.get('Type')=='Partner' or a['Name']=='Cipta Travel, PT']
rows=[]; 
for a in accs:
    r={k:v for k,v in a.items() if k!='attributes'}; r['Id']='old_'+a['attributes']['referenceId']; r['RecordTypeId']=rt; rows.append(r)
print('Account partner',len(rows),len(tree_insert('Account',rows,m)))
for n in ['Affiliate_Code__c','Commission_Statement__c','Redemption__c']:
    rs=json.load(open(B+n+'.json'))['records']; out=[]
    for i,a in enumerate(rs):
        r={k:v for k,v in a.items() if k!='attributes'}; r['Id']=f'old_{n}{i}'
        r['Afiliator__c']=m['old_'+a['Afiliator__c'][1:]]; out.append(r)
    print(n,len(out),len(tree_insert(n,out,m)))
