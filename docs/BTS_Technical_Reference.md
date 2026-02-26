# BTS Technical Reference
> Extracted from ChatGPT conversation history | Split from combined BTS/NHPID reference
> Use this as context primer for any new coding session on the BTS system.

---

## 1. SYSTEM OVERVIEW

### BTS — Biocides Tracking System
| Property | Value |
|---|---|
| **DB Engine** | MySQL 8.0 |
| **Schema** | `bts_appian_rt` |
| **View Definer** | `` `bts_appian_owner_dv`@`%` `` |
| **Frontend** | Appian (low-code BPM platform) |
| **Your Role** | Lead backend developer — full owner of schema, views, debug |
| **Tooling** | MySQL Workbench |

---

## 2. BTS SCHEMA — TABLE INVENTORY

### Core Tables

#### `bts_dossier`
```
PK, ID, CREATED_ON, CREATED_BY, MODIFIED_ON, MODIFIED_BY
```
- Top-level container. Everything hangs off a dossier.

#### `bts_regulatory_activity` (primary work table)
```
PK
DOSSIER_FK
CONTROL_NUMBER_ID
REGULATORY_ACTIVITY_LEAD_CODE        -- e.g. 'BP'
REGULATORY_ACTIVITY_TYPE_CODE        -- e.g. 'BNMA'
FILING_FIRST_SUBMISSION_IND
SUBMISSION_CLASS_CODE                -- e.g. 'SRI-NF', 'UFD'
ASSIGNED_ON
ASSIGNED_TO
STATUS
FILING_DATE
CREATED_BY, CREATED_ON
MODIFIED_BY, MODIFIED_ON
LOCK_RECORD, LOCK_RECORD_BY
RA_TARGET_DATE
STATUS_TARGET_DATE
```
> ⚠️ **No IS_ACTIVE column** — use `COALESCE(STATUS_TARGET_DATE, RA_TARGET_DATE, MODIFIED_ON, CREATED_ON)` for recency ranking.

#### `bts_market_authorization`
```
PK
DOSSIER_FK
IS_ACTIVE                            -- 1/0
STATUS                               -- 'APPROV' for approved
BIOCIDE_IDENTIFICATION_NO            -- VARCHAR, 8-digit zero-padded identifier
```
> ⚠️ **BIOCIDE_IDENTIFICATION_NO data quality issue**: some values contain embedded control characters (CR=`0x0D`, NBSP=`0xA0`). Use `REGEXP_REPLACE(col, '[^0-9]', '')` before any length/pad operations.

#### `bts_product`
```
PK
DOSSIER_FK
PRIMARY_BRAND_NAME_EN
PRIMARY_BRAND_NAME_FR
IS_ACTIVE
REGULATORY_ACTIVTY_FK                -- ⚠️ TYPO: missing 'I' in ACTIVITY
```
> ⚠️ **Known typo**: `REGULATORY_ACTIVTY_FK` (not `REGULATORY_ACTIVITY_FK`). This is the actual column name in prod. Don't "fix" it in queries — use it as-is.

#### `bts_ref_nhpid_reg_activity_status` (lookup / reference)
```
PK
CODE                                 -- e.g. 'APPROVED', 'UNDER_CONSIDERATION', 'REJECTED'
REGULATORY_ACTIVITY_STATUS_EN
```
**Correct join:** `bts_ref_nhpid_reg_activity_status rs ON rs.PK = ra.REGULATORY_ACTIVITY_STATUS_FK`
> ⚠️ **Common mistake**: joining as `rs.REGULATORY_ACTIVITY_FK = ra.PK` — this column does not exist → MySQL Error 1054.

> **Note:** Despite "nhpid" in the name, `bts_ref_nhpid_reg_activity_status` is a BTS table in `bts_appian_rt`. The name is historical and does not indicate an NHPID dependency.

---

### Child Tables of `bts_regulatory_activity` (FK children)
When deleting from `bts_regulatory_activity`, these must be cleared first in any order:

