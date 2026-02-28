# BTS Database Development

## Who I Am
Lead backend developer on the Government of Canada Health Canada BTS (Biocides Tracking System) — MySQL 8.0, schema `bts_appian_rt`, Appian low-code frontend.

## Full Technical Reference
@docs/BTS_Technical_Reference.md

Read this before ANY SQL or schema work. It is a selective context primer containing:
- Core schema anchors (key tables, columns, relationships)
- Known production column name bugs (do not "fix" them)
- FK dependency maps for bts_regulatory_activity
- Common query patterns and status code groups
- Active JIRA ticket designs (NBT522, sp_refresh)

For additional context see companion docs in `/docs`:
- `BTS_NBT522_Workstream.md` — NBT522 MA state/status refactor design (read for NBT522 work)
- `BTS_CTS_DPD_Refresh_Workstream.md` — sp_refresh ETL table inventory (read for ETL work)
- `BTS_Conversation_Extraction_Notes.md` — conversation source inventory
- `BTS_Knowledge_Base_Ingestion.md` — vector DB integration plan
- `BTS_Working_Context.md` — environment metadata and role context
- `BTS_NBT522_Workstream.md` — dedicated NBT522 MA state/status refactor workstream reference
- `BTS_CTS_DPD_Refresh_Workstream.md` — dedicated CTS/DPD company refresh workstream reference

---

## CRITICAL RULES — MANDATORY BEFORE WRITING ANY SQL

### Syntax
- BTS = **MySQL 8.0** syntax only

### Known Production Gotchas
- `bts_product.REGULATORY_ACTIVTY_FK` — **the typo is intentional and real**. The column exists in production with this spelling. Do not correct it in any query or DDL.
- `bts_regulatory_activity` has **NO IS_ACTIVE column**. Use `COALESCE(STATUS_TARGET_DATE, RA_TARGET_DATE, MODIFIED_ON, CREATED_ON)` for recency ordering.
- `BIOCIDE_IDENTIFICATION_NO` values contain embedded control characters (CR=0x0D, NBSP=0xA0). Always strip with `REGEXP_REPLACE(col, '[^0-9]', '')` before any `CHAR_LENGTH` or `LPAD` operation.

### Join Patterns
- Status ref table join: `bts_ref_nhpid_reg_activity_status rs ON rs.PK = ra.REGULATORY_ACTIVITY_STATUS_FK`
- **NEVER** join as `rs.REGULATORY_ACTIVITY_FK = ra.PK` — that column does not exist (MySQL Error 1054)
- Note: Despite "nhpid" in the name, `bts_ref_nhpid_reg_activity_status` is a BTS table in `bts_appian_rt`. The name is historical.

### DML Safety
- Always wrap DML in `START TRANSACTION; ... COMMIT;`
- Always run a `SELECT` preview before any `UPDATE` or `DELETE`
- Never write directly to production tables — always script with proper guards

---

## Active JIRA Tickets

### NBT522 — MA State/Status Refactor (In Progress)
Full design in `docs/BTS_Technical_Reference.md` Section 12.
Dedicated workstream reference: `docs/BTS_NBT522_Workstream.md`
- New tables needed: `bts_ma_state_hist`, `bts_ma_status_hist`
- New columns on `bts_market_authorization`: `ORIGINAL_ISSUE_DATE`, `ORIGINAL_ISSUER`
- Two stored procs: `sp_ma_submit_state(...)`, `sp_ma_update_status(...)`
- Three views: `bts_view_ma_current`, `bts_view_ma_state_history`, `bts_view_ma_status_history`
- Frontend dev: Yawei | Business owner: Shannon's team

### sp_refresh_cts_dpd_company_refs (In Progress)
SQL Server → MySQL org/company data refresh stored procedure.
JIRA tickets: NBT537, NBT568
ETL table inventory in Section 13 of reference doc.
Dedicated workstream reference: `docs/BTS_CTS_DPD_Refresh_Workstream.md`

---

## Tooling
- MySQL Workbench (BTS)
- Appian Designer (frontend — low-code BPM)
- View definer: `` `bts_appian_owner_dv`@`%` ``

---

## Repo Layout
```
/schema      → DDL: CREATE TABLE, ALTER TABLE scripts
/views       → CREATE OR REPLACE VIEW scripts
/procedures  → Stored procedure scripts
/migrations  → One-time data migration and backfill scripts
/queries     → Debug, reporting, and investigation queries
/docs        → Reference documentation
```

## File Naming Convention
```
schema/     nbt522_bts_ma_state_hist.sql
views/      bts_view_ma_current.sql
procedures/ sp_ma_submit_state.sql
migrations/ nbt522_backfill_ma_state_hist.sql
queries/    debug_biocide_identification_no_chars.sql
```

---

## Working Instructions
- Always verify column names against `docs/BTS_Technical_Reference.md` before writing SQL
- Schema changes: DDL first → views second → stored procs third
- Never refactor existing working queries unless explicitly asked
- When in doubt about a table or column, say so — do not invent names
- IMPORTANT: All new BTS tables follow the `bts_` prefix convention
- IMPORTANT: All new BTS views follow the `bts_view_` prefix convention
- IMPORTANT: All new BTS stored procs follow the `sp_` prefix convention
