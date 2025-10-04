#!/usr/bin/env python3
import sqlite3
db='/config/db.sqlite3'
conn=sqlite3.connect(db)
cur=conn.cursor()
print('\n---- sqlite schema (tables) ----')
for row in cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"):
    print(row[0])

for t in ['regulation','user','users','authentications','events','logins','bans']:
    try:
        cur.execute(f'SELECT count(*) FROM {t}')
        cnt=cur.fetchone()[0]
        print(f'\nTable {t}: count={cnt}')
        for r in cur.execute(f'SELECT * FROM {t} ORDER BY rowid DESC LIMIT 5'):
            print('  ',r)
    except Exception:
        pass
conn.close()
