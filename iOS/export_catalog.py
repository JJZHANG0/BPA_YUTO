"""Export the native app's offline catalog without internal source fields."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from ingest import seed
from model import connect
from server import public

seed()
with connect() as db:
    data = {
        'provinces': [row[0] for row in db.execute('SELECT name FROM provinces ORDER BY name')],
        'attractions': [public(db, row, True) for row in db.execute('SELECT * FROM attractions ORDER BY province, city, name')],
    }
(ROOT / 'iOS/Resources/Catalog.json').write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
