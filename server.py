import hmac
import json
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit
from ingest import queue, seed
from model import ROOT, FIELDS, analyze, connect, destination_analysis, match, verified

NOTICE = '部分游览条件尚未确认。出发前请向景区确认开放时间、步道和所需设施。'


def search(db, params):
    rows = db.execute('SELECT * FROM attractions ORDER BY province,city,name').fetchall()
    return [row for row in rows if all(not params.get(k) or row[k] == params[k] for k in ('province','city'))
            and (not params.get('q') or params['q'] in row['name'] + row['province'] + row['city'])]


def public(db, row, detail=False):
    item = {key:row[key] for key in ('id','name','province','city','grade','category','lat','lon')}
    score = analyze(verified(db,row['id']))
    score['rating'] = score.pop('grade')
    item.update(score)
    item['notice'] = NOTICE
    if not detail:
        item.pop('dimensions')
    return item


class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs):
        super().__init__(*args,directory=str(ROOT / 'public'),**kwargs)

    def send_json(self,value,status=200):
        data = json.dumps(value,ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header('Content-Type','application/json; charset=utf-8')
        self.send_header('Cache-Control','no-store')
        self.send_header('X-Content-Type-Options','nosniff')
        self.send_header('Content-Length',str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def admin(self):
        secret = os.getenv('YUTO_ADMIN_TOKEN')
        return secret and hmac.compare_digest(self.headers.get('Authorization','').encode(), ('Bearer '+secret).encode())

    def do_GET(self):
        path = urlsplit(self.path)
        if not path.path.startswith('/api/'):
            if path.path not in ('/', '/index.html','/styles.css','/app.js','/hero.jpg','/admin.html','/admin.js'):
                self.send_error(404)
                return
            return super().do_GET()
        params = {key:values[0] for key,values in parse_qs(path.query).items()}
        with connect() as db:
            if path.path == '/api/provinces':
                self.send_json([dict(row) for row in db.execute('SELECT p.name, count(a.id) AS count FROM provinces p LEFT JOIN attractions a ON a.province=p.name GROUP BY p.name')])
            elif path.path == '/api/cities':
                self.send_json([dict(row) for row in db.execute('SELECT city AS name, count(*) AS count FROM attractions WHERE province=? GROUP BY city ORDER BY count DESC,city',(params.get('province'),))])
            elif path.path == '/api/attractions':
                self.send_json([public(db,row) for row in search(db,params)])
            elif path.path.startswith('/api/attractions/'):
                parts = path.path.split('/')
                row = db.execute('SELECT * FROM attractions WHERE id=?',(parts[3],)).fetchone()
                if row and (len(parts) == 4 or (len(parts) == 5 and parts[4] in ('score','analysis'))):
                    item = public(db,row,True)
                    if len(parts) == 5 and parts[4] == 'score':
                        item = {k:item[k] for k in ('score','rating','coverage','confidence','dimensions')}
                    if len(parts) == 5 and parts[4] == 'analysis':
                        item = {**destination_analysis(db,row['id']),'notice':NOTICE}
                        item.pop('version')
                    self.send_json(item)
                else:
                    self.send_json({'error':'未找到景区'},404)
            elif path.path == '/api/admin/evidence':
                if not self.admin():
                    return self.send_json({'error':'需要运营授权'},401)
                records = db.execute('SELECT * FROM evidence WHERE attraction=? ORDER BY field,source',(params.get('id'),))
                self.send_json({'records':[dict(row) for row in records],'fields':FIELDS})
            elif path.path == '/api/admin':
                if not self.admin():
                    return self.send_json({'error':'需要运营授权'},401)
                counts = {k:db.execute('SELECT count(*) FROM '+k).fetchone()[0] for k in ('provinces','cities','attractions','images','analyses')}
                self.send_json({'counts':counts,'jobs':[dict(row) for row in db.execute('SELECT * FROM jobs ORDER BY id DESC LIMIT 50')],
                                'logs':[dict(row) for row in db.execute('SELECT * FROM logs ORDER BY rowid DESC LIMIT 50')],
                                'sources':[dict(row) for row in db.execute('SELECT * FROM sources')]})
            else:
                self.send_json({'error':'接口不存在'},404)

    def do_POST(self):
        path = urlsplit(self.path).path
        try:
            length = int(self.headers.get('Content-Length','0'))
            if not 0 < length <= 16000:
                raise ValueError()
            body = json.loads(self.rfile.read(length))
            if not isinstance(body,dict):
                raise ValueError()
            with connect() as db:
                if path == '/api/recommendations':
                    query = str(body.get('query',''))[:250]
                    profile = body.get('profile') or {}
                    if not isinstance(profile,dict):
                        raise ValueError()
                    rows = search(db,{'province':body.get('province'),'city':body.get('city')})
                    named = [r for r in rows if r['name'] in query or r['city'] in query or r['city'].removesuffix('市') in query or r['province'] in query]
                    candidates = named or (rows if not query or body.get('province') or any(word in query for word in ('旅行','旅游','出游','台阶','轮椅','老人','爬山','走走','爬坡','少走')) else [])
                    results = []
                    for row in candidates:
                        fit = match(verified(db,row['id']),profile,query)
                        if not fit['exclude']:
                            results.append({**public(db,row),'match':fit['score'],'reminders':fit['reminders']})
                    self.send_json(sorted(results,key=lambda r: -(r['match'] if r['match'] is not None else -1))[:30])
                elif path == '/api/trips':
                    days = int(body.get('days',1))
                    people = int(body.get('people',1))
                    if not 1 <= days <= 14 or not 1 <= people <= 30:
                        raise ValueError()
                    rows = search(db,{'province':body.get('province'),'city':body.get('city')})
                    ids = body.get('ids') or []
                    if not isinstance(ids,list):
                        raise ValueError()
                    first = body.get('first')
                    if first:
                        rows.sort(key=lambda row: row['id'] != first)
                    preferences = body.get('profile') or {}
                    if not isinstance(preferences,dict):
                        raise ValueError()
                    rows = [row for row in rows if not match(verified(db,row['id']),preferences,'')['exclude']]
                    if ids:
                        rows = [r for r in rows if r['id'] in ids]
                    elif rows and not body.get('city'):
                        rows = [r for r in rows if r['city'] == rows[0]['city'] and r['province'] == rows[0]['province']]
                    entries = []
                    for i in range(days):
                        index = i // 2 if body.get('pace') == '轻松' else i
                        available = body.get('pace') != '轻松' or i % 2 == 0
                        item = rows[index] if available and index < len(rows) else None
                        entries.append({'name':item['name'] if item else '自由活动与休息','id':item['id'] if item else None,
                                        'note':'只安排一处景区，预留午间休息。请确认开放时间、交通耗时和步行条件。' if item else '保留弹性，按当天体力安排。'})
                    self.send_json(entries)
                elif path == '/api/admin/evidence':
                    if not self.admin():
                        return self.send_json({'error':'需要运营授权'},401)
                    attraction, field, source = body['id'],body['field'],body['source']
                    status = body['status']
                    value = float(body['value'])
                    if not db.execute('SELECT 1 FROM attractions WHERE id=?',(attraction,)).fetchone() or field not in FIELDS:
                        raise ValueError()
                    if status not in ('VERIFIED','PARTIAL','INFERRED','UNKNOWN') or not 0 <= value <= 100:
                        raise ValueError()
                    parsed = urlsplit(source)
                    if parsed.scheme != 'https' or not parsed.hostname or parsed.username:
                        raise ValueError()
                    db.execute('INSERT OR IGNORE INTO sources(url) VALUES (?)',(source,))
                    db.execute('INSERT INTO evidence(attraction,field,value,status,source) VALUES (?,?,?,?,?) ON CONFLICT(attraction,field,source) DO UPDATE SET value=excluded.value,status=excluded.status,updated=CURRENT_TIMESTAMP',
                               (attraction,field,json.dumps(value),status,source))
                    result = destination_analysis(db,attraction)
                    db.execute('INSERT INTO analyses(attraction,version,result) VALUES (?,?,?) ON CONFLICT(attraction,version) DO UPDATE SET result=excluded.result,created=CURRENT_TIMESTAMP',
                               (attraction,result['version'],json.dumps(result,ensure_ascii=False)))
                    db.commit()
                    self.send_json({'ok':True})
                elif path == '/api/admin/jobs':
                    if not self.admin():
                        return self.send_json({'error':'需要运营授权'},401)
                    if 'url' in body:
                        queue(db,body['url'])
                    else:
                        previous,next_state = {'retry':('FAILED','RETRYING'),'pause':('PENDING','PAUSED'),'resume':('PAUSED','PENDING')}[body['action']]
                        db.execute('UPDATE jobs SET state=?, updated=CURRENT_TIMESTAMP WHERE id=? AND state=?',(next_state,int(body['id']),previous))
                    db.commit()
                    self.send_json({'ok':True})
                else:
                    self.send_json({'error':'接口不存在'},404)
        except (ValueError,TypeError,KeyError):
            self.send_json({'error':'请检查输入内容'},400)


if __name__ == '__main__':
    seed()
    port = int(os.getenv('PORT', '8000'))
    print(f'YUTO http://127.0.0.1:{port}', flush=True)
    ThreadingHTTPServer((os.getenv('YUTO_HOST','127.0.0.1'), port),Handler).serve_forever()
