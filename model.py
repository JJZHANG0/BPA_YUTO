import json
import os
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROVINCES = '北京 天津 河北 山西 内蒙古 辽宁 吉林 黑龙江 上海 江苏 浙江 安徽 福建 江西 山东 河南 湖北 湖南 广东 广西 海南 重庆 四川 贵州 云南 西藏 陕西 甘肃 青海 宁夏 新疆'.split()
DIMENSIONS = {
    '无障碍便利性': (25, {'entrance':'无障碍入口','accessible_toilet':'无障碍卫生间','accessible_route':'无障碍游览路线','wheelchair':'轮椅使用条件'}),
    '步行及体力负担': (20, {'distance':'步行距离','slope':'坡度','stairs':'台阶','surface':'路面'}),
    '休息设施': (15, {'seating':'座椅','rest_points':'休息点','shade':'遮阳','indoors':'室内休息空间'}),
    '交通便利性': (15, {'transit':'公共交通','parking':'停车','shuttle':'景区接驳','internal_transit':'内部交通'}),
    '医疗与安全保障': (15, {'medical':'医疗服务点','first_aid':'急救设施','emergency':'紧急求助','safety':'安全措施'}),
    '配套服务': (10, {'food':'餐饮','toilet':'卫生间','lodging':'住宿','shop':'便利设施'})
}
FIELDS = {key: label for _, fields in DIMENSIONS.values() for key, label in fields.items()}


def connect():
    db = sqlite3.connect(os.getenv('YUTO_DB', str(ROOT / 'data/yuto.sqlite')), timeout=15)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    return db


def initialize():
    with connect() as db:
        db.executescript((ROOT / 'schema.sql').read_text())
        db.executemany('INSERT OR IGNORE INTO provinces VALUES (?)', [(p,) for p in PROVINCES])


def verified(db, attraction_id):
    values = {}
    for row in db.execute("SELECT field,value FROM evidence WHERE attraction=? AND status='VERIFIED'", (attraction_id,)):
        if row['field'] in FIELDS:
            value = json.loads(row['value'])
            if type(value) in (int, float) and 0 <= value <= 100:
                values.setdefault(row['field'], set()).add(value)
    return {key: next(iter(items)) for key, items in values.items() if len(items) == 1}


def analyze(values):
    earned = covered = 0
    breakdown = []
    for name, (weight, fields) in DIMENSIONS.items():
        available = [values[key] for key in fields if key in values]
        coverage = len(available) / len(fields)
        earned += sum(available) * weight / len(fields)
        covered += weight * coverage
        breakdown.append({'name': name, 'score': round(sum(available)/len(available)) if available else None,
                          'conditions': [{'name': label, 'confirmed': key in values} for key, label in fields.items()]})
    score = round(earned / 100) if covered >= 80 and all(item['score'] is not None for item in breakdown) else None
    grade = next((label for minimum, label in [(90,'非常友好'),(80,'比较友好'),(70,'具有一定适应性'),(60,'需要提前规划'),(0,'出行挑战较大')] if score is not None and score >= minimum), None)
    return {'score':score, 'grade':grade, 'coverage':round(covered), 'confidence':'较高' if covered == 100 else '有限',
            'dimensions':breakdown}


def match(values, profile, query):
    needs = set()
    if profile.get('aid') == '轮椅' or '轮椅' in query:
        needs.update(['entrance','accessible_route','accessible_toilet'])
    if profile.get('walk') == '短距离' or '少走' in query:
        needs.add('distance')
    if profile.get('stairs') == '尽量避免' or '台阶' in query:
        needs.add('stairs')
    if profile.get('slope') == '尽量避免' or re.search('不.{0,3}爬山|少爬坡',query):
        needs.add('slope')
    if profile.get('standing') == '需要常休息':
        needs.update(['seating','rest_points'])
    missing = sorted(needs - values.keys())
    available = [values[k] for k in needs if k in values]
    score = round(sum(available) / len(needs)) if needs and not missing else None
    return {'score':score, 'exclude':any(v < 40 for v in available),
            'reminders':[FIELDS[k] + '需要提前确认' for k in missing]}


def destination_analysis(db, attraction_id):
    values = verified(db, attraction_id)
    summary = analyze(values)
    strengths = [FIELDS[key] for key, value in values.items() if value >= 75]
    challenges = [FIELDS[key] for key, value in values.items() if value < 40]
    unconfirmed = [label for key, label in FIELDS.items() if key not in values]
    stored = db.execute("SELECT result FROM analyses WHERE attraction=? AND version='model-focus-1' AND created >= COALESCE((SELECT max(updated) FROM evidence WHERE attraction=?),created)", (attraction_id,attraction_id)).fetchone()
    focus = [FIELDS[key] for key in json.loads(stored['result'])['focus'] if key in FIELDS and key not in values] if stored else []
    return {'focus':focus, 'version':'rules-1', 'strengths':strengths, 'challenges':challenges,
            'unconfirmed':unconfirmed, 'score':summary['score'],
            'recommendation': '仅将已核实的条件纳入评估，优先安排时间较短、方便休息的游览。' if values else '安排行程前，先确认您在意的游览条件。'}
