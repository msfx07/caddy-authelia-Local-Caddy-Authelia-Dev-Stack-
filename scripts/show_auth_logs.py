#!/usr/bin/env python3
import sqlite3


DB='/config/db.sqlite3'
conn=sqlite3.connect(DB)
cur=conn.cursor()
print('\n---- Recent authentication_logs ----')
try:
    cur.execute("SELECT rowid, * FROM authentication_logs ORDER BY rowid DESC LIMIT 50")
    rows=cur.fetchall()
    for r in rows:
        print(r)
except Exception as e:
    print('Error querying authentication_logs:', e)

print('\n---- Recent authentication_events (if present) ----')
for t in ('authentication_logs','events','oauth2_access_token_session'):
    try:
        cur.execute(f"SELECT name FROM sqlite_master WHERE type='table' AND name='{t}'")
        if cur.fetchone():
            cur.execute(f"SELECT rowid, * FROM {t} ORDER BY rowid DESC LIMIT 20")
            for r in cur.fetchall():
                print(t, r)
    except Exception as e:
        pass
conn.close()
