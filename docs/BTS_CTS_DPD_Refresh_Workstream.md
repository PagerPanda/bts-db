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

### Confirmed diagnostic results (2026-03-03)

Pipeline tracer query (`queries/debug_cts_missing_companies_pipeline.sql`) confirmed:

| Layer | Finding |
|-------|---------|
| `bts_ref_org` | 22179 absent. MAX(PK) = 19328 |
| `stg_cts_company` | 22179 absent. MAX(COMPANY_CODE) = 19328, 14707 rows, all ETL_DATE_STAMP = 2026-02-23 |
| `bts_load_org` | **Empty** (MAX = NULL). Load layer not populated or truncated post-load |
| `bts_view_load_org` | Validation/error-detection view (not a pass-through). Selects rows from `bts_load_org` where any column fails format/length validation. Does NOT filter companies from pipeline |
| `bts_initial_load_org` | 22179 absent |

**Conclusion:** Company 22179 never entered the pipeline at any layer. The upstream Informatica extract/source caps at COMPANY_CODE 19328. All companies above that code are absent.

**Additional finding:** `bts_load_org` is completely empty, suggesting Informatica may write directly to `stg_cts_company` (bypassing the load layer), or `bts_load_org` is truncated post-load.

### Diagnostic approach

Run the pipeline tracer query: `queries/debug_cts_missing_companies_pipeline.sql`

This walks backward from SP output to load-layer input, checking each pipeline layer for the missing company and inspecting staging freshness watermarks.

### Resolution

1. Confirm which pipeline layer the company drops off at (diagnostic queries) — **done, see above**
2. Escalate to ETL/Informatica team: the source extract caps at COMPANY_CODE 19328 — correct source mapping from `dpd.*` to `common.*_WV`
3. Confirm actual Informatica target table mapping (does it write to `stg_cts_company` directly or via `bts_load_org`?)
4. After upstream fix, re-run SP and verify company appears in `bts_ref_org` and Appian FE

### Date discovered

2026-03-03

### Related tickets

NBT537 / NBT568

---

## 9. CONFIRMED STAGING ARCHITECTURE — SP V3 ETL REMAPPING

> Confirmed 2026-03-06. This section supersedes any prior assumption that the SP must be rewritten to use common/dp native column names.

### Core principle

Existing `stg_cts_*` staging tables retain their **DPD-shaped column names**. Informatica is responsible for remapping common/dp source columns INTO these legacy staging columns. The SP reads staging tables unchanged.

### Staging table categories

#### A) Existing staging tables — SOURCE CHANGE ONLY (keep table name + columns)

| Staging Table | Old Source | New Source | Column Mapping Notes |
|---|---|---|---|
| `stg_cts_company` | `dpd.COMPANY` | `common.ORG_WV` | Map into COMPANY_CODE, COMPANY_NAME, MFR_CODE, OLD_NOTES, NOTES, INACTIVATION_DATE, CRA_BUSINESS_NO, SBR_* |
| `stg_cts_contact` | `dpd.CONTACT` | `common.CONTACT` | Map PK→CONTACT_CODE, SALUTATION_FK→SALUTATION_CODE, EMAIL→E_MAIL_ADDRESS, TS→LAST_UPDATE_DATE |
| `stg_cts_address` | `dpd.ADDRESS` | `common.ADDR_WV` | Map PK→ADDRESS_CODE, COUNTRY_FK→COUNTRY_CODE, PROVINCE_FK→PROVINCE_CODE, ADDR_LINE_1→STREET_NAME |
| `stg_cts_address_orig` | `dpd.ADDRESS_ORIG` | `common.ADDR_DETAIL` | Map ADDR_FK→ADDRESS_CODE, LOCATION→ATTENTION_TO, TS→LAST_UPDATE_DATE |
| `stg_cts_company_contact` | `dpd.COMPANY_CONTACT` | `common.ORG_CONTACT_WV` | Map ORG_COMPANY_CODE_RO→COMPANY_CODE, CONTACT_FK→CONTACT_CODE |
| `stg_cts_company_type` | `dpd.COMPANY_TYPE` | `common.ORG_TYPE` | Map ORG_TYPE_FK→COMPANY_TYPE_CODE, ORG_TYPE_DESC_EN (or FR — TBD)→COMPANY_TYPE_DESC, INACTIVE_DATE |
| `stg_cts_country` | `dpd.COUNTRY` | `common.COUNTRY` | Direct column mapping |
| `stg_cts_province` | `dpd.PROVINCE` | `common.PROVINCE` | Direct column mapping |
| `stg_cts_salutation` | `dpd.SALUTATION` | `common.SALUTATION` | Direct column mapping |