| Table | FK Column | Constraint Name |
|---|---|---|
| `bts_audit_regulatory_activity` | `REGULATORY_ACTIVITY_FK` | — |
| `bts_document_regulatory_activity` | `REGULATORY_ACTIVITY_FK` | `DocumentRegulatoryActivityRegulatoryActivity_FK` |
| `bts_note_regulatory_activity` | `REGULATORY_ACTIVITY_FK` | `NoteRegulatoryActivityRegulatoryActivity_FK` |
| `bts_ra_fee` | `REGULATORY_ACTIVITY_FK` | `BTS_RA_FEE_REGULATORY_ACTIVITY_FK` |
| `bts_ra_status_history` | `REGULATORY_ACTIVITY_FK` | `RAStatusHistoryRegulatoryActivityFK_FK` |
| `bts_related_transaction` | `REGULATORY_ACTIVITY_FK` | `BTS_RELATED_TRANSACTION_REGULATORY_ACTIVITY_FK_FK` |
| **`bts_product`** | `REGULATORY_ACTIVTY_FK` | `BTS_PRODUCT_REGULATORY_ACTIVITY_FK` |

> The `bts_product` row is the one most people miss — note the typo in the column name.

**Query to discover all FK children of any table:**
```sql
SELECT
    kcu.CONSTRAINT_SCHEMA AS child_schema,
    kcu.TABLE_NAME        AS child_table,
    kcu.COLUMN_NAME       AS child_column,
    kcu.CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
WHERE kcu.REFERENCED_TABLE_SCHEMA = 'bts_appian_rt'
  AND kcu.REFERENCED_TABLE_NAME   = 'bts_regulatory_activity'
  AND kcu.REFERENCED_COLUMN_NAME  = 'PK'
ORDER BY child_schema, child_table;
```

---

### Views (confirmed existing)
| View | Purpose |
|---|---|
| `bts_view_dossier` | Main dossier rollup — joins dossier + product + RA + market + org |
| `bts_view_dossier_organization` | Org/company info per dossier |
| `bts_view_dossier_recent_approved_ra` | Most recent approved RA per dossier (window fn) |
| `bts_view_dossier_recent_draft_ra` | Most recent pending/draft RA per dossier |

---

## 3. BTS — APPIAN RECORD TYPES

Appian record types mapped to BTS tables:

| Appian Record Type | Maps To |
|---|---|
| `BTS_Product` | `bts_product` |
| `BTS_Dossier` | `bts_dossier` |
| `BTS_Regulatory_Activity` | `bts_regulatory_activity` |
| `BTS_Product_Container` | `bts_product_container` (multiple) |
| `BTS_Product_Brand_Name` | `bts_product_brand_name` (multiple) |
| `BTS_Product_Active_Ingredient` | `bts_product_active_ingredient` (multiple) |
| `BTS_Product_Use_Setting` | `bts_product_use_setting` (multiple) |
| `BTS_Product_Use_Purpose` | `bts_product_use_purpose` (multiple) |
| `BTS_Product_Method_Of_Application` | `bts_product_method_of_application` (multiple) |
| `BTS_Product_Monograph` | `bts_product_monograph` |
| `BTS_Product_Detail` | `bts_product_detail` |
| `BTS_Product_Comparison` | `bts_product_comparison` |
| `BTS_Product_Use_Of_Foreign_Decision` | `bts_product_use_of_foreign_decision` |

**Process model context:**
Process: `BTS Create Or Update Product (2.0)`
Key node: `Get Product Lock Info`
Key PV inputs to this node: `BTS_Product` (record), `pk` (Number Integer), `regulatoryActivtyFK` (Number Integer — note typo matches column), `dossierFK`, `status`, `lockRecord`, `lockRecordBy`, etc.

---

## 4. BTS — KNOWN BUGS AND GOTCHAS

