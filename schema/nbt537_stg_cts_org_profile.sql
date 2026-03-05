-- ============================================================================
-- File:        nbt537_stg_cts_org_profile.sql
-- Ticket:      NBT537 / NBT568
-- Author:      BTS DB team
-- Date:        2026-03-05
-- Environment: DEV / TEST
-- Engine:      MySQL 8.0
-- Schema:      bts_appian_dv (staging schema — p_src_schema)
-- Description: Net-new staging table for dp.ORG_PROFILE_WV.
--              Replaces the 220-line deterministic sortkey/tie-breaking
--              selector in sp_refresh_cts_company_refs Section 6.
--              The source view already resolves DIN owner / billing /
--              notification role assignments per org.
--
--              The *_ORG_ADDR_CONTACT_FK columns reference
--              common.ORG_ADDR_CONTACT_WV.PK (NOT bts_ref_org_addr_contact.PK).
--              The SP resolves through the denormalized *_RO columns instead.
-- ============================================================================

CREATE TABLE IF NOT EXISTS stg_cts_org_profile (
  PK                              INT          NOT NULL COMMENT 'Org PK — maps to bts_ref_org.PK',
  UPDATED_BY                      VARCHAR(200) NULL,
  TS                              DATETIME     NULL,

  /* Role FK columns (source namespace — NOT BTS PKs) */
  DIN_OWNER_ORG_ADDR_CONTACT_FK   INT          NULL COMMENT 'Source OAC FK for DIN owner (common namespace)',
  BILLING_ORG_ADDR_CONTACT_FK     INT          NULL COMMENT 'Source OAC FK for billing (common namespace)',
  NOTIFY_ORG_ADDR_CONTACT_FK      INT          NULL COMMENT 'Source OAC FK for notification (common namespace)',
  BILLING_ORG_TYPE_FK             INT          NULL COMMENT 'Org type FK for billing role',
  NOTIFY_ORG_TYPE_FK              INT          NULL COMMENT 'Org type FK for notification role',
  EBILLING_FLAG                   BIT(1)       NULL,
  INACTIVE_DATE                   DATETIME     NULL,

  /* Denormalized read-only columns — used by SP to resolve through BTS ref tables */
  DIN_OWNER_ORG_FK_RO             INT          NULL,
  DIN_OWNER_ADDR_FK_RO            INT          NULL,
  DIN_OWNER_CONTACT_FK_RO         INT          NULL,
  BILLING_ORG_FK_RO               INT          NULL,
  BILLING_ADDR_FK_RO              INT          NULL,
  BILLING_CONTACT_FK_RO           INT          NULL,
  NOTIFY_ORG_FK_RO                INT          NULL,
  NOTIFY_ADDR_FK_RO               INT          NULL,
  NOTIFY_CONTACT_FK_RO            INT          NULL,

  PRIMARY KEY (PK)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
