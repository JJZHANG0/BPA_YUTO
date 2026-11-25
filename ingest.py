"""Import ministry announcement records and run a persistent collection worker."""
import argparse
import hashlib
import json
import re
import time
from html.parser import HTMLParser
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener
from urllib.robotparser import RobotFileParser
from model import ROOT, PROVINCES, connect, initialize

BASE = 'https://zwgk.mct.gov.cn'
PREFIX = BASE + '/zfxxgkml/zykf/'
AGENT = 'YUTO-Catalog/1.0'
REGION_SUFFIX = {'内蒙古':'自治区','广西':'壮族自治区','宁夏':'回族自治区','新疆':'维吾尔自治区','西藏':'自治区'}
MUNICIPALITIES = {'北京','上海','天津','重庆'}


class Announcement(HTMLParser):
    BLOCKS = {'p','div','li','br'}

    def __init__(self):
        super().__init__()
        self.lines = []
        self.parts = []

    def flush(self):
        if self.parts:
            self.lines.append(''.join(self.parts).strip())
            self.parts.clear()

    def handle_starttag(self, tag, attrs):
        if tag in self.BLOCKS:
            self.flush()

    def handle_data(self, data):
        self.parts.append(data)

    def handle_endtag(self, tag):
        if tag in self.BLOCKS:
            self.flush()


def parse_record(line):
    if '黄河壶口瀑布旅游区（陕西省延安市·山西省临汾市）' in line:
        return ('陕西','延安市','黄河壶口瀑布旅游区')
    line = re.sub(r'^\s*\d+\s*[.．、]\s*', '', line).strip().rstrip('；。')
    for province in PROVINCES:
        prefix = province + REGION_SUFFIX.get(province, '市' if province in MUNICIPALITIES else '省')
        if not line.startswith(prefix):
            continue
        tail = line[len(prefix):]
        if province in MUNICIPALITIES:
            city, name = province + '市', tail
        else:
            parts = re.match(r'^(.{2,14}?(?:自治州|地区|市|盟|州))(.+)$', tail)
            if not parts:
                return
            city, name = parts.groups()
        if len(name) in range(3, 65) and re.search(r'景区|旅游区|游览区|风景区|公园|度假区|博物馆|古城|古镇', name):
            return (province, city, name)


def import_records(db, url, records):
    db.execute('INSERT OR IGNORE INTO sources(url) VALUES (?)', (url,))
    for province, city, name in records:
        db.execute('INSERT OR IGNORE INTO cities VALUES (?,?)', (province, city))
        key = hashlib.sha256(('|'.join((province,city,name))).encode()).hexdigest()[:20]
        db.execute("INSERT OR IGNORE INTO attractions(id,name,province,city,grade) VALUES (?,?,?,?, '5A')",
                   (key,name,province,city))
        db.execute("INSERT OR IGNORE INTO evidence(attraction,field,value,status,source) VALUES (?,?,?,'VERIFIED',?)",
                   (key,'grade',json.dumps('5A'),url))


def seed():
    initialize()
    file = ROOT / 'data/announcements.json'
    if file.exists():
        with connect() as db:
            for url, records in json.loads(file.read_text()).items():
                import_records(db,url,records)


def queue(db, url):
    if not re.fullmatch(re.escape(PREFIX) + r'\d{6}/t\d{8}_\d+\.html',url):
        raise ValueError('请输入文旅部公开公告网址')
    db.execute('INSERT OR IGNORE INTO sources(url) VALUES (?)', (url,))
    db.execute('INSERT OR IGNORE INTO jobs(url) VALUES (?)', (url,))


class MinistryRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not newurl.startswith(BASE + '/'):
            raise ValueError('unexpected redirect host')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch(url):
    with build_opener(MinistryRedirects()).open(Request(url,headers={'User-Agent':AGENT}),timeout=20) as response:
        if not response.url.startswith(BASE + '/'):
            raise ValueError('unexpected host')
        data = response.read(2_000_001)
        if len(data) > 2_000_000:
            raise ValueError('response too large')
        return data.decode(response.headers.get_content_charset() or 'utf-8',errors='replace')


def scrape(url):
    robots = RobotFileParser()
    try:
        robots.parse(fetch(BASE + '/robots.txt').splitlines())
    except HTTPError as error:
        if error.code not in (404,410):
            raise
        robots.parse([])
    if not robots.can_fetch(AGENT,url):
        raise ValueError('robots.txt does not permit collection')
    page = Announcement()
    html = fetch(url)
    page.feed(html)
    page.flush()
    title = re.search(r'<title[^>]*>(.*?)</title>',html,re.S|re.I)
    if not title or '公示' in title[1] or '公告' not in title[1] or not re.search(r'正式确定为国家5A级|确定以下.{0,30}国家5A级', html):
        raise ValueError('not a final 5A announcement')
    records = sorted({record for line in page.lines if (record := parse_record(line))})
    if not records:
        raise ValueError('no supported records found')
    return records


def work():
    with connect() as db:
        db.execute('BEGIN IMMEDIATE')
        job = db.execute("SELECT * FROM jobs WHERE state IN ('PENDING','RETRYING') OR (state='RUNNING' AND updated < datetime('now','-5 minutes')) ORDER BY id LIMIT 1").fetchone()
        if job is None:
            return False
        db.execute("UPDATE jobs SET state='RUNNING',attempts=attempts+1,updated=CURRENT_TIMESTAMP WHERE id=?", (job['id'],))
    try:
        records = scrape(job['url'])
        with connect() as db:
            import_records(db,job['url'],records)
            db.execute("UPDATE jobs SET state='COMPLETED',progress=?,updated=CURRENT_TIMESTAMP WHERE id=?", (len(records),job['id']))
            db.execute('INSERT INTO logs(job,message) VALUES (?,?)',(job['id'],f'Imported {len(records)} records'))
    except Exception as error:
        with connect() as db:
            db.execute("UPDATE jobs SET state='FAILED',updated=CURRENT_TIMESTAMP WHERE id=?", (job['id'],))
            db.execute('INSERT INTO logs(job,message) VALUES (?,?)',(job['id'],str(error)))
    return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--queue',action='append',default=[])
    parser.add_argument('--worker',action='store_true')
    args = parser.parse_args()
    seed()
    with connect() as db:
        for url in args.queue:
            queue(db,url)
    if args.worker:
        while True:
            time.sleep(2 if work() else 5)
    else:
        while work():
            pass