### Bug 1: BIOCIDE_IDENTIFICATION_NO control characters
**Symptom:** `LPAD(..., 8, '0')` returns 0 rows changed even though 15 rows matched.
**Root cause:** Values contain embedded non-digit bytes (CR=`0D`, NBSP=`A0`) — `CHAR_LENGTH` reports 7 but data isn't clean.
**Fix:**
```sql
-- Diagnosis
SELECT BIOCIDE_IDENTIFICATION_NO,
       CHAR_LENGTH(BIOCIDE_IDENTIFICATION_NO) AS len,
       HEX(BIOCIDE_IDENTIFICATION_NO) AS raw_hex
FROM bts_appian_rt.bts_market_authorization
WHERE STATUS = 'APPROV';

-- Cleanup + pad
START TRANSACTION;
UPDATE bts_appian_rt.bts_market_authorization
SET BIOCIDE_IDENTIFICATION_NO =
      LPAD(REGEXP_REPLACE(BIOCIDE_IDENTIFICATION_NO, '[^0-9]', ''), 8, '0')
WHERE STATUS = 'APPROV'
  AND CHAR_LENGTH(REGEXP_REPLACE(BIOCIDE_IDENTIFICATION_NO, '[^0-9]', '')) = 7
  AND BIOCIDE_IDENTIFICATION_NO <>
      LPAD(REGEXP_REPLACE(BIOCIDE_IDENTIFICATION_NO, '[^0-9]', ''), 8, '0');
SELECT ROW_COUNT() AS rows_changed;
COMMIT;
```

### Bug 2: Appian `pv!BTS_Product.pk` null error
**Error:** `a!queryRecordByIdentifier identifier cannot be null or empty`
**Process:** BTS Create Or Update Product (2.0) → Get Product Lock Info node
**Root cause:** On CREATE path, pk doesn't exist yet; expression digs into `pv!BTS_Product` record which has null pk.
**Fix:**
1. In node Data Inputs → find the input whose Value contains `a!queryRecordByIdentifier` → change identifier to `pv!pk`
2. Add node run condition: `not(isnull(pv!pk))` so node skips on create path

### Bug 3: Wrong status table join
**Error:** MySQL 1054 `Unknown column 'rs.REGULATORY_ACTIVITY_FK' in 'on clause'`
**Fix:** Always join as `bts_ref_nhpid_reg_activity_status rs ON rs.PK = ra.REGULATORY_ACTIVITY_STATUS_FK`

### Bug 4: `bts_product.REGULATORY_ACTIVTY_FK` typo
The column exists with the typo in production. Use `REGULATORY_ACTIVTY_FK` in all queries (not `REGULATORY_ACTIVITY_FK`).

---

## 5. BTS — COMMON QUERY PATTERNS

### RA Status codes (approved / draft / terminal)
```sql
-- Approved/authorized
rs.CODE IN ('APPROVED','MARKET','MA','AUTHORIZED')
   OR rs.REGULATORY_ACTIVITY_STATUS_EN IN ('APPROVED','MARKET AUTHORIZED')

-- Pending/draft (not terminal)
rs.CODE IN ('UNDER_CONSIDERATION','UNDER_RECONSIDERATION','SCREENING','SCRREC','INACTIVE_RECONSIDERATION')
AND rs.CODE NOT IN ('REJECTED','CANCEL','CANCEL_REVIEW','WITHDRAWN','INACTIVE')

-- Terminal/negative
rs.CODE IN ('REJECTED','CANCEL','CANCEL_REVIEW','WITHDRAWN','INACTIVE')
```

### Most recent RA per dossier (window function pattern)
```sql
WITH ranked AS (
  SELECT
      ra.DOSSIER_FK,
      ra.PK AS RA_PK,
      p.PRIMARY_BRAND_NAME_EN,
      p.PRIMARY_BRAND_NAME_FR,
      ROW_NUMBER() OVER (
        PARTITION BY ra.DOSSIER_FK
        ORDER BY COALESCE(ra.STATUS_TARGET_DATE,
                          ra.RA_TARGET_DATE,
                          ra.MODIFIED_ON,
                          ra.CREATED_ON) DESC, ra.PK DESC
      ) AS rn
  FROM bts_regulatory_activity ra
  JOIN bts_ref_nhpid_reg_activity_status rs ON rs.PK = ra.REGULATORY_ACTIVITY_STATUS_FK
  LEFT JOIN bts_product p ON p.DOSSIER_FK = ra.DOSSIER_FK AND p.IS_ACTIVE = 1
  WHERE rs.CODE IN ('APPROVED','MARKET','MA','AUTHORIZED')
)
SELECT DOSSIER_FK, RA_PK, PRIMARY_BRAND_NAME_EN, PRIMARY_BRAND_NAME_FR
FROM ranked WHERE rn = 1;
```

