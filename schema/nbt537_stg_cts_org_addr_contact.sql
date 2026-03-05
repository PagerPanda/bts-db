-- ============================================================================
-- File:        nbt537_stg_cts_org_addr_contact.sql
-- Ticket:      NBT537 / NBT568
-- Author:      BTS DB team
-- Date:        2026-03-05
-- Environment: DEV / TEST
-- Engine:      MySQL 8.0
-- Schema:      bts_appian_dv (staging schema — p_src_schema)
-- Description: Net-new staging table for common.ORG_ADDR_CONTACT_WV.
--              Replaces the UNION ALL of stg_cts_company_address_link +
--              stg_cts_sub_company_address_link for org-addr-contact associations.
--              Populated by Informatica from common.ORG_ADDR_CONTACT_WV.
--
--              ORG_FK_RO and ADDR_FK_RO are denormalized read-only columns
--              from the source view, used by the SP to resolve through
--              bts_ref_org_addr (which has its own auto-increment PK).
-- ============================================================================

CREATE TABLE IF NOT EXISTS stg_cts_org_addr_contact (
  PK                INT          NOT NULL COMMENT 'Source PK from common.ORG_ADDR_CONTACT_WV',
  CONTACT_FK        INT          NULL     COMMENT 'Contact FK — maps to bts_ref_contact.PK',
  ORG_ADDR_FK       INT          NULL     COMMENT 'Source ORG_ADDR FK — references common.ORG_ADDR_WV.PK (NOT bts_ref_org_addr.PK)',
  ORG_FK_RO         INT          NULL     COMMENT 'Denormalized org FK — used to resolve through bts_ref_org_addr',
  ADDR_FK_RO        INT          NULL     COMMENT 'Denormalized addr FK — used to resolve through bts_ref_org_addr',
  UPDATED_BY        VARCHAR(200) NULL,
  TS                DATETIME     NULL,
  PRIMARY KEY (PK),
  INDEX idx_oac_contact_fk (CONTACT_FK),
  INDEX idx_oac_org_addr_fk (ORG_ADDR_FK),
  INDEX idx_oac_resolve (ORG_FK_RO, ADDR_FK_RO)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
