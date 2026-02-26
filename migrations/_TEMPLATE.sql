-- ============================================================================
-- File:        <filename>.sql
-- Ticket:      <JIRA ticket, e.g. NBT522>
-- Author:      <name>
-- Date:        <YYYY-MM-DD>
-- Environment: DEV / TEST / PROD
-- Engine:      MySQL 8.0
-- Schema:      bts_appian_rt
-- Description: <brief description>
-- ============================================================================

-- STEP 1: Preview — verify rows to be affected
-- SELECT * FROM bts_appian_rt.<table> WHERE <condition>;

-- STEP 2: Execute migration
START TRANSACTION;

-- DML goes here (INSERT, UPDATE, DELETE)

-- Verify result
-- SELECT ROW_COUNT() AS rows_affected;

COMMIT;
