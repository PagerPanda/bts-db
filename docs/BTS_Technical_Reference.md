# BTS Technical Reference

> Context primer for coding, troubleshooting, and system reasoning on the BTS system.
> Revised from prior extracted notes and corrected against established BTS session context.
> **Important:** inventories below are **selective, not exhaustive**, unless explicitly stated otherwise.

---

## 1. SYSTEM OVERVIEW

### BTS — Biocides Tracking System

| Property                        | Value                                      |
| ------------------------------- | ------------------------------------------ |
| **DB Engine**                   | MySQL 8.x                                  |
| **Primary Schema**              | `bts_appian_rt`                            |
| **Frontend / Workflow Layer**   | Appian                                     |
| **Primary SQL Clients (local)** | MySQL Workbench / equivalent MySQL tooling |

### Scope

BTS is the operational tracking system for biocides dossier, regulatory activity, market authorization, and related business workflow. It is implemented in Appian with MySQL backing tables, views, and stored procedures, and it also interacts with ETL / refresh processes that populate reference and organization-related data.

### Core system model

* `bts_appian_rt` is the primary runtime schema for BTS operational tables, reference tables, ETL support tables, views, and procedures.
* Appian record types and process models sit above the MySQL schema and drive user workflow, locking, create/update flows, and record-based UI logic.
* View definitions and stored procedures are key sources of truth for derived logic, ranking, and refresh behaviour.
* Some BTS areas contain historical naming debt and legacy modelling choices that must be respected as-is in SQL and Appian integration.

---

## 2. AUTHORITATIVE REFERENCES

### Primary sources of truth

1. **Live `bts_appian_rt` schema** — source of truth for actual table and column names
2. **Appian record types / process models** — source of truth for Appian integration behaviour
3. **View definitions / stored procedures** — source of truth for current derived logic
4. **Approved ticket / design artifacts** — source of truth for active refactors not yet fully deployed

### Practical rule

When exact behaviour matters:

* verify object definitions directly in MySQL
* verify Appian expressions / process variables directly in Appian
* verify active refactor design against the current approved ticket or implementation branch

---

## 3. CORE SCHEMA ANCHORS

The following objects have been repeatedly important in prior BTS work and should be treated as core schema anchors for future SQL / troubleshooting:

| Object                                | Notes                                                                                     |
| ------------------------------------- | ----------------------------------------------------------------------------------------- |
| `bts_regulatory_activity`             | Key columns include `RA_TARGET_DATE`, `STATUS_TARGET_DATE`, `CONTROL_NUMBER_ID`, `STATUS` |
| `bts_dossier`                         | Key identifier column includes `ID`                                                       |
| `bts_market_authorization`            | Key columns include `BIOCIDE_IDENTIFICATION_NO`, `STATUS`                                 |
| `bts_product`                         | Key columns include `PRIMARY_BRAND_NAME_EN`, `PRIMARY_BRAND_NAME_FR`                      |
| `bts_ref_nhpid_reg_activity_type`     | Key reference table for regulatory activity type                                          |
| `bts_ref_submission_class`            | Key reference table for submission class                                                  |
| `bts_ref_nhpid_reg_activity_status`   | Key reference table for RA status                                                         |
| `bts_ref_market_authorization_status` | Key reference table for MA-related status / code work                                     |
| `bts_dossier_organization`            | Key dossier-organization linkage table                                                    |
| `bts_ref_org`                         | Key organization reference table                                                          |

### Historical / legacy naming cautions

* `bts_ref_nhpid_reg_activity_status` is a BTS table despite the `nhpid` naming.
* `bts_product.REGULATORY_ACTIVTY_FK` is intentionally misspelled in the live schema and must be used exactly as named.
* `bts_market_authorization.STATUS` is a legacy overloaded field and is part of active refactor work under NBT522.

---

## 4. CORE OPERATIONAL TABLES

> Selective operational inventory for orientation. This is not a full BTS data dictionary.

### `bts_dossier`

Top-level dossier container. Much BTS workflow hangs off the dossier.

**Key columns previously referenced**

```sql
PK, ID, CREATED_ON, CREATED_BY, MODIFIED_ON, MODIFIED_BY
```

### `bts_regulatory_activity`

Primary regulatory-activity work table.

**Key columns previously referenced**

```sql
PK
DOSSIER_FK
CONTROL_NUMBER_ID
REGULATORY_ACTIVITY_LEAD_CODE
REGULATORY_ACTIVITY_TYPE_CODE
FILING_FIRST_SUBMISSION_IND
SUBMISSION_CLASS_CODE
ASSIGNED_ON
ASSIGNED_TO
STATUS
FILING_DATE
CREATED_BY, CREATED_ON
MODIFIED_BY, MODIFIED_ON
LOCK_RECORD, LOCK_RECORD_BY
RA_TARGET_DATE
STATUS_TARGET_DATE
REGULATORY_ACTIVITY_STATUS_FK
```