SP steps 3.1–4 read these tables with **no code changes required**.

#### B) Legacy link staging tables — KEPT FOR BACKWARD COMPATIBILITY

| Staging Table | Current Source |
|---|---|
| `stg_cts_company_address_link` | `dpd.COMPANY_ADDRESS_LINK` |
| `stg_cts_sub_company_address_link` | `dpd.SUB_COMPANY_ADDRESS_LINK` |

Confirmed DDL for `stg_cts_company_address_link`:
```
COMPANY_ID (PK), DIN_COMPANY_CODE, ADDRESS_CODE, CONTACT_CODE,
MAILING_FLAG, BILLING_FLAG, NOTIFICATION_FLAG, OTHER_FLAG,
COMPANY_TYPE_CODE, STANDARD_COMM_MTD, ETL_*
```

Confirmed DDL for `stg_cts_sub_company_address_link`:
```
COMPANY_ID (PK), DIN_COMPANY_CODE, COMPANY_CODE, ADDRESS_CODE, CONTACT_CODE,
MAILING_FLAG, BILLING_FLAG, NOTIFICATION_FLAG, OTHER_FLAG,
COMPANY_TYPE_CODE, ETL_*
```

These remain populated for backward compatibility until SP v3 is fully validated end-to-end, then can be retired.

#### C) Net-new staging tables — CREATED FOR SP V3 STEPS 5–6

| Staging Table | Source | DDL File |
|---|---|---|
| `stg_cts_org_addr` | `common.ORG_ADDR_WV` | `schema/nbt537_stg_cts_org_addr.sql` |
| `stg_cts_org_addr_contact` | `common.ORG_ADDR_CONTACT_WV` | `schema/nbt537_stg_cts_org_addr_contact.sql` |
| `stg_cts_org_profile` | `dp.ORG_PROFILE_WV` | `schema/nbt537_stg_cts_org_profile.sql` |

SP steps 5–6 use these new tables with `_RO` columns for resolving into `bts_ref_org_addr` / `bts_ref_org_addr_contact`.

### Confirmed DDL for `stg_cts_company_type`

```
COMPANY_TYPE_CODE (PK), COMPANY_TYPE_DESC, INACTIVE_DATE, ETL_*
```

### What was corrected

1. **Prior incorrect claim:** SP steps 3.1–4 must be rewritten to common/dp native column names. **Correction:** staging tables remain DPD-shaped; Informatica remaps at load time. SP is unchanged.
2. **Prior incorrect claim:** `stg_cts_company_type` needs renaming to `stg_cts_org_type`. **Correction:** keep existing table; only change source from `dpd.COMPANY_TYPE` to `common.ORG_TYPE`.

### Pending confirmations (pre-cutover)

1. **`stg_cts_company_type` mapping rule:** `COMPANY_TYPE_DESC` is `VARCHAR(50)`. `common.ORG_TYPE` has EN/FR; pick one (likely EN) or implement preference/concat/truncate rule.
2. **`stg_cts_address_orig` from `common.ADDR_DETAIL`:** rowcount was observed as 0 earlier; confirm whether LOCATION should populate ATTENTION_TO (may be empty, still include mapping).
3. **`stg_cts_org_addr_contact`** must include `ORG_FK_RO` + `ADDR_FK_RO` populated (required by SP v3 join into `bts_ref_org_addr`).
4. **Post-ETL validation:** `stg_cts_company` count should align with `common.ORG_WV` (~14,840) not `dpd.COMPANY` (~14,707). Spot check DIN owner/billing/notify resolution rates.

---

## 10. SUMMARY

### What this file is

A dedicated workstream note for BTS CTS / DPD company-reference refresh and migration activity.

### What it is not

- not a final production ETL spec
- not a full data lineage document
- not proof that all listed objects remain unchanged in the current environment

### Practical use

Use this file when troubleshooting or extending the organization/reference refresh pipeline feeding BTS, especially around `sp_refresh_cts_dpd_company_refs` and related load / stage / reference objects.
