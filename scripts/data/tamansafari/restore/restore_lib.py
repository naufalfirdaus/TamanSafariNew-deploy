"""Pustaka kecil untuk restore data TamanSafari 1022 ke scratch org baru.
Semua panggilan sf memakai -o TamanSafari. Peta Id lama -> baru disimpan di idmap.json."""
import json, os, subprocess, tempfile

ORG = 'TamanSafari'
D = '/Users/macbooklks1/Downloads/TamanSafariNew-deploy/backup/TamanSafari-BACKUP-20261022/data/'
S = os.path.dirname(os.path.abspath(__file__))
MAP = S + '/idmap.json'
PROJ = '/Users/macbooklks1/Downloads/TamanSafariNew-deploy'


def sf(args, check=True):
    r = subprocess.run(['sf'] + args + ['-o', ORG, '--json'], capture_output=True, text=True, cwd=PROJ)
    try:
        j = json.loads(r.stdout)
    except Exception:
        raise RuntimeError(r.stdout[-800:] + r.stderr[-800:])
    if check and j.get('status') != 0:
        raise RuntimeError(json.dumps(j)[:1800])
    return j


def load(name):
    return json.load(open(D + name + '.clean.json'))


def idmap():
    return json.load(open(MAP)) if os.path.exists(MAP) else {}


def save_idmap(m):
    json.dump(m, open(MAP, 'w'), indent=1)


_desc = {}


def createable(obj):
    if obj not in _desc:
        j = sf(['sobject', 'describe', '-s', obj])
        _desc[obj] = {f['name']: f for f in j['result']['fields'] if f['createable']}
    return _desc[obj]


def tree_insert(obj, rows, m):
    """Insert rows (dict, key 'Id' = Id lama) via sf data import tree; kembalikan {Id lama: Id baru}."""
    ok = createable(obj)
    recs = []
    for r in rows:
        rec = {'attributes': {'type': obj, 'referenceId': 'r' + r['Id']}}
        for k, v in r.items():
            if k == 'Id' or v is None or k not in ok:
                continue
            rec[k] = v
        recs.append(rec)
    out = {}
    for i in range(0, len(recs), 150):
        chunk = recs[i:i + 150]
        fn = tempfile.mktemp(suffix='.json', dir=S)
        json.dump({'records': chunk}, open(fn, 'w'))
        j = sf(['data', 'import', 'tree', '-f', fn], check=False)
        os.remove(fn)
        if j.get('status') != 0:
            raise RuntimeError(obj + ' gagal: ' + json.dumps(j)[:2500])
        for res in j['result']:
            out[res['refId'][1:]] = res['id']
    m.update(out)
    save_idmap(m)
    return out


def query(soql):
    j = sf(['data', 'query', '-q', soql])
    return j['result']['records']


def bulk_update(obj, rows):
    """rows: list of dict berisi 'Id' (Id baru) + field yang diubah."""
    import csv
    cols = []
    for r in rows:
        for k in r:
            if k not in cols:
                cols.append(k)
    fn = tempfile.mktemp(suffix='.csv', dir=S)
    with open(fn, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=cols, lineterminator="\n")
        w.writeheader()
        for r in rows:
            w.writerow({k: ('' if r.get(k) is None else r[k]) for k in cols})
    j = sf(['data', 'update', 'bulk', '-s', obj, '-f', fn, '-w', '10'], check=False)
    os.remove(fn)
    res = j.get('result') or {}
    if j.get('status') != 0 or res.get('numberRecordsFailed'):
        raise RuntimeError(obj + ' update gagal: ' + json.dumps(j)[:2500])
    return res.get('numberRecordsProcessed')