### Important note

There is **no `IS_ACTIVE` column** on `bts_regulatory_activity`. In prior SQL / view logic, recency was often derived using:

* `COALESCE(STATUS_TARGET_DATE, RA_TARGET_DATE, MODIFIED_ON, CREATED_ON)`

This is useful **query logic**, but should not be treated as a universal business invariant without checking the active view / report definition.

### `bts_market_authorization`

Market authorization header-level table.

**Key columns previously referenced**

```sql
PK
DOSSIER_FK
IS_ACTIVE
STATUS
BIOCIDE_IDENTIFICATION_NO
```

### Important note

`STATUS` is a **legacy overloaded field**. Historically it has been used in ways that blur authorization-state and operational-status meanings. Active refactor work under **NBT522** separates these concepts more explicitly.

### `bts_product`

Product table linked to dossier and, in practice, to regulatory activity.

**Key columns previously referenced**

```sql
PK
DOSSIER_FK
PRIMARY_BRAND_NAME_EN
PRIMARY_BRAND_NAME_FR
IS_ACTIVE
REGULATORY_ACTIVTY_FK
```

### Critical schema caution

The live column name is:

* `REGULATORY_ACTIVTY_FK`

That typo is real and must be used as-is in SQL, views, joins, and Appian-related work.

---

## 5. KEY REFERENCE TABLES AND COMMON JOIN CAUTIONS

### `bts_ref_nhpid_reg_activity_status`

Reference table used for RA status classification.

**Typical relevant columns**

```sql
PK
CODE
REGULATORY_ACTIVITY_STATUS_EN
```

### Correct join pattern

```sql
bts_ref_nhpid_reg_activity_status rs
  ON rs.PK = ra.REGULATORY_ACTIVITY_STATUS_FK
```

### Common mistake

Do **not** join on a nonexistent column such as:

```sql
rs.REGULATORY_ACTIVITY_FK = ra.PK
```

That leads to MySQL error 1054 for unknown column.

### Related core reference tables

The following are recurring reference tables in BTS work:

* `bts_ref_nhpid_reg_activity_type`
* `bts_ref_submission_class`
* `bts_ref_market_authorization_status`
* `bts_ref_org`

When implementing logic that depends on business semantics, always confirm whether the semantic source is:

* table code values
* view logic
* Appian logic
* ticket-specific mapping rules

---

## 6. KNOWN VIEWS / DERIVED LOGIC SURFACES

> These are key BTS views referenced in prior work. Verify exact existence and definition in the target environment.

| View                                  | Notes                                                                                   |
| ------------------------------------- | --------------------------------------------------------------------------------------- |
| `bts_view_dossier`                    | Main dossier rollup joining dossier + product + RA + market + organization-related data |
| `bts_view_dossier_organization`       | Organization / company information per dossier                                          |
| `bts_view_dossier_recent_approved_ra` | Most recent approved RA per dossier using ranking logic                                 |
| `bts_view_dossier_recent_draft_ra`    | Most recent pending / draft-like RA per dossier using ranking logic                     |

### Practical rule

If a query seems to duplicate a BTS view's purpose, inspect the actual view definition before re-implementing the logic ad hoc.

---

## 7. COMMON SQL / VIEW LOGIC PATTERNS

> These are **working patterns used in prior BTS SQL / view logic**, not guaranteed universal business definitions.

### RA status classification patterns

#### Approved / authorized-like

```sql
rs.CODE IN ('APPROVED','MARKET','MA','AUTHORIZED')
   OR rs.REGULATORY_ACTIVITY_STATUS_EN IN ('APPROVED','MARKET AUTHORIZED')
```

#### Pending / draft-like

```sql
rs.CODE IN ('UNDER_CONSIDERATION','UNDER_RECONSIDERATION','SCREENING','SCRREC','INACTIVE_RECONSIDERATION')
AND rs.CODE NOT IN ('REJECTED','CANCEL','CANCEL_REVIEW','WITHDRAWN','INACTIVE')
```

#### Terminal / negative

```sql
rs.CODE IN ('REJECTED','CANCEL','CANCEL_REVIEW','WITHDRAWN','INACTIVE')
```

### Most recent RA per dossier — ranking pattern

This ranking style has been used in recent-approved / recent-draft dossier logic and similar ad hoc SQL.