### Find all FKs referencing any table (cross-schema safe)
```sql
SELECT kcu.CONSTRAINT_SCHEMA, kcu.TABLE_NAME, kcu.COLUMN_NAME, kcu.CONSTRAINT_NAME,
       kcu.REFERENCED_TABLE_NAME, kcu.REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
WHERE kcu.REFERENCED_TABLE_NAME = '<your_table>'
  AND kcu.REFERENCED_COLUMN_NAME = 'PK'
ORDER BY CONSTRAINT_SCHEMA, TABLE_NAME;
```

---

## 6. CONVERSATION INVENTORY (source files)

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

## 7. HANDLING `conversations-006.json` (59MB — TOO LARGE TO UPLOAD)

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

## 8. NEXT STEPS — VECTOR DB INTEGRATION

Once Mac mini M4 Pro is set up:
1. Copy all BTS `.md` files from extraction to Mac mini knowledge base directory
2. Chunk by conversation section (≈500 token chunks with overlap)
3. Embed with OpenAI `text-embedding-3-small` or Anthropic embeddings
4. Store in local vector DB (ChromaDB or pgvector recommended)
5. Tag each chunk with metadata: `system` = BTS, `date`, `topic`, `keywords_hit`
6. Process `conversations-006.json` and merge into the same DB

---

## 9. BTS — ACTIVE TICKET: NBT522 — MA State/Status Refactor (Jan 2026)

### Overview
**JIRA:** NBT522 — Market Authorization State/Status separation
**Your role:** DB implementation (Ramy)
**Frontend developer:** Yawei
**Business owner/MA amendments:** Shannon's team
**Status as of Jan 2026:** Active — DB design underway

### Core Business Rule: State vs Status Separation
The existing `bts_market_authorization.STATUS` column conflates two distinct concepts that must now be separated:

| Concept | Description | New Object |
|---|---|---|
| **MA State** | Whether the MA is authorized or not | `bts_ma_state_hist` |
| **MA Status** | Operational status (marketed, suspended, etc.) | `bts_ma_status_hist` |

### MA State Values (3 combinations)
| STATE_CODE | AUTHORIZED_TYPE_CODE | Display |
|---|---|---|
| `AUTHORIZED` | `INITIAL` | "AUTHORIZED – INITIAL" |
| `AUTHORIZED` | `AMENDMENT` | "AUTHORIZED – AMENDMENT" |
| `NOT_AUTHORIZED` | NULL | "NOT AUTHORIZED" |

> **Design decision:** Store `STATE_CODE` (AUTHORIZED/NOT_AUTHORIZED) + `AUTHORIZED_TYPE_CODE` (INITIAL/AMENDMENT/null) in the same row. Dashboards show simplified `STATE_CODE` only; history pages use `AUTHORIZED_TYPE_CODE` for full display.

### MA Status Values (reference codes)
`MARKETED`, `TEMPORARY SUSPENSION`, `TEMPORARY PARTIAL SUSPENSION`, `REVOKED` (and variants)

### Three Date Categories Required
1. **Initial Market Authorization date** — effective date of first AUTHORIZED-INITIAL event
2. **MA Amendment date** — effective date of each AUTHORIZED-AMENDMENT event (start + end)
3. **MA Status date** — effective start/end of each status event

### New Tables to Create

