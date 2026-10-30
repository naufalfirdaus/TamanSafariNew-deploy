from restore_lib import *
m=idmap()
def fix(rows,kind):
    drop=0
    for r in rows:
        r.pop('CreatedDate',None)
        r['OwnerId']=m[r['OwnerId']]
        w=r.get('WhatId')
        if w: 
            r['WhatId']=m.get(w); drop+= (r['WhatId'] is None)
        w=r.get('WhoId')
        if w: r['WhoId']=m.get(w)
    print(kind,'relasi WhatId tak terpetakan:',drop)
    return rows
ev=fix(load('Event'),'Event'); print('Event',len(tree_insert('Event',ev,m)))
tk=fix(load('Task'),'Task'); print('Task',len(tree_insert('Task',tk,m)))
ft=query("SELECT Id FROM ForecastingType WHERE DeveloperName='OpportunityRevenue'")[0]['Id']
q=load('ForecastingQuota')
for r in q: r['QuotaOwnerId']=m[r['QuotaOwnerId']]; r['ForecastingTypeId']=ft
print('Quota',len(tree_insert('ForecastingQuota',q,m)))