```sql
WITH ranked AS (
  SELECT
      ra.DOSSIER_FK,
      ra.PK AS RA_PK,
      p.PRIMARY_BRAND_NAME_EN,
      p.PRIMARY_BRAND_NAME_FR,
      ROW_NUMBER() OVER (
        PARTITION BY ra.DOSSIER_FK
        ORDER BY COALESCE(
                 ra.STATUS_TARGET_DATE,
                 ra.RA_TARGET_DATE,
                 ra.MODIFIED_ON,
                 ra.CREATED_ON
               ) DESC,
               ra.PK DESC
      ) AS rn
  FROM bts_regulatory_activity ra
  JOIN bts_ref_nhpid_reg_activity_status rs
    ON rs.PK = ra.REGULATORY_ACTIVITY_STATUS_FK
  LEFT JOIN bts_product p
    ON p.DOSSIER_FK = ra.DOSSIER_FK
   AND p.IS_ACTIVE = 1
  WHERE rs.CODE IN ('APPROVED','MARKET','MA','AUTHORIZED')
)
SELECT DOSSIER_FK, RA_PK, PRIMARY_BRAND_NAME_EN, PRIMARY_BRAND_NAME_FR
FROM ranked
WHERE rn = 1;
```

### Important caution

Treat this as a **ranking pattern**, not a universal legal/business rule. If the output is business-critical, verify against the active view or approved reporting logic.

### FK discovery pattern

Useful for delete planning and schema analysis.

```sql
SELECT
    kcu.CONSTRAINT_SCHEMA,
    kcu.TABLE_NAME,
    kcu.COLUMN_NAME,
    kcu.CONSTRAINT_NAME,
    kcu.REFERENCED_TABLE_NAME,
    kcu.REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
WHERE kcu.REFERENCED_TABLE_NAME = '<your_table>'
  AND kcu.REFERENCED_COLUMN_NAME = 'PK'
ORDER BY CONSTRAINT_SCHEMA, TABLE_NAME;
```

---

## 8. OBSERVED FK DELETE TOPOLOGY — `bts_regulatory_activity`

> Observed child-table inventory from prior work. Always re-query `INFORMATION_SCHEMA.KEY_COLUMN_USAGE` before assuming the list is complete.

When deleting from `bts_regulatory_activity`, prior work identified the following FK children as needing clearance first:

| Table                              | FK Column                | Constraint Name                                     |
| ---------------------------------- | ------------------------ | --------------------------------------------------- |
| `bts_audit_regulatory_activity`    | `REGULATORY_ACTIVITY_FK` | —                                                   |
| `bts_document_regulatory_activity` | `REGULATORY_ACTIVITY_FK` | `DocumentRegulatoryActivityRegulatoryActivity_FK`   |
| `bts_note_regulatory_activity`     | `REGULATORY_ACTIVITY_FK` | `NoteRegulatoryActivityRegulatoryActivity_FK`       |
| `bts_ra_fee`                       | `REGULATORY_ACTIVITY_FK` | `BTS_RA_FEE_REGULATORY_ACTIVITY_FK`                 |
| `bts_ra_status_history`            | `REGULATORY_ACTIVITY_FK` | `RAStatusHistoryRegulatoryActivityFK_FK`            |
| `bts_related_transaction`          | `REGULATORY_ACTIVITY_FK` | `BTS_RELATED_TRANSACTION_REGULATORY_ACTIVITY_FK_FK` |
| `bts_product`                      | `REGULATORY_ACTIVTY_FK`  | `BTS_PRODUCT_REGULATORY_ACTIVITY_FK`                |

### Important caution

The `bts_product` row is easy to miss because of the typo column name:

* `REGULATORY_ACTIVTY_FK`

### Discovery query

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

## 9. APPIAN INTEGRATION NOTES

> These notes reflect prior BTS/Appian implementation work and should be validated against the current Appian object model.

### Appian record type mappings previously referenced

| Appian Record Type                    | Maps To                               |
| ------------------------------------- | ------------------------------------- |
| `BTS_Product`                         | `bts_product`                         |
| `BTS_Dossier`                        | `bts_dossier`                         |
| `BTS_Regulatory_Activity`             | `bts_regulatory_activity`             |
| `BTS_Product_Container`               | `bts_product_container`               |
| `BTS_Product_Brand_Name`              | `bts_product_brand_name`              |
| `BTS_Product_Active_Ingredient`       | `bts_product_active_ingredient`       |
| `BTS_Product_Use_Setting`             | `bts_product_use_setting`             |
| `BTS_Product_Use_Purpose`             | `bts_product_use_purpose`             |
| `BTS_Product_Method_Of_Application`   | `bts_product_method_of_application`   |
| `BTS_Product_Monograph`               | `bts_product_monograph`               |
| `BTS_Product_Detail`                  | `bts_product_detail`                  |
| `BTS_Product_Comparison`              | `bts_product_comparison`              |
| `BTS_Product_Use_Of_Foreign_Decision` | `bts_product_use_of_foreign_decision` |

