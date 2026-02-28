# BTS Conversation Extraction Notes

> Extracted conversation inventories from ChatGPT history.
> Companion to `BTS_Technical_Reference.md` — separated during v2 cleanup.

---

## 1. Conversation Inventory (Original Extraction)

| # | Date | Title | System | Size |
|---|---|---|---|---|
| 19 | 2025-08-08 | Insert unique bioc data | BTS/NHPID | 45K |
| 21 | 2025-08-22 | Replace view query | BTS | 12K |
| 22 | 2025-10-02 | Update BIOCIDE_IDENTIFICATION_NO | BTS | 31K |
| 23 | 2025-10-07 | Write in MySQL | BTS | 1K |
| 25 | 2025-11-06 | MySQL script for Oracle | BTS | 10K |
| 26 | 2025-11-07 | Create view script | BTS | 119K |
| 28 | 2025-11-21 | Debugging Appian error | BTS/Appian | 723K |
| 29 | 2025-11-21 | Find tables with column | BTS | 48K |
| 30 | 2025-11-28 | Fix SQL syntax error | BTS | 612K |
| 32 | 2025-12-03 | Control number ranking rewrite | BTS | 33K |
| 34 | 2025-12-16 | Create table script | BTS | 1.33M |

> Conversations #19 and #28 are cross-system — also tracked in the NHPID repo where relevant.

---

## 2. Handling `conversations-006.json` (59MB — TOO LARGE TO UPLOAD)

The 31MB chat limit blocked this file. Options to process it:

**Option A — Split it locally (recommended):**
```python
import json

with open('conversations-006.json') as f:
    data = json.load(f)

mid = len(data) // 2
with open('conversations-006a.json', 'w') as f:
    json.dump(data[:mid], f)
with open('conversations-006b.json', 'w') as f:
    json.dump(data[mid:], f)

print(f"Total: {len(data)} convos → {mid} + {len(data)-mid}")
```
Then upload `conversations-006a.json` and `conversations-006b.json` in a new session.

**Option B — Pre-filter to only technical conversations:**
```python
import json

KEYWORDS = [
    'bts_regulatory_activity', 'bts_market_authorization',
    'BIOCIDE_IDENTIFICATION_NO', 'CONTROL_NUMBER_ID',
    'bts_appian_rt', 'bts_dossier'
]

with open('conversations-006.json') as f:
    data = json.load(f)

def full_text(convo):
    texts = []
    for node in convo.get('mapping', {}).values():
        msg = node.get('message')
        if not msg: continue
        parts = msg.get('content', {}).get('parts', []) if isinstance(msg.get('content'), dict) else []
        texts.extend(p for p in parts if isinstance(p, str))
    return ' '.join(texts)

hits = [c for c in data if any(k.lower() in full_text(c).lower() for k in KEYWORDS)]
with open('conversations-006-bts.json', 'w') as f:
    json.dump(hits, f)

print(f"Filtered: {len(hits)}/{len(data)} conversations")
```
Upload the filtered file — it'll be much smaller.

---

## 3. Updated Conversation Inventory (conversations-006)

| Date | Title | System | Size | Notes |
|---|---|---|---|---|
| 2026-01-10 | sp_refresh_cts_dpd_company_refs | BTS | 1.9M | SQL Server→MySQL org/company refresh SP |
| 2026-01-19 | BTS_market_auth_NBT522 | BTS | 667K | NBT522 ticket — MA State/Status refactor design |
| 2026-01-20 | JIRA code cleaning | BTS | 31K | NBT522 front end spec formatting |
| 2026-01-28 | Branch · BTS_market_auth_NBT522 | BTS | 1.69M | NBT522 continued implementation |
| 2026-02-15 | Branch · sp_refresh_cts_dpd_company_refs | BTS | 955K | SP refresh continued |

---

*Moved from BTS_Technical_Reference.md v1 (sections 6, 7, 11) during v2 restructuring — 2026-02-28*
