# BTS CTS / DPD Refresh Workstream

> Active ETL / migration workstream reference for CTS / DPD company and organization refresh logic into BTS.
> This file is intentionally separate from the core BTS technical reference because it captures implementation workstream details and point-in-time observations.

---

## 1. WORKSTREAM OVERVIEW

### Primary procedure referenced

- **Stored Procedure:** `sp_refresh_cts_dpd_company_refs`

### Ticket

- **JIRA / Tickets:** `NBT537` & `NBT568`

### Theme

SQL Server / CTS / DPD source data refresh into MySQL BTS reference and organization structures.

### Status in prior sessions

- Active workstream across Jan–Feb 2026
- Continued across multiple long technical sessions / branches

### Why this work matters

This workstream confirms that BTS is not only Appian CRUD over operational tables; it also contains a meaningful ETL / refresh layer inside `bts_appian_rt` for reference and organization data.

---

## 2. BROADER INTEGRATION CONTEXT

### System pattern

Prior sessions established a broader mapping / refresh context roughly described as:

- CTS / DPD source structures
- transformed / staged into BTS load + stage objects
- refreshed into BTS reference tables inside `bts_appian_rt`
- surfaced to operational logic through views / reference joins

### Mental model

Think of this workstream as part of the broader:

- CTS_DPD → BTS_APPIAN_RT refresh / migration pattern

---

## 3. POINT-IN-TIME MIGRATION OBSERVATIONS

> These counts were point-in-time observations during workstream analysis. Revalidate before using operationally.

Tables observed with `updated_by = 'MIGRATION'` in `bts_appian_rt` included:

| Table                      | Observed Migrated Rows |
| -------------------------- | ---------------------- |
| `bts_ref_org_contact`      | 20,308                 |
| `bts_ref_org_addr`         | 19,994                 |
| `bts_ref_address`          | 19,929                 |
| `bts_ref_contact`          | 19,825                 |
| `bts_ref_org`              | 13,447                 |
| `bts_ref_org_addr_contact` | 9,715                  |
| `bts_ref_org_profile`      | 5,454                  |
| `bts_ref_province`         | 994                    |

### Practical caution

Treat these as historical diagnostics / migration observations, not durable architecture facts.

---

## 4. ETL FOOTPRINT OBSERVED DURING WORKSTREAM

### Load tables

- `bts_load_address`
- `bts_load_address_detail`
- `bts_load_contact`
- `bts_load_country`
- `bts_load_org`
- `bts_load_org_addr`
- `bts_load_org_addr_contact`
- `bts_load_org_contact`
- `bts_load_org_profile`
- `bts_load_province`
- `bts_load_salutation`
- `bts_initial_load_org`

### Stage tables

- `bts_stage_address`
- `bts_stage_address_detail`
- `bts_stage_contact`
- `bts_stage_country`
- `bts_stage_org`
- `bts_stage_org_addr`
- `bts_stage_org_addr_contact`
- `bts_stage_org_contact`
- `bts_stage_org_profile`
- `bts_stage_province`
- `bts_stage_salutation`

### Reference tables

- `bts_ref_address`
- `bts_ref_address_detail`
- `bts_ref_contact`
- `bts_ref_country`
- `bts_ref_org`
- `bts_ref_org_addr`
- `bts_ref_org_addr_contact`
- `bts_ref_org_contact`
- `bts_ref_org_profile`
- `bts_ref_province`
- `bts_ref_salutation`

### Supporting / other table

- `bts_tmp_country`

### Load views

- `bts_view_load_addr_detail`
- `bts_view_load_address`
- `bts_view_load_contact`
- `bts_view_load_country`
- `bts_view_load_org`
- `bts_view_load_org_addr`
- `bts_view_load_org_addr_contact`
- `bts_view_load_org_contact`
- `bts_view_load_org_profile`
- `bts_view_load_province`
- `bts_view_load_salutation`

---

## 5. WORKSTREAM INTERPRETATION

### What this object footprint implies

BTS contains an internal ETL / reference-refresh layer with at least these logical bands:

1. **Load layer**
   - source-oriented ingest / landing structures
2. **Stage layer**
   - transformation / normalization structures
3. **Reference layer**
   - runtime reference tables used by the application
4. **Load views**
   - view-based transformation / abstraction over load data

### Practical implication

When a BTS issue seems to be "missing org/company data," the problem may sit in:

- source extraction
- load tables
- stage transformation
- reference-table refresh
- downstream joins / views

not only in the Appian UI or operational tables.

---

## 6. IMPLEMENTATION CAUTIONS

### Treat inventories as observed, not exhaustive

The table / view lists in this file reflect prior workstream observations. They should not be treated as a guaranteed full ETL catalog without direct schema inspection.

### Revalidate before coding

Before making ETL changes, verify:

- exact current procedure body for `sp_refresh_cts_dpd_company_refs`
- actual dependencies among load / stage / ref objects
- indexes and constraints relevant to refresh ordering
- whether new migration artifacts have been introduced since the prior sessions

### Key risk areas

- duplicate / stale organization reference data
- incomplete propagation from stage to ref tables
- assumptions about source-system uniqueness or key stability
- point-in-time row counts being mistaken for current truth

---

## 7. RELATIONSHIP TO CORE BTS REFERENCE

This file is a **workstream companion** to:

- `BTS_Technical_Reference.md`

Use the core technical reference for:

- system overview
- schema anchors
- Appian integration notes
- common BTS SQL / troubleshooting

Use this workstream file for:

- ETL / migration refresh context
- CTS / DPD company / organization reference pipeline details
- point-in-time migration observations

---

## 8. KNOWN ISSUE — MISSING POST-CUTOFF COMPANIES

### Symptom

Companies added to CTS after approximately March 2025 do not appear in `bts_ref_org` after `sp_refresh_cts_company_refs` runs. Example: "JIFCLEAN INC." / COMPANY_CODE = 22179.

### Root cause assessment

The SP itself has no date filtering — step 3.4 is an unfiltered `SELECT ... FROM stg_cts_company`. If a company is missing from `bts_ref_org` post-refresh, the data never reached `stg_cts_company`.

The most likely upstream cause is that the Informatica ETL mapping extracts from `dpd.*` tables (a stale replica) instead of the canonical `common.*_WV` views on the CTS SQL Server side. If `dpd.*` was last refreshed around March 2025, all companies added after that date would be absent from the BTS pipeline.

### Diagnostic approach

Run the pipeline tracer query: `queries/debug_cts_missing_companies_pipeline.sql`

This walks backward from SP output to load-layer input, checking each pipeline layer for the missing company and inspecting staging freshness watermarks.

### Resolution

1. Confirm which pipeline layer the company drops off at (diagnostic queries)
2. If missing from `stg_cts_company` and `bts_load_org`: escalate to ETL/Informatica team to correct source mapping from `dpd.*` to `common.*_WV`
3. If missing only from `stg_cts_company` (present in `bts_load_org`): inspect `bts_view_load_org` for filtering
4. After upstream fix, re-run SP and verify company appears in `bts_ref_org` and Appian FE

### Date discovered

2026-03-03

### Related tickets

NBT537 / NBT568

---

## 9. SUMMARY

### What this file is

A dedicated workstream note for BTS CTS / DPD company-reference refresh and migration activity.

### What it is not

- not a final production ETL spec
- not a full data lineage document
- not proof that all listed objects remain unchanged in the current environment

### Practical use

Use this file when troubleshooting or extending the organization/reference refresh pipeline feeding BTS, especially around `sp_refresh_cts_dpd_company_refs` and related load / stage / reference objects.
