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

-- View definer: `bts_appian_owner_dv`@`%`

CREATE OR REPLACE
ALGORITHM = UNDEFINED
DEFINER = `bts_appian_owner_dv`@`%`
SQL SECURITY DEFINER
VIEW `bts_appian_rt`.`bts_view_<name>` AS
SELECT
    -- columns here
FROM bts_appian_rt.<table>
-- JOIN ...
-- WHERE ...
;
