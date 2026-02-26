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

DELIMITER //

CREATE PROCEDURE bts_appian_rt.sp_<name>(
    IN p_param1 INT,
    IN p_user   VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Procedure logic here

    COMMIT;
END //

DELIMITER ;
