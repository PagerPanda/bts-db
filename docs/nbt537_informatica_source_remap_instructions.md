-- ============================================================================
-- File:        nbt537_informatica_source_remap_instructions.md
-- Ticket:      NBT537 / NBT568
-- Author:      BTS DB team
-- Date:        2026-03-05
-- Description: Ready-to-send Informatica instruction for CTS/DPD company
--              refresh source remap from dpd.* to common.*/dp.* schema.
--              Includes keep/change/add/supersede/untouched matrix,
--              SP impact summary, and validation guidance.
-- ============================================================================

# BTS CTS/DPD Company Refresh — Source Remap to common/dp Schema (TEST)

## Context

The BTS nightly company-reference refresh currently sources from `dpd.*` objects.
Testing showed the org/company population differs between `dpd.COMPANY` and the
authoritative CTS views (e.g., `common.ORG_WV`), and the `common.*` / `dp.*` views
provide the complete "org profiling" model required for BTS (org + contacts +
addresses + org profile + org type).

## Scope

Update Informatica mappings that populate the existing `stg_cts_*` staging tables
in `bts_appian_dv` (TEST). No staging table renames — we keep existing staging
table names wherever possible.

---

## A) Existing staging tables — KEEP TABLE, CHANGE SOURCE ONLY

These staging tables already exist in `bts_appian_dv`. Keep the same target table
name and general layout. Only update the Informatica source object and apply
column-to-column mapping as required:

| Staging table (unchanged) | Phase 1 current source | New source (authoritative) |
|--------------------------|----------------------|---------------------------|
| `stg_cts_company` | `dpd.COMPANY` | `common.ORG_WV` |
| `stg_cts_company_contact` | `dpd.COMPANY_CONTACT` | `common.ORG_CONTACT_WV` |
| `stg_cts_company_type` | `dpd.COMPANY_TYPE` | `common.ORG_TYPE` |
| `stg_cts_contact` | `dpd.CONTACT` | `common.CONTACT` |
| `stg_cts_address` | `dpd.ADDRESS` | `common.ADDR_WV` |
| `stg_cts_address_orig` | `dpd.ADDRESS_ORIG` | `common.ADDR_DETAIL` |
| `stg_cts_country` | `dpd.COUNTRY` | `common.COUNTRY` |
| `stg_cts_province` | `dpd.PROVINCE` | `common.PROVINCE` |
| `stg_cts_salutation` | `dpd.SALUTATION` | `common.SALUTATION` |

Note: this is intentionally not a rename. We preserve the `stg_cts_*` nomenclature
and only swap sources + map columns.

## B) Net-new staging tables — CREATE + ADD TO NIGHTLY ETL

These staging tables do not exist today (based on the current list) and must be
created in `bts_appian_dv`, populated nightly, and then consumed by the refreshed SP:

| New staging table | Source object | Purpose |
|-------------------|--------------|---------|
| `stg_cts_org_addr` | `common.ORG_ADDR_WV` | Org-to-address associations (replaces link-table logic in SP) |
| `stg_cts_org_addr_contact` | `common.ORG_ADDR_CONTACT_WV` | Org-address-to-contact associations |
| `stg_cts_org_profile` | `dp.ORG_PROFILE_WV` | Per-org profile assignments (DIN owner / billing / notification + org type FKs) |

**Important:** schema is `dp.ORG_PROFILE_WV` (not `dpd.*`).

## C) Superseded staging tables — KEEP FOR NOW (do not delete yet)

These Phase 1 staging tables are expected to become unused by the SP after refactor,
but should remain until end-to-end validation is completed:

| Staging table | Status after SP refactor |
|---------------|------------------------|
| `stg_cts_company_address_link` | Superseded by `stg_cts_org_addr` + `stg_cts_org_addr_contact` + `stg_cts_org_profile` |
| `stg_cts_sub_company_address_link` | Same — superseded |

## D) Untouched staging tables — NO CHANGES

Leave these as-is:

- `stg_cts_address_hist`
- `stg_cts_dpd_email_notification_type`
- `stg_cts_dpd203_report_addr_contact`
- `stg_cts_dpd203_report_addresses`
- `stg_cts_dpd203_report_company_types`
- `stg_cts_dpd203_report_products`

## E) Validation / retirement guidance (explicit)

- Please do **not** delete any Phase 1 sources or staging tables yet.
- After the new sources are populated, we will validate:
  - staging row counts vs CTS sources,
  - SP output counts in BTS reference tables,
  - spot-check key orgs that were missing before.
- Once validated, we will confirm which Phase 1 Informatica source objects can be retired.

## Ask

Please implement Section A source remaps and Section B new staging objects in the
TEST nightly ETL. Once populated, we'll validate and run the updated stored
procedure end-to-end.

---

## SP Impact Summary

| SP section | Change? | What changes |
|-----------|---------|-------------|
| Steps 0–4, 3.1–3.7 | **No** | Same staging table names; source swapped upstream via Informatica |
| Step 5.1 ORG_ADDR | **Yes** | Stop reading `stg_cts_company_address_link` / `stg_cts_sub_company_address_link`; read `stg_cts_org_addr` |
| Step 5.2 ORG_ADDR_CONTACT | **Yes** | Stop reading the two link tables; read `stg_cts_org_addr_contact` |
| Step 6 ORG_PROFILE | **Yes** | Replace 220-line deterministic selector/tie-break logic with direct read from `stg_cts_org_profile` (authoritative) |

## Column Layouts Already Captured

We already have the column lists + sample rows for:

- `common.ORG_ADDR_WV`
- `common.ORG_ADDR_CONTACT_WV`
- `dp.ORG_PROFILE_WV`

If the Informatica developer needs column-to-column mapping for the Section A
remaps (e.g., `common.ORG_WV` → `stg_cts_company`), we can provide it, but it's
not a blocker to proceed with adding the sources and creating the new staging objects.

---

## Current Staging Tables Snapshot

### Keep table name, change source (Informatica)

- `stg_cts_company` (source becomes `common.ORG_WV`)
- `stg_cts_company_contact` (source becomes `common.ORG_CONTACT_WV`)
- `stg_cts_company_type` (source becomes `common.ORG_TYPE`)
- `stg_cts_contact` (source becomes `common.CONTACT`)
- `stg_cts_address` (source becomes `common.ADDR_WV`)
- `stg_cts_address_orig` (source becomes `common.ADDR_DETAIL`)
- `stg_cts_country` (source becomes `common.COUNTRY`)
- `stg_cts_province` (source becomes `common.PROVINCE`)
- `stg_cts_salutation` (source becomes `common.SALUTATION`)

### Net-new tables to create

- `stg_cts_org_addr` (from `common.ORG_ADDR_WV`)
- `stg_cts_org_addr_contact` (from `common.ORG_ADDR_CONTACT_WV`)
- `stg_cts_org_profile` (from `dp.ORG_PROFILE_WV`)

### Superseded (keep for now; eventually unused by SP)

- `stg_cts_company_address_link`
- `stg_cts_sub_company_address_link`

### Untouched

- `stg_cts_address_hist`
- `stg_cts_dpd_email_notification_type`
- `stg_cts_dpd203_report_*` (all currently present)
