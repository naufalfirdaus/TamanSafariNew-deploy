from restore_lib import *
m=idmap()
# Account (skip sampel entitlement bawaan SDO)
acc=[a for a in load('Account') if a['Name']!='Sample Account for Entitlements']
print('Account',len(tree_insert('Account',acc,m)))
con=load('Contact')
for c in con: c['AccountId']=m.get(c['AccountId']) if c.get('AccountId') else None
print('Contact',len(tree_insert('Contact',con,m)))
print('Lead',len(tree_insert('Lead',load('Lead'),m)))
pe=load('PricebookEntry'); b2b=[p for p in pe if p['Pricebook2Id']=='01sBh000000mi6nIAA']
need={p['Product2Id'] for p in b2b}
prod=[p for p in load('Product2') if p['Id'] in need]
print('Product2',len(prod),len(tree_insert('Product2',prod,m)))