### Process model context previously referenced

* Process: `BTS Create Or Update Product (2.0)`
* Key node: `Get Product Lock Info`

### Previously referenced PV inputs to that node

* `BTS_Product`
* `pk`
* `regulatoryActivtyFK`
* `dossierFK`
* `status`
* `lockRecord`
* `lockRecordBy`

### Caution

The Appian side may intentionally mirror backend naming debt, including:

* `regulatoryActivtyFK` typo-like naming aligned to `REGULATORY_ACTIVTY_FK`

---

## 10. TROUBLESHOOTING / KNOWN DEFECTS

### 10.1 BIOCIDE_IDENTIFICATION_NO non-digit contamination

#### Symptom

`LPAD(..., 8, '0')` returns no effective changes even though rows appear to match.

#### Root cause

Some `BIOCIDE_IDENTIFICATION_NO` values contain embedded non-digit bytes such as:

* carriage return (`0D`)
* non-breaking space (`A0`)

#### Diagnostic pattern

```sql
SELECT BIOCIDE_IDENTIFICATION_NO,
       CHAR_LENGTH(BIOCIDE_IDENTIFICATION_NO) AS len,
       HEX(BIOCIDE_IDENTIFICATION_NO) AS raw_hex
FROM bts_appian_rt.bts_market_authorization
WHERE STATUS = 'APPROV';
```

#### Cleanup pattern

```sql
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

### Practical rule

When handling BIN values, sanitize to digits before doing length checks, padding, or comparisons.

---

### 10.2 Appian create-path null identifier bug

#### Error

```text
a!queryRecordByIdentifier identifier cannot be null or empty
```

#### Context

* Process: `BTS Create Or Update Product (2.0)`
* Node: `Get Product Lock Info`

#### Root cause

On the create path, `pk` does not yet exist, but the expression attempts to query by identifier using a null value from the record/process state.

#### Working fix pattern

1. In node Data Inputs, find the value containing `a!queryRecordByIdentifier`
2. Use `pv!pk` as the identifier source rather than digging into an unsaved record
3. Add a run condition such as:

```text
not(isnull(pv!pk))
```

#### Practical rule

Any Appian node that queries a record by identifier must be guarded on create flows where the PK has not yet been persisted.

---

### 10.3 Wrong RA status join

#### Error

MySQL 1054 unknown column in join clause.

#### Cause

Incorrect join logic against `bts_ref_nhpid_reg_activity_status`.

#### Correct pattern

```sql
bts_ref_nhpid_reg_activity_status rs
  ON rs.PK = ra.REGULATORY_ACTIVITY_STATUS_FK
```

---

### 10.4 Live schema typo on product→RA FK

This is not merely a one-off bug; it is a persistent schema truth:

* `bts_product.REGULATORY_ACTIVTY_FK` is the live column name
* do not silently "correct" it to `REGULATORY_ACTIVITY_FK` in SQL or Appian logic

---

## 11. INTEGRATION / REFRESH CONTEXT

### Broader integration pattern

Prior BTS work included CTS/DPD → BTS runtime/reference refresh design and implementation work, including nightly / repeatable refresh concepts into `bts_appian_rt`.

### Key workstream example

* `sp_refresh_cts_dpd_company_refs`

This workstream is part of the broader BTS system mental model because organization/company reference data and related structures are populated and maintained through ETL / refresh processes, not only by direct user-facing Appian CRUD.

---

## 12. NBT522 — MA State/Status Refactor

> Full design extracted to [`docs/BTS_NBT522_Workstream.md`](BTS_NBT522_Workstream.md) to reduce auto-load token cost. Read that file when working on NBT522.

---

## 13. sp_refresh ETL Workstream

> Full ETL table inventory extracted to [`docs/BTS_CTS_DPD_Refresh_Workstream.md`](BTS_CTS_DPD_Refresh_Workstream.md) to reduce auto-load token cost. Read that file when working on the company refresh procedure.

---

## 14. SUMMARY

### What this document is

A corrected **technical context primer** for BTS architecture, schema anchors, Appian integration, common SQL patterns, and troubleshooting.

### Primary mental model

1. **Use the live `bts_appian_rt` schema** for actual object names
2. **Use view definitions and procedures** for derived/ranked logic
3. **Use Appian object definitions** for create/update/lock/UI behaviour
4. **Treat legacy naming debt as real schema truth**
5. **Treat NBT522 and company-refresh work as implementation context until verified as deployed**

---

*Updated: 2026-02-28 | v3 — Sections 12-13 extracted to companion docs for token efficiency*