#### `bts_ma_state_hist`
```sql
CREATE TABLE bts_ma_state_hist (
  ID                    INT AUTO_INCREMENT PRIMARY KEY,
  MARKET_AUTHORIZATION_FK INT NOT NULL,              -- FK → bts_market_authorization.PK
  STATE_CODE            VARCHAR(30) NOT NULL,         -- 'AUTHORIZED' / 'NOT_AUTHORIZED'
  AUTHORIZED_TYPE_CODE  VARCHAR(20) NULL,             -- 'INITIAL' / 'AMENDMENT' / NULL
  EFFECTIVE_START_DATE  DATE NOT NULL,
  EFFECTIVE_END_DATE    DATE NULL,
  ISSUER                VARCHAR(100) NULL,
  CREATED_BY            VARCHAR(100),
  CREATED_ON            DATETIME DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_auth_type CHECK (
    (STATE_CODE = 'AUTHORIZED' AND AUTHORIZED_TYPE_CODE IN ('INITIAL','AMENDMENT'))
    OR (STATE_CODE = 'NOT_AUTHORIZED' AND AUTHORIZED_TYPE_CODE IS NULL)
  )
);
```

#### `bts_ma_status_hist`
```sql
CREATE TABLE bts_ma_status_hist (
  ID                    INT AUTO_INCREMENT PRIMARY KEY,
  MARKET_AUTHORIZATION_FK INT NOT NULL,
  STATUS_CODE           VARCHAR(50) NOT NULL,
  EFFECTIVE_START_DATE  DATE NOT NULL,
  EFFECTIVE_END_DATE    DATE NULL,
  ISSUER                VARCHAR(100) NULL,
  CREATED_BY            VARCHAR(100),
  CREATED_ON            DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### `bts_market_authorization` — add columns
```sql
ALTER TABLE bts_appian_rt.bts_market_authorization
  ADD COLUMN ORIGINAL_ISSUE_DATE  DATE NULL,
  ADD COLUMN ORIGINAL_ISSUER      VARCHAR(100) NULL;
