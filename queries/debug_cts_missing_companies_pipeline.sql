-- ============================================================================
-- File:        debug_cts_missing_companies_pipeline.sql
-- Ticket:      NBT537 / NBT568
-- Author:      Claude / BTS DB team
-- Date:        2026-03-03
-- Engine:      MySQL 8.0
-- Schema:      (run in the actual target BTS schema — no hardcoded qualifiers)
-- Description: Layer-by-layer diagnostic to trace missing companies through
--              the CTS→BTS refresh pipeline.
--
-- Usage:       Connect to the target BTS schema (e.g. bts_appian_dv) and
--              run each query in order. The results will identify which
--              pipeline layer the company drops off at.
--
-- Pipeline:    CTS SQL Server → Informatica → bts_load_org
--              → bts_view_load_org → stg_cts_company
--              → sp_refresh_cts_company_refs → bts_ref_org
-- ============================================================================

-- 0) Confirm current schema
SELECT DATABASE() AS current_schema;

-- ============================================================================
-- SECTION 1: Quick check — does the company exist at SP output and input?
-- ============================================================================

-- 1) Check final SP output (bts_ref_org)
SELECT PK, ORG_NAME, IS_ACTIVE, TS, UPDATED_BY
FROM bts_ref_org
WHERE PK = 22179;

-- 2) Check SP input (stg_cts_company)
SELECT COMPANY_CODE, COMPANY_NAME, ETL_DATE_STAMP, INACTIVATION_DATE
FROM stg_cts_company
WHERE COMPANY_CODE = 22179;

-- ============================================================================
-- SECTION 2: Staging freshness — is the extract stale?
-- ============================================================================

-- 3) Staging freshness / ceiling
SELECT
  MAX(COMPANY_CODE)    AS max_company_code,
  MAX(ETL_DATE_STAMP)  AS max_etl_date,
  MIN(ETL_DATE_STAMP)  AS min_etl_date,
  COUNT(*)             AS total_companies
FROM stg_cts_company;

-- 4) ETL date distribution (most recent first)
SELECT
  DATE(ETL_DATE_STAMP) AS etl_date,
  COUNT(*)             AS company_count
FROM stg_cts_company
WHERE ETL_DATE_STAMP IS NOT NULL
GROUP BY DATE(ETL_DATE_STAMP)
ORDER BY etl_date DESC
LIMIT 20;

-- ============================================================================
-- SECTION 3: Load layer — confirm objects exist, then probe
-- ============================================================================

-- 5) Confirm load-layer objects exist before querying
SELECT TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('bts_load_org', 'bts_view_load_org', 'bts_initial_load_org');

-- 6) If bts_load_org exists:
SELECT *
FROM bts_load_org
WHERE COMPANY_CODE = 22179;

-- 7) If bts_view_load_org exists — inspect definition for WHERE clauses / filters:
SHOW CREATE VIEW bts_view_load_org;

SELECT *
FROM bts_view_load_org
WHERE COMPANY_CODE = 22179;

-- 8) If bts_initial_load_org exists:
SELECT *
FROM bts_initial_load_org
WHERE COMPANY_CODE = 22179;

-- ============================================================================
-- INTERPRETATION
-- ============================================================================
--
-- Missing from stg_cts_company:
--   Issue is upstream of SP. Most likely Informatica extract/source freshness.
--
-- Present in bts_load_org but missing from stg_cts_company:
--   Staging transform/view/filter issue — inspect bts_view_load_org definition.
--
-- Present in stg_cts_company but missing from bts_ref_org right after refresh:
--   Inspect SP execution/schema targeting. First confirm you refreshed the
--   correct schema and are not inspecting stale target data in another env.
--
-- MAX(COMPANY_CODE) < 22179 or ETL dates are stale:
--   Very strong sign the source feed is old/incomplete. Escalate to
--   ETL/Informatica team — likely extracting from dpd.* instead of
--   canonical common.*_WV views.
-- ============================================================================
