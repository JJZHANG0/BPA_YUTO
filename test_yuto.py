import json
import os
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from unittest.mock import patch

from intelligence import validate_focus
from ingest import Announcement, parse_record, seed
from model import FIELDS, analyze, match
from server import Handler


class YutoTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder = tempfile.TemporaryDirectory()
        cls.env = patch.dict(os.environ,{'YUTO_DB':cls.folder.name+'/test.sqlite','YUTO_ADMIN_TOKEN':'test-only'})
        cls.env.start()
        seed()
        seed()
        cls.server = ThreadingHTTPServer(('127.0.0.1',0),Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever,daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.thread.join()
        cls.server.server_close()
        cls.env.stop()
        cls.folder.cleanup()

    def request(self,path,body=None,admin=False):
        headers = {'Content-Type':'application/json'}
        if admin:
            headers['Authorization'] = 'Bearer test-only'
        data = json.dumps(body).encode() if body is not None else None
        request = Request(f'http://127.0.0.1:{self.server.server_port}'+path,data=data,headers=headers)
        with urlopen(request,timeout=5) as response:
            return json.load(response)

    def test_static_entry_points(self):
        base = f'http://127.0.0.1:{self.server.server_port}'
        for path, marker in (('/',b'YUTO'),('/app.js',b'function render'),('/hero.jpg',b'\xff\xd8'),('/admin.html',b'admin.js')):
            with urlopen(base+path,timeout=5) as response:
                self.assertIn(marker,response.read())

    def test_catalog_and_source_isolation(self):
        self.assertEqual(len(self.request('/api/provinces')),31)
        items = self.request('/api/attractions')
        self.assertGreaterEqual(len(items),100)
        self.assertEqual(len({a['name'] for a in items}),len(items))
        item = items[0]
        for suffix in ('','/analysis','/score'):
            result = json.dumps(self.request('/api/attractions/'+item['id']+suffix))
            for internal in ('mct.gov','source','VERIFIED','UNKNOWN'):
                self.assertNotIn(internal,result)
        self.assertEqual(item['grade'],'5A')
        self.assertIsNone(item['score'])
        self.assertEqual(item['coverage'],0)
        with self.assertRaises(HTTPError) as error:
            self.request('/api/admin')
        self.assertEqual(error.exception.code,401)
        self.assertGreaterEqual(len(self.request('/api/admin',admin=True)['sources']),5)

    def test_score_and_match(self):
        self.assertEqual(analyze(dict.fromkeys(FIELDS,100))['score'],100)
        self.assertIsNone(analyze({'stairs':100})['score'])
        self.assertTrue(match({'accessible_route':0},{'aid':'轮椅'},'')['exclude'])
        self.assertFalse(match({'accessible_route':0},{'walk':'短距离'},'')['exclude'])

    def test_search_and_itinerary(self):
        found = self.request('/api/recommendations',{'query':'我想去浙江旅游，最好不要爬山'})
        self.assertTrue(found)
        self.assertTrue(all(a['province']=='浙江' for a in found))
        self.assertIn('坡度需要提前确认',found[0]['reminders'])
        selected = found[0]
        plan = self.request('/api/trips',{'province':selected['province'],'city':selected['city'],'days':3,
                                         'people':2,'pace':'轻松','first':selected['id']})
        self.assertEqual(len(plan),3)
        self.assertEqual(plan[0]['id'],selected['id'])
        self.assertIsNone(plan[1]['id'])

    def test_admin_evidence(self):
        target = self.request('/api/attractions')[-1]
        path = '/api/admin/evidence'
        data = {'id':target['id'],'status':'VERIFIED','field':'stairs','value':0,'source':'https://example.org/test-evidence'}
        self.assertTrue(self.request(path,data,admin=True)['ok'])
        detail = self.request('/api/attractions/'+target['id']+'/analysis')
        self.assertIn('台阶',detail['challenges'])
        query = self.request('/api/recommendations',{'query':target['name'],'profile':{'stairs':'尽量避免'}})
        self.assertNotIn(target['id'],[item['id'] for item in query])

    def test_model_focus_validation(self):
        self.assertEqual(validate_focus({'focus':['stairs'],'pace':'light'})['focus'],['stairs'])
        with self.assertRaises(ValueError):
            validate_focus({'focus':['fictional_condition'],'pace':'light'})

    def test_announcement_markup(self):
        document = Announcement()
        document.feed('<div>1. 浙江省金华市<span>双龙风景旅游区</span></div><p>特此公告</p>')
        self.assertIn(('浙江','金华市','双龙风景旅游区'),[parse_record(line) for line in document.lines])


if __name__ == '__main__':
    unittest.main()
