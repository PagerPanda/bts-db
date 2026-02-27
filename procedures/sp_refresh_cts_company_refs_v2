DELIMITER $$

DROP PROCEDURE IF EXISTS sp_refresh_cts_company_refs $$

CREATE DEFINER=`bts_appian_owner_test`@`%` PROCEDURE `sp_refresh_cts_company_refs`(
    IN p_src_schema        VARCHAR(64),   -- schema containing stg_cts_* tables (dev: bts_appian_dv)
    IN p_updated_by        VARCHAR(200),  -- e.g., 'CTS_DPD_NIGHTLY'
    IN p_org_type_mode     VARCHAR(10)    -- 'DIRECT' or 'NULL'
)
BEGIN
    DECLARE v_lock_ok INT DEFAULT 0;
    DECLARE v_old_fk  INT DEFAULT 1;

    /* handlers must be declared before any statements */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET FOREIGN_KEY_CHECKS = v_old_fk;
        DO RELEASE_LOCK('sp_refresh_cts_company_refs');
        RESIGNAL;
    END;

    /* -----------------------------
       Input hardening
       ----------------------------- */
    IF p_src_schema IS NULL OR p_src_schema = '' OR p_src_schema NOT REGEXP '^[0-9A-Za-z_]+$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid p_src_schema. Use only letters, digits, underscore.';
    END IF;

    IF p_org_type_mode IS NULL OR p_org_type_mode = '' THEN
        SET p_org_type_mode = 'NULL';
    END IF;

    /* PREPARE/EXECUTE USING requires USER variables */
    SET @p_updated_by    := p_updated_by;
    SET @p_org_type_mode := p_org_type_mode;

    /* -----------------------------
       0) Single-run lock
       ----------------------------- */
    SELECT GET_LOCK('sp_refresh_cts_company_refs', 0) INTO v_lock_ok;
    IF v_lock_ok <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Refresh already running (GET_LOCK failed).';
    END IF;

    SET SESSION sql_safe_updates = 0;

    /* -----------------------------
       1) Disable FK checks for bulk rebuild
       ----------------------------- */
    SET v_old_fk := @@FOREIGN_KEY_CHECKS;
    SET FOREIGN_KEY_CHECKS = 0;

    START TRANSACTION;

    /* -----------------------------
       2) TRUNCATE targets (dependency order)
       ----------------------------- */
    TRUNCATE TABLE bts_ref_org_profile;
    TRUNCATE TABLE bts_ref_org_addr_contact;
    TRUNCATE TABLE bts_ref_org_addr;
    TRUNCATE TABLE bts_ref_org_contact;
    TRUNCATE TABLE bts_ref_address_detail;
    TRUNCATE TABLE bts_ref_address;
    TRUNCATE TABLE bts_ref_contact;
    TRUNCATE TABLE bts_ref_org;
    TRUNCATE TABLE bts_ref_province;
    TRUNCATE TABLE bts_ref_country;
    TRUNCATE TABLE bts_ref_salutation;

    /* -----------------------------
       3) Load masters (order matters)
       ----------------------------- */

    /* 3.1 COUNTRY */
    SET @sql := CONCAT(
        'INSERT INTO bts_ref_country ',
        '(PK, RM_COUNTRY_CODE, COUNTRY_DESC_EN, COUNTRY_DESC_FR, COUNTRY_SHORT, ',
        ' POSTAL_CODE_FORMAT_RE, UPDATED_BY, TS, INACTIVE_DATE, PROVINCE_MANDATORY_FLAG) ',
        'SELECT ',
        '  c.COUNTRY_CODE, c.COUNTRY_CODE, c.COUNTRY_DESC, c.COUNTRY_DESC_FR, c.COUNTRY_SHORT, ',
        '  NULL, ?, NOW(6), NULL, NULL ',
        'FROM `', p_src_schema, '`.stg_cts_country c'
    );
    PREPARE s FROM @sql; EXECUTE s USING @p_updated_by; DEALLOCATE PREPARE s;

    /* 3.2 PROVINCE (dedupe to avoid duplicate PK in target) */
    SET @sql := CONCAT(
        'INSERT INTO bts_ref_province ',
        '(PK, COUNTRY_FK, RM_PROVINCE_CODE, PROVINCE_DESC_EN, PROVINCE_DESC_FR, PROVINCE_SYMBOL, UPDATED_BY, TS, INACTIVE_DATE) ',
        'SELECT ',
        '  p.PROVINCE_CODE AS PK, ',
        '  c1.PK AS COUNTRY_FK, ',
        '  p.PROVINCE_CODE AS RM_PROVINCE_CODE, ',
        '  p.PROVINCE_DESC AS PROVINCE_DESC_EN, ',
        '  p.PROVINCE_DESC_FR AS PROVINCE_DESC_FR, ',
        '  p.PROVINCE_SYMBOL AS PROVINCE_SYMBOL, ',
        '  ? AS UPDATED_BY, ',
        '  NOW(6) AS TS, ',
        '  NULL AS INACTIVE_DATE ',
        'FROM (',
        '  SELECT ',
        '    PROVINCE_CODE, ',
        '    COUNTRY_SHORT, ',
        '    MIN(PROVINCE_DESC)    AS PROVINCE_DESC, ',
        '    MIN(PROVINCE_DESC_FR) AS PROVINCE_DESC_FR, ',
        '    MIN(PROVINCE_SYMBOL)  AS PROVINCE_SYMBOL ',
        '  FROM `', p_src_schema, '`.stg_cts_province ',
        '  GROUP BY PROVINCE_CODE, COUNTRY_SHORT ',
        ') p ',
        'JOIN (',
        '  SELECT COUNTRY_SHORT, MIN(PK) AS PK ',
        '  FROM bts_ref_country ',
        '  GROUP BY COUNTRY_SHORT ',
        ') c1 ',
        '  ON c1.COUNTRY_SHORT = p.COUNTRY_SHORT'
    );
    PREPARE s FROM @sql; EXECUTE s USING @p_updated_by; DEALLOCATE PREPARE s;

    /* 3.3 SALUTATION */
    SET @sql := CONCAT(
        'INSERT INTO bts_ref_salutation ',
        '(PK, RM_SALUTATION_CODE, SALUTATION_EN, SALUTATION_FR, UPDATED_BY, TS, INACTIVE_DATE) ',
        'SELECT ',
        '  s.SALUTATION_CODE, s.SALUTATION_CODE, s.SALUTATION_ENG, s.SALUTATION_FRE, ',
        '  ?, NOW(6), ''9999-12-31 00:00:00'' ',
        'FROM `', p_src_schema, '`.stg_cts_salutation s'
    );
    PREPARE s FROM @sql; EXECUTE s USING @p_updated_by; DEALLOCATE PREPARE s;

       /* 3.4 ORG (COMPANY) — SBR_SB_STATUS as 1/0/NULL */
    SET @sql := CONCAT(
        'INSERT INTO bts_ref_org ',
        '(PK, RM_COMPANY_CODE, ORG_NAME, RM_MANF_CODE, OLD_NOTES, NOTES, UPDATED_BY, TS, ',
        ' COMPANY_CODE, MANF_CODE, INACTIVATION_DATE, BUSINESS_NO, BUSINESS_NO_VALIDATED, RM_SOURCE, ',
        ' SBR_EFFECTIVE_DATE, SBR_EXPIRY_DATE, SBR_NAME_CHANGED_DATE, OTHER_ORG_NAME, SBR_SB_STATUS, ',
        ' PARENT_ORG_PK, DELETED, IS_ACTIVE) ',
        'SELECT ',
        '  co.COMPANY_CODE, co.COMPANY_CODE, co.COMPANY_NAME, co.MFR_CODE, co.OLD_NOTES, co.NOTES, ',
        '  ?, COALESCE(co.ETL_DATE_STAMP, NOW(6)), ',
        '  co.COMPANY_CODE, co.MFR_CODE, co.INACTIVATION_DATE, ',
        '  LPAD(CAST(co.CRA_BUSINESS_NO AS CHAR), 9, ''0''), ',
        '  NULL, ''CTS_DPD'', ',
        '  co.SBR_EFFECTIVE_DATE, co.SBR_EXPIRY_DATE, co.SBR_NAME_CHANGED, NULL, ',
        '  CASE ',
        '    WHEN UPPER(LEFT(TRIM(co.SBR_SB_STATUS), 1)) = ''Y'' THEN 1 ',
        '    WHEN UPPER(LEFT(TRIM(co.SBR_SB_STATUS), 1)) = ''N'' THEN 0 ',
        '    ELSE NULL ',
        '  END AS SBR_SB_STATUS, ',
        '  NULL, b''0'', CASE WHEN co.INACTIVATION_DATE IS NULL THEN b''1'' ELSE b''0'' END ',
        'FROM `', p_src_schema, '`.stg_cts_company co'
    );
    PREPARE s FROM @sql; EXECUTE s USING @p_updated_by; DEALLOCATE PREPARE s;

    /* 3.5 CONTACT */
    SET @sql := CONCAT(
        'INSERT INTO bts_ref_contact ',
        '(PK, RM_CONTACT_CODE, RM_SALUTATION_CODE, SURNAME, GIVEN_NAME, INITIALS, POSITION, DEPARTMENT, LANG, ',
        ' TELEPHONE_NO, FAX_NO, EMAIL_ADDR, INACTIVE_DATE, UPDATED_BY, TS, SALUTATION_FK, NO_EMAIL_FLAG, ROUTING_ID) ',
        'SELECT ',
        '  ct.CONTACT_CODE, ct.CONTACT_CODE, ct.SALUTATION_CODE, ct.SURNAME, ct.GIVEN_NAME, ct.INITIALS, ',
        '  ct.POSITION, ct.DEPARTMENT, ct.LANGUAGE, ct.TELEPHONE_NUMBER, ct.FAX_NUMBER, ct.E_MAIL_ADDRESS, ',
        '  ct.INACTIVE_DATE, ?, ct.LAST_UPDATE_DATE, ct.SALUTATION_CODE, ',
        '  CASE WHEN ct.E_MAIL_ADDRESS IS NULL OR TRIM(ct.E_MAIL_ADDRESS) = '''' THEN b''1'' ELSE b''0'' END, ',
        '  ct.ROUTING_ID ',
        'FROM `', p_src_schema, '`.stg_cts_contact ct'
    );
    PREPARE s FROM @sql; EXECUTE s USING @p_updated_by; DEALLOCATE PREPARE s;

    /* 3.6 ADDRESS */
    SET @sql := CONCAT(
        'INSERT INTO bts_ref_address ',
        '(PK, COUNTRY_FK, PROVINCE_FK, RM_ADDR_CODE, SUITE_NO, ADDR_LINE1, ADDR_LINE2, CITY_NAME, POSTAL_CODE, POSTAL_OFFICE_BOX, ',
        ' INACTIVE_DATE, UPDATED_BY, TS, MIGRATED_MFADDR, RM_SOURCE) ',
        'SELECT ',
        '  a.ADDRESS_CODE, a.COUNTRY_CODE, a.PROVINCE_CODE, a.ADDRESS_CODE, a.SUITE_NUMBER, a.STREET_NAME, NULL, ',
        '  a.CITY_NAME, a.POSTAL_CODE, a.POST_OFFICE_BOX, a.INACTIVE_DATE, ?, a.LAST_UPDATE_DATE, NULL, ''CTS_DPD'' ',
        'FROM `', p_src_schema, '`.stg_cts_address a'
    );
    PREPARE s FROM @sql; EXECUTE s USING @p_updated_by; DEALLOCATE PREPARE s;

    /* 3.7 ADDRESS_DETAIL */
    SET @sql := CONCAT(
        'INSERT INTO bts_ref_address_detail ',
        '(PK, ADDR_FK, PARENT_ADDR_DETAIL_FK, LOCATION, UPDATED_BY, TS) ',
        'SELECT ',
        '  ao.ADDRESS_CODE, ao.ADDRESS_CODE, NULL, NULLIF(TRIM(ao.ATTENTION_TO), ''''), ?, NOW(6) ',
        'FROM `', p_src_schema, '`.stg_cts_address_orig ao ',
        'WHERE ao.ATTENTION_TO IS NOT NULL AND TRIM(ao.ATTENTION_TO) <> '''''
    );
    PREPARE s FROM @sql; EXECUTE s USING @p_updated_by; DEALLOCATE PREPARE s;

/* -----------------------------
   4) ORG↔CONTACT (FULL LIST) — source: stg_cts_company_contact
   Appian-safe: PK auto_increment; uniqueness enforced by uq_org_contact_pair (ORG_FK, CONTACT_FK)
   ORG_CONTACT_KEY is SHA2 checksum (VARCHAR(64))
   ----------------------------- */
TRUNCATE TABLE bts_ref_org_contact;

SET @sql := CONCAT(
  'INSERT INTO bts_ref_org_contact (ORG_FK, CONTACT_FK, ORG_CONTACT_KEY, UPDATED_BY, TS) ',
  'SELECT DISTINCT ',
  '  cc.COMPANY_CODE AS ORG_FK, ',
  '  cc.CONTACT_CODE AS CONTACT_FK, ',
  '  SHA2(CONCAT(cc.COMPANY_CODE, ''|'', cc.CONTACT_CODE), 256) AS ORG_CONTACT_KEY, ',
  '  ? AS UPDATED_BY, ',
  '  NOW(6) AS TS ',
  'FROM `', p_src_schema, '`.stg_cts_company_contact cc ',
  'JOIN bts_ref_org o ON o.PK = cc.COMPANY_CODE ',
  'WHERE cc.COMPANY_CODE IS NOT NULL ',
  '  AND cc.CONTACT_CODE IS NOT NULL ',
  '  AND cc.CONTACT_CODE <> 0'
);

PREPARE s FROM @sql;
EXECUTE s USING @p_updated_by;
DEALLOCATE PREPARE s;
    /* -----------------------------
       5) Authoritative associations
       ----------------------------- */

    /* 5.1 ORG↔ADDR */
    SET @sql := CONCAT(
        'INSERT INTO bts_ref_org_addr (ORG_FK, ADDR_FK, ADDR_DETAIL_FK, UPDATED_BY, TS) ',
        'SELECT DISTINCT x.ORG_FK, x.ADDR_FK, x.ADDR_DETAIL_FK, ?, NOW(6) ',
        'FROM (',
        '  SELECT cal.DIN_COMPANY_CODE AS ORG_FK, NULLIF(cal.ADDRESS_CODE,0) AS ADDR_FK, NULLIF(cal.ADDRESS_CODE,0) AS ADDR_DETAIL_FK ',
        '  FROM `', p_src_schema, '`.stg_cts_company_address_link cal ',
        '  UNION ALL ',
        '  SELECT sub.DIN_COMPANY_CODE AS ORG_FK, NULLIF(sub.ADDRESS_CODE,0) AS ADDR_FK, NULLIF(sub.ADDRESS_CODE,0) AS ADDR_DETAIL_FK ',
        '  FROM `', p_src_schema, '`.stg_cts_sub_company_address_link sub ',
        ') x ',
        'WHERE x.ORG_FK IS NOT NULL AND x.ADDR_FK IS NOT NULL'
    );
    PREPARE s FROM @sql; EXECUTE s USING @p_updated_by; DEALLOCATE PREPARE s;

    /* 5.2 ORG↔ADDR↔CONTACT */
    SET @sql := CONCAT(
        'INSERT INTO bts_ref_org_addr_contact (ORG_ADDR_FK, CONTACT_FK, UPDATED_BY, TS) ',
        'SELECT DISTINCT oa.PK, x.CONTACT_FK, ?, NOW(6) ',
        'FROM (',
        '  SELECT cal.DIN_COMPANY_CODE AS ORG_FK, NULLIF(cal.ADDRESS_CODE,0) AS ADDR_FK, NULLIF(cal.CONTACT_CODE,0) AS CONTACT_FK ',
        '  FROM `', p_src_schema, '`.stg_cts_company_address_link cal ',
        '  UNION ALL ',
        '  SELECT sub.DIN_COMPANY_CODE AS ORG_FK, NULLIF(sub.ADDRESS_CODE,0) AS ADDR_FK, NULLIF(sub.CONTACT_CODE,0) AS CONTACT_FK ',
        '  FROM `', p_src_schema, '`.stg_cts_sub_company_address_link sub ',
        ') x ',
        'JOIN bts_ref_org_addr oa ON oa.ORG_FK = x.ORG_FK AND oa.ADDR_FK = x.ADDR_FK ',
        'WHERE x.ORG_FK IS NOT NULL AND x.ADDR_FK IS NOT NULL AND x.CONTACT_FK IS NOT NULL'
    );
    PREPARE s FROM @sql; EXECUTE s USING @p_updated_by; DEALLOCATE PREPARE s;

    /* -----------------------------
       6) ORG_PROFILE deterministic selectors (NO CTEs, NO window functions)
       Tie-breakers:
         src_priority (CAL=1, SUB=2),
         company_id (NULL->999999999),
         company_type_code (NULL->999999999),
         addr_fk,
         contact_fk
       ----------------------------- */

    SET @sql := CONCAT(
        'INSERT INTO bts_ref_org_profile ',
        '(PK, DIN_OWNER_ORG_ADDR_CONTACT_FK, BILLING_ORG_ADDR_CONTACT_FK, NOTIFY_ORG_ADDR_CONTACT_FK, ',
        ' BILLING_ORG_TYPE_FK, NOTIFY_ORG_TYPE_FK, EBILLING_FLAG, INACTIVE_DATE, UPDATED_BY, TS) ',
        'SELECT ',
        '  orgs.org_fk AS PK, ',
        '  owner_oac.PK AS DIN_OWNER_ORG_ADDR_CONTACT_FK, ',
        '  bill_oac.PK  AS BILLING_ORG_ADDR_CONTACT_FK, ',
        '  notif_oac.PK AS NOTIFY_ORG_ADDR_CONTACT_FK, ',
        '  CASE WHEN ? = ''DIRECT'' THEN bill_best.company_type_code ELSE NULL END AS BILLING_ORG_TYPE_FK, ',
        '  CASE WHEN ? = ''DIRECT'' THEN notif_best.company_type_code ELSE NULL END AS NOTIFY_ORG_TYPE_FK, ',
        '  NULL AS EBILLING_FLAG, ',
        '  NULL AS INACTIVE_DATE, ',
        '  ? AS UPDATED_BY, ',
        '  NOW(6) AS TS ',
        'FROM (',
        '  SELECT DISTINCT x.org_fk ',
        '  FROM (',
        '    SELECT cal.DIN_COMPANY_CODE AS org_fk FROM `', p_src_schema, '`.stg_cts_company_address_link cal ',
        '    UNION ALL ',
        '    SELECT sub.DIN_COMPANY_CODE AS org_fk FROM `', p_src_schema, '`.stg_cts_sub_company_address_link sub ',
        '  ) x ',
        '  WHERE x.org_fk IS NOT NULL',
        ') orgs ',
        /* ---------- owner_best (MAILING_FLAG='Y') ---------- */
        'LEFT JOIN (',
        '  SELECT ln.org_fk, ln.addr_fk, ln.contact_fk, ln.company_type_code ',
        '  FROM (',
        '    SELECT ',
        '      z.org_fk, z.addr_fk, z.contact_fk, z.company_type_code, ',
        '      MIN(z.sortkey) AS min_sortkey ',
        '    FROM (',
        '      SELECT ',
        '        cal.DIN_COMPANY_CODE AS org_fk, NULLIF(cal.ADDRESS_CODE,0) AS addr_fk, NULLIF(cal.CONTACT_CODE,0) AS contact_fk, ',
        '        cal.COMPANY_TYPE_CODE AS company_type_code, ',
        '        CONCAT(',
        '          ''1|'', ',
        '          LPAD(COALESCE(cal.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(cal.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_company_address_link cal ',
        '      WHERE cal.MAILING_FLAG = ''Y'' AND cal.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(cal.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(cal.CONTACT_CODE,0) IS NOT NULL ',
        '      UNION ALL ',
        '      SELECT ',
        '        sub.DIN_COMPANY_CODE AS org_fk, NULLIF(sub.ADDRESS_CODE,0) AS addr_fk, NULLIF(sub.CONTACT_CODE,0) AS contact_fk, ',
        '        sub.COMPANY_TYPE_CODE AS company_type_code, ',
        '        CONCAT(',
        '          ''2|'', ',
        '          LPAD(COALESCE(sub.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(sub.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_sub_company_address_link sub ',
        '      WHERE sub.MAILING_FLAG = ''Y'' AND sub.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(sub.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(sub.CONTACT_CODE,0) IS NOT NULL ',
        '    ) z ',
        '    GROUP BY z.org_fk, z.addr_fk, z.contact_fk, z.company_type_code ',
        '  ) ln ',
        '  JOIN (',
        '    SELECT org_fk, MIN(sortkey) AS min_sortkey ',
        '    FROM (',
        '      SELECT cal.DIN_COMPANY_CODE AS org_fk, ',
        '        CONCAT(',
        '          ''1|'', ',
        '          LPAD(COALESCE(cal.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(cal.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_company_address_link cal ',
        '      WHERE cal.MAILING_FLAG = ''Y'' AND cal.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(cal.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(cal.CONTACT_CODE,0) IS NOT NULL ',
        '      UNION ALL ',
        '      SELECT sub.DIN_COMPANY_CODE AS org_fk, ',
        '        CONCAT(',
        '          ''2|'', ',
        '          LPAD(COALESCE(sub.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(sub.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_sub_company_address_link sub ',
        '      WHERE sub.MAILING_FLAG = ''Y'' AND sub.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(sub.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(sub.CONTACT_CODE,0) IS NOT NULL ',
        '    ) all_owner ',
        '    GROUP BY org_fk ',
        '  ) pick ON pick.org_fk = ln.org_fk AND pick.min_sortkey = ln.min_sortkey ',
        ') owner_best ON owner_best.org_fk = orgs.org_fk ',
        'LEFT JOIN bts_ref_org_addr oa_owner ON oa_owner.ORG_FK = owner_best.org_fk AND oa_owner.ADDR_FK = owner_best.addr_fk ',
        'LEFT JOIN bts_ref_org_addr_contact owner_oac ON owner_oac.ORG_ADDR_FK = oa_owner.PK AND owner_oac.CONTACT_FK = owner_best.contact_fk ',
        /* ---------- billing_best (BILLING_FLAG='Y') ---------- */
        'LEFT JOIN (',
        '  SELECT ln.org_fk, ln.addr_fk, ln.contact_fk, ln.company_type_code ',
        '  FROM (',
        '    SELECT ',
        '      z.org_fk, z.addr_fk, z.contact_fk, z.company_type_code, ',
        '      MIN(z.sortkey) AS min_sortkey ',
        '    FROM (',
        '      SELECT ',
        '        cal.DIN_COMPANY_CODE AS org_fk, NULLIF(cal.ADDRESS_CODE,0) AS addr_fk, NULLIF(cal.CONTACT_CODE,0) AS contact_fk, ',
        '        cal.COMPANY_TYPE_CODE AS company_type_code, ',
        '        CONCAT(',
        '          ''1|'', ',
        '          LPAD(COALESCE(cal.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(cal.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_company_address_link cal ',
        '      WHERE cal.BILLING_FLAG = ''Y'' AND cal.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(cal.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(cal.CONTACT_CODE,0) IS NOT NULL ',
        '      UNION ALL ',
        '      SELECT ',
        '        sub.DIN_COMPANY_CODE AS org_fk, NULLIF(sub.ADDRESS_CODE,0) AS addr_fk, NULLIF(sub.CONTACT_CODE,0) AS contact_fk, ',
        '        sub.COMPANY_TYPE_CODE AS company_type_code, ',
        '        CONCAT(',
        '          ''2|'', ',
        '          LPAD(COALESCE(sub.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(sub.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_sub_company_address_link sub ',
        '      WHERE sub.BILLING_FLAG = ''Y'' AND sub.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(sub.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(sub.CONTACT_CODE,0) IS NOT NULL ',
        '    ) z ',
        '    GROUP BY z.org_fk, z.addr_fk, z.contact_fk, z.company_type_code ',
        '  ) ln ',
        '  JOIN (',
        '    SELECT org_fk, MIN(sortkey) AS min_sortkey ',
        '    FROM (',
        '      SELECT cal.DIN_COMPANY_CODE AS org_fk, ',
        '        CONCAT(',
        '          ''1|'', ',
        '          LPAD(COALESCE(cal.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(cal.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_company_address_link cal ',
        '      WHERE cal.BILLING_FLAG = ''Y'' AND cal.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(cal.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(cal.CONTACT_CODE,0) IS NOT NULL ',
        '      UNION ALL ',
        '      SELECT sub.DIN_COMPANY_CODE AS org_fk, ',
        '        CONCAT(',
        '          ''2|'', ',
        '          LPAD(COALESCE(sub.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(sub.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_sub_company_address_link sub ',
        '      WHERE sub.BILLING_FLAG = ''Y'' AND sub.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(sub.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(sub.CONTACT_CODE,0) IS NOT NULL ',
        '    ) all_bill ',
        '    GROUP BY org_fk ',
        '  ) pick ON pick.org_fk = ln.org_fk AND pick.min_sortkey = ln.min_sortkey ',
        ') bill_best ON bill_best.org_fk = orgs.org_fk ',
        'LEFT JOIN bts_ref_org_addr oa_bill ON oa_bill.ORG_FK = bill_best.org_fk AND oa_bill.ADDR_FK = bill_best.addr_fk ',
        'LEFT JOIN bts_ref_org_addr_contact bill_oac ON bill_oac.ORG_ADDR_FK = oa_bill.PK AND bill_oac.CONTACT_FK = bill_best.contact_fk ',
        /* ---------- notif_best (NOTIFICATION_FLAG='Y') ---------- */
        'LEFT JOIN (',
        '  SELECT ln.org_fk, ln.addr_fk, ln.contact_fk, ln.company_type_code ',
        '  FROM (',
        '    SELECT ',
        '      z.org_fk, z.addr_fk, z.contact_fk, z.company_type_code, ',
        '      MIN(z.sortkey) AS min_sortkey ',
        '    FROM (',
        '      SELECT ',
        '        cal.DIN_COMPANY_CODE AS org_fk, NULLIF(cal.ADDRESS_CODE,0) AS addr_fk, NULLIF(cal.CONTACT_CODE,0) AS contact_fk, ',
        '        cal.COMPANY_TYPE_CODE AS company_type_code, ',
        '        CONCAT(',
        '          ''1|'', ',
        '          LPAD(COALESCE(cal.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(cal.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_company_address_link cal ',
        '      WHERE cal.NOTIFICATION_FLAG = ''Y'' AND cal.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(cal.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(cal.CONTACT_CODE,0) IS NOT NULL ',
        '      UNION ALL ',
        '      SELECT ',
        '        sub.DIN_COMPANY_CODE AS org_fk, NULLIF(sub.ADDRESS_CODE,0) AS addr_fk, NULLIF(sub.CONTACT_CODE,0) AS contact_fk, ',
        '        sub.COMPANY_TYPE_CODE AS company_type_code, ',
        '        CONCAT(',
        '          ''2|'', ',
        '          LPAD(COALESCE(sub.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(sub.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_sub_company_address_link sub ',
        '      WHERE sub.NOTIFICATION_FLAG = ''Y'' AND sub.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(sub.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(sub.CONTACT_CODE,0) IS NOT NULL ',
        '    ) z ',
        '    GROUP BY z.org_fk, z.addr_fk, z.contact_fk, z.company_type_code ',
        '  ) ln ',
        '  JOIN (',
        '    SELECT org_fk, MIN(sortkey) AS min_sortkey ',
        '    FROM (',
        '      SELECT cal.DIN_COMPANY_CODE AS org_fk, ',
        '        CONCAT(',
        '          ''1|'', ',
        '          LPAD(COALESCE(cal.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(cal.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(cal.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_company_address_link cal ',
        '      WHERE cal.NOTIFICATION_FLAG = ''Y'' AND cal.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(cal.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(cal.CONTACT_CODE,0) IS NOT NULL ',
        '      UNION ALL ',
        '      SELECT sub.DIN_COMPANY_CODE AS org_fk, ',
        '        CONCAT(',
        '          ''2|'', ',
        '          LPAD(COALESCE(sub.COMPANY_ID,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(sub.COMPANY_TYPE_CODE,999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.ADDRESS_CODE,0),999999999), 10, ''0''), ''|'', ',
        '          LPAD(COALESCE(NULLIF(sub.CONTACT_CODE,0),999999999), 10, ''0'')',
        '        ) AS sortkey ',
        '      FROM `', p_src_schema, '`.stg_cts_sub_company_address_link sub ',
        '      WHERE sub.NOTIFICATION_FLAG = ''Y'' AND sub.DIN_COMPANY_CODE IS NOT NULL ',
        '        AND NULLIF(sub.ADDRESS_CODE,0) IS NOT NULL AND NULLIF(sub.CONTACT_CODE,0) IS NOT NULL ',
        '    ) all_notif ',
        '    GROUP BY org_fk ',
        '  ) pick ON pick.org_fk = ln.org_fk AND pick.min_sortkey = ln.min_sortkey ',
        ') notif_best ON notif_best.org_fk = orgs.org_fk ',
        'LEFT JOIN bts_ref_org_addr oa_notif ON oa_notif.ORG_FK = notif_best.org_fk AND oa_notif.ADDR_FK = notif_best.addr_fk ',
        'LEFT JOIN bts_ref_org_addr_contact notif_oac ON notif_oac.ORG_ADDR_FK = oa_notif.PK AND notif_oac.CONTACT_FK = notif_best.contact_fk '
    );

    PREPARE s FROM @sql;
    EXECUTE s USING @p_org_type_mode, @p_org_type_mode, @p_updated_by;
    DEALLOCATE PREPARE s;

    COMMIT;

    SET FOREIGN_KEY_CHECKS = v_old_fk;
    DO RELEASE_LOCK('sp_refresh_cts_company_refs');

END
