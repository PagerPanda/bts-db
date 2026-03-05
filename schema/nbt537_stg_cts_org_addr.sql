-- ============================================================================
-- File:        nbt537_stg_cts_org_addr.sql
-- Ticket:      NBT537 / NBT568
-- Author:      BTS DB team
-- Date:        2026-03-05
-- Environment: DEV / TEST
-- Engine:      MySQL 8.0
-- Schema:      bts_appian_dv (staging schema — p_src_schema)
-- Description: Net-new staging table for common.ORG_ADDR_WV.
--              Replaces the UNION ALL of stg_cts_company_address_link +
--              stg_cts_sub_company_address_link for org-addr associations.
--              Populated by Informatica from common.ORG_ADDR_WV.
-- ============================================================================

CREATE TABLE IF NOT EXISTS stg_cts_org_addr (
  PK                INT          NOT NULL COMMENT 'Source PK from common.ORG_ADDR_WV',
  ORG_FK            INT          NULL     COMMENT 'Org FK — maps to bts_ref_org.PK / stg_cts_company.COMPANY_CODE',
  ADDR_FK           INT          NULL     COMMENT 'Address FK — maps to bts_ref_address.PK / stg_cts_address.ADDRESS_CODE',
  UPDATED_BY        VARCHAR(200) NULL,
  TS                DATETIME     NULL,
  PRIMARY KEY (PK),
  INDEX idx_org_addr_org_fk (ORG_FK),
  INDEX idx_org_addr_addr_fk (ADDR_FK)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