```

### Stored Procedures to Implement

#### `sp_ma_submit_state(p_dossier_fk, p_bin, p_state_code, p_state_subtype, p_effective_date, p_state_issuer, p_user)`
Logic:
1. Resolve/ensure `bts_market_authorization` row exists for BIN
2. End-date prior open state interval row (`EFFECTIVE_END_DATE = p_effective_date - 1 day`)
3. Insert new row into `bts_ma_state_hist`
4. If `AUTHORIZED + INITIAL`: set `ORIGINAL_ISSUE_DATE` and `ORIGINAL_ISSUER` on header (only if not already set)
5. If `AUTHORIZED + AMENDMENT`: do NOT overwrite original issue date
6. If `NOT_AUTHORIZED`: leave original issue date as-is

#### `sp_ma_update_status(p_bin, p_status_code, p_effective_date, p_issuer, p_user)`
Logic:
1. Gate check: if no `AUTHORIZED INITIAL` history exists → raise error
2. End-date current open status row
3. Insert new status row
4. **Cross-effects (rules from ticket):**
   - If new status = `REVOKED` (any variant): end-date any open AUTHORIZED state + insert NOT_AUTHORIZED state
   - If new status = `TEMPORARY SUSPENSION`: end-date open MARKETED status + end-date AUTHORIZED state + insert NOT_AUTHORIZED state

### Views to Create
| View | Description |
|---|---|
| `bts_view_ma_current` | Per BIN: CURRENT_STATUS_CODE, CURRENT_STATE_CODE, DISPLAY_CODE = COALESCE(status, state), ORIGINAL_ISSUE_DATE |
| `bts_view_ma_state_history` | All state hist rows ordered by effective date |
| `bts_view_ma_status_history` | All status hist rows ordered by effective date |

### Reference Tables (confirm or add)
- `bts_ref_market_authorization_status` — already exists; ensure `CATEGORY` column distinguishes `STATE` vs `STATUS` and includes `IS_ACTIVE`, `SEQUENCE`, `DATE_IS_REQUIRED` flags
- State codes: `APPROV` = AUTHORIZED, `NOTAUT` = NOT_AUTHORIZED

### UI / Front End Contract (for Yawei)
- Dropdowns: query `bts_ref_market_authorization_status` filtered by `CATEGORY='STATE'` or `CATEGORY='STATUS'` and `IS_ACTIVE=1`, sorted by `SEQUENCE`
- Dashboard display: read `DISPLAY_CODE` from `bts_view_ma_current`
- History pages: read from `bts_view_ma_state_history` / `bts_view_ma_status_history`
- AMENDMENT subtype displayed only in history section and optionally submit screen
- Submit handler: call `sp_submit_ma_state(p_dossier_fk, p_bin, p_state_code, p_state_subtype, p_effective_date, p_state_issuer, p_user)` — `p_state_subtype` always NULL from UI (DB derives INITIAL vs AMENDMENT)

### Access Groups
`TEST_BTS_ADMIN_BUSINESS`, `TEST_BTS_ADMIN_IT`, `TEST_BTS_REVIEWER`

---

## 10. BTS — ACTIVE TICKET: sp_refresh_cts_dpd_company_refs (Jan–Feb 2026)

### Overview
**Stored Procedure:** `sp_refresh_cts_dpd_company_refs`
**Purpose:** SQL Server → MySQL migration and refresh for company/org reference data
**Status as of Feb 2026:** Active — two long sessions (Jan 10 + Feb 15 branch)

### Migration Table Footprint
Tables with `updated_by = 'MIGRATION'` in `bts_appian_rt`:

| Table | Migrated Rows |
|---|---|
| `bts_ref_org_contact` | 20,308 |
| `bts_ref_org_addr` | 19,994 |
| `bts_ref_address` | 19,929 |
| `bts_ref_contact` | 19,825 |
| `bts_ref_org` | 13,447 |
| `bts_ref_org_addr_contact` | 9,715 |
| `bts_ref_org_profile` | 5,454 |
| `bts_ref_province` | 994 |

### Load/Stage Table Inventory (discovered during SP work)
These are the ETL layer tables in `bts_appian_rt`:

**Load tables:** `bts_load_address`, `bts_load_address_detail`, `bts_load_contact`, `bts_load_country`, `bts_load_org`, `bts_load_org_addr`, `bts_load_org_addr_contact`, `bts_load_org_contact`, `bts_load_org_profile`, `bts_load_province`, `bts_load_salutation`, `bts_initial_load_org`

**Stage tables:** `bts_stage_address`, `bts_stage_address_detail`, `bts_stage_contact`, `bts_stage_country`, `bts_stage_org`, `bts_stage_org_addr`, `bts_stage_org_addr_contact`, `bts_stage_org_contact`, `bts_stage_org_profile`, `bts_stage_province`, `bts_stage_salutation`

**Reference tables (company/org):** `bts_ref_address`, `bts_ref_address_detail`, `bts_ref_contact`, `bts_ref_country`, `bts_ref_org`, `bts_ref_org_addr`, `bts_ref_org_addr_contact`, `bts_ref_org_contact`, `bts_ref_org_profile`, `bts_ref_province`, `bts_ref_salutation`

**Other:** `bts_tmp_country`

**Load views:** `bts_view_load_addr_detail`, `bts_view_load_address`, `bts_view_load_contact`, `bts_view_load_country`, `bts_view_load_org`, `bts_view_load_org_addr`, `bts_view_load_org_addr_contact`, `bts_view_load_org_contact`, `bts_view_load_org_profile`, `bts_view_load_province`, `bts_view_load_salutation`

---

## 11. UPDATED CONVERSATION INVENTORY (conversations-006)

| Date | Title | System | Size | Notes |
|---|---|---|---|---|
| 2026-01-10 | sp_refresh_cts_dpd_company_refs | BTS | 1.9M | SQL Server→MySQL org/company refresh SP |
| 2026-01-19 | BTS_market_auth_NBT522 | BTS | 667K | NBT522 ticket — MA State/Status refactor design |
| 2026-01-20 | JIRA code cleaning | BTS | 31K | NBT522 front end spec formatting |
| 2026-01-28 | Branch · BTS_market_auth_NBT522 | BTS | 1.69M | NBT522 continued implementation |
| 2026-02-15 | Branch · sp_refresh_cts_dpd_company_refs | BTS | 955K | SP refresh continued |

---
*Updated: 2026-02-26 | Split from combined BTS/NHPID reference | BTS conversations only*
