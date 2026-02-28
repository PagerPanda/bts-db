# BTS Database Scripts

SQL scripts for backend development on the Biocides Tracking System (BTS).

- **DB Engine:** MySQL 8.0
- **Schema:** `bts_appian_rt`
- **Frontend:** Appian (low-code BPM platform)

## Structure

| Folder | Contents |
|---|---|
| `/schema` | DDL — CREATE TABLE, ALTER TABLE |
| `/views` | CREATE OR REPLACE VIEW scripts |
| `/procedures` | Stored procedures |
| `/migrations` | One-time data backfill / migration scripts |
| `/queries` | Debug, reporting, investigation queries |
| `/docs` | Technical reference documentation |

## Active Tickets

- **NBT522** — MA State/Status refactor (schema + procs + views)
- **NBT537 / NBT568** — CTS/DPD → BTS org/company reference refresh (`sp_refresh_cts_dpd_company_refs`)

## Reference

See `docs/BTS_Technical_Reference.md` for schema context, known gotchas, and active ticket designs.

Additional companion docs in `/docs`:
- `BTS_Conversation_Extraction_Notes.md` — ChatGPT conversation source inventory
- `BTS_Knowledge_Base_Ingestion.md` — vector DB / knowledge base integration plan
- `BTS_Working_Context.md` — environment metadata, role context, view definer
- `BTS_NBT522_Workstream.md` — NBT522 MA state/status refactor workstream
- `BTS_CTS_DPD_Refresh_Workstream.md` — CTS/DPD company refresh workstream

## Claude Code

This repo is configured for Claude Code via `CLAUDE.md`. Run `claude` from the repo root to start a context-aware session.
