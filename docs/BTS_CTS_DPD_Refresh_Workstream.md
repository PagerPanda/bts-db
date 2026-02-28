# sp_refresh_cts_dpd_company_refs — ETL / Migration Workstream

> This document captures a major active BTS ETL / migration workstream from prior sessions. Treat row counts and exact inventories as point-in-time observations unless revalidated.
>
> Extracted from `BTS_Technical_Reference.md` Section 13 to reduce auto-load token cost.

---

## Overview

* **Stored Procedure:** `sp_refresh_cts_dpd_company_refs`
* **Theme:** SQL Server to MySQL migration / refresh for company and organization reference data
* **Status in prior sessions:** active workstream across Jan-Feb 2026

## Point-in-time migrated-row observations

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

## ETL footprint observed during procedure work

### Load tables

* `bts_load_address`
* `bts_load_address_detail`
* `bts_load_contact`
* `bts_load_country`
* `bts_load_org`
* `bts_load_org_addr`
* `bts_load_org_addr_contact`
* `bts_load_org_contact`
* `bts_load_org_profile`
* `bts_load_province`
* `bts_load_salutation`
* `bts_initial_load_org`

### Stage tables

* `bts_stage_address`
* `bts_stage_address_detail`
* `bts_stage_contact`
* `bts_stage_country`
* `bts_stage_org`
* `bts_stage_org_addr`
* `bts_stage_org_addr_contact`
* `bts_stage_org_contact`
* `bts_stage_org_profile`
* `bts_stage_province`
* `bts_stage_salutation`

### Reference tables

* `bts_ref_address`
* `bts_ref_address_detail`
* `bts_ref_contact`
* `bts_ref_country`
* `bts_ref_org`
* `bts_ref_org_addr`
* `bts_ref_org_addr_contact`
* `bts_ref_org_contact`
* `bts_ref_org_profile`
* `bts_ref_province`
* `bts_ref_salutation`

### Other supporting table

* `bts_tmp_country`

### Load views

* `bts_view_load_addr_detail`
* `bts_view_load_address`
* `bts_view_load_contact`
* `bts_view_load_country`
* `bts_view_load_org`
* `bts_view_load_org_addr`
* `bts_view_load_org_addr_contact`
* `bts_view_load_org_contact`
* `bts_view_load_org_profile`
* `bts_view_load_province`
* `bts_view_load_salutation`

## Practical takeaway

This workstream confirms that BTS includes a meaningful ETL / reference-refresh layer inside `bts_appian_rt`, not just user-facing operational tables.

---

*Extracted: 2026-02-28 | Source: BTS_Technical_Reference.md Section 13*
