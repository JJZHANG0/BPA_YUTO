"""Optional multimodal evidence prioritization for operators."""
import argparse
import json
import os
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from model import FIELDS, connect, verified
from ingest import seed

VERSION = 'model-focus-1'


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def validate_focus(result):
    if not isinstance(result,dict) or set(result) != {'focus','pace'}:
        raise ValueError('模型返回格式无效')
    focus, pace = result['focus'], result['pace']
    if not isinstance(focus,list) or not 1 <= len(focus) <= 4 or any(not isinstance(key,str) or key not in FIELDS for key in focus):
        raise ValueError('模型返回了不支持的指标')
    if pace not in ('light','moderate'):
        raise ValueError('模型返回了不支持的游览节奏')
    return {'focus':list(dict.fromkeys(focus)), 'pace':pace}


def analyze_with_model(attraction_id):
    endpoint = os.getenv('YUTO_MODEL_ENDPOINT','')
    api_key = os.getenv('YUTO_MODEL_KEY')
    model = os.getenv('YUTO_MODEL_NAME')
    parsed = urlsplit(endpoint)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or not api_key or not model:
        raise ValueError('请先配置模型的 HTTPS 接口、密钥和名称')
    with connect() as db:
        attraction = db.execute('SELECT name,province,city,grade,category FROM attractions WHERE id=?',(attraction_id,)).fetchone()
        if not attraction:
            raise ValueError('未找到景区')
        values = verified(db,attraction_id)
        images = [row['path'] for row in db.execute("SELECT path FROM images WHERE attraction=? AND path LIKE 'https://%' AND license <> '' LIMIT 3",(attraction_id,))]
    evidence = {'destination':dict(attraction),'verified':values,'checklist':FIELDS}
    content = [{'type':'text','text':json.dumps(evidence,ensure_ascii=False)}]
    content.extend({'type':'image_url','image_url':{'url':url}} for url in images)
    body = {'model':model,'response_format':{'type':'json_object'},'messages':[
        {'role':'system','content':'为银发旅行者安排出行核对重点。仅返回 JSON 对象，字段 focus 为 checklist 中 1 至 4 个键，pace 仅为 light 或 moderate。图片只能提示需要核对的项目，不能核实设施、步道或地形。不要输出分数、解释或任何事实判断。'},
        {'role':'user','content':content}
    ]}
    request = Request(endpoint,data=json.dumps(body,ensure_ascii=False).encode(),
                      headers={'Authorization':'Bearer '+api_key,'Content-Type':'application/json'})
    with build_opener(NoRedirect()).open(request,timeout=35) as response:
        payload = response.read(500_001)
    if len(payload) > 500_000:
        raise ValueError('模型响应过大')
    data = json.loads(payload)
    result = validate_focus(json.loads(data['choices'][0]['message']['content']))
    with connect() as db:
        db.execute('INSERT INTO analyses(attraction,version,result) VALUES (?,?,?) ON CONFLICT(attraction,version) DO UPDATE SET result=excluded.result,created=CURRENT_TIMESTAMP',
                   (attraction_id,VERSION,json.dumps(result,ensure_ascii=False)))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='生成景区出行核对重点')
    parser.add_argument('attraction_id')
    args = parser.parse_args()
    seed()
    print(json.dumps(analyze_with_model(args.attraction_id),ensure_ascii=False))
