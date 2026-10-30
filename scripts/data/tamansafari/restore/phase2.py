from restore_lib import *
m=idmap()
# --- Pricebook ---
std=query("SELECT Id FROM Pricebook2 WHERE IsStandard=true")[0]['Id']
cust=query("SELECT Id FROM Pricebook2 WHERE Name='B2B Custom Pricebook'")
if cust: cust=cust[0]['Id']
else:
    cust=sf(['data','create','record','-s','Pricebook2','-v',"Name='B2B Custom Pricebook' IsActive=true"])['result']['id']
m['_std']=std; m['_b2b']=cust; save_idmap(m)
b2b=[p for p in load('PricebookEntry') if p['Pricebook2Id']=='01sBh000000mi6nIAA']
stdrows=[{'Id':'s'+p['Id'],'Pricebook2Id':std,'Product2Id':m[p['Product2Id']],'UnitPrice':p['UnitPrice'],'IsActive':True} for p in b2b]
custrows=[{'Id':p['Id'],'Pricebook2Id':cust,'Product2Id':m[p['Product2Id']],'UnitPrice':p['UnitPrice'],'IsActive':True} for p in b2b]
print('PBE std',len(tree_insert('PricebookEntry',stdrows,m)))
print('PBE b2b',len(tree_insert('PricebookEntry',custrows,m)))
