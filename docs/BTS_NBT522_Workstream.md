# BTS NBT522 Workstream

> Active design / implementation reference for the BTS Market Authorization state/status refactor.
> This file is intentionally separate from the core BTS technical reference because parts of this design may be in-flight rather than fully deployed.

---

## 1. WORKSTREAM OVERVIEW

### Ticket

- **JIRA / Ticket:** `NBT522`
- **Theme:** Market Authorization (MA) State / Status separation
- **Status in prior sessions:** active design / implementation workstream as of Jan 2026

### Previously referenced participants / roles

- **DB implementation:** Ramy
- **Frontend / Appian developer:** Yawei
- **Business owner / amendments context:** Shannon's team

### Why this work exists

The legacy `bts_market_authorization.STATUS` field conflates more than one business concept. The workstream direction is to split this into:

- **MA State** — authorized vs not authorized
- **MA Status** — operational / market status such as marketed, suspended, revoked

---

## 2. BUSINESS DIRECTION

### Target separation

| Concept       | Meaning                                                              | Intended modeling direction |
| ------------- | -------------------------------------------------------------------- | --------------------------- |
| **MA State**  | Whether the market authorization is authorized or not authorized     | state-history model         |
| **MA Status** | Operational condition of the authorization after issuance            | status-history model        |

### Key business objective

Stop overloading one legacy column with multiple dimensions of meaning, while preserving auditability and date history.

---

## 3. PROPOSED STATE MODEL

### State combinations discussed

| STATE_CODE       | AUTHORIZED_TYPE_CODE | Intended Display       |
| ---------------- | -------------------- | ---------------------- |
| `AUTHORIZED`     | `INITIAL`            | AUTHORIZED – INITIAL   |
| `AUTHORIZED`     | `AMENDMENT`          | AUTHORIZED – AMENDMENT |
| `NOT_AUTHORIZED` | `NULL`               | NOT AUTHORIZED         |

### Design intent

- Store `STATE_CODE` and `AUTHORIZED_TYPE_CODE` in the same state-history row.
- Simplify dashboard displays to the higher-level state where appropriate.
- Preserve amendment / subtype nuance in history and detail views.

---

## 4. DATE CONCEPTS REQUIRED

The workstream previously identified three distinct date categories that must be modeled clearly:

1. **Initial Market Authorization date**
   - effective date of the first `AUTHORIZED + INITIAL` event
2. **MA Amendment date**
   - effective date range of each `AUTHORIZED + AMENDMENT` event
3. **MA Status date**
   - effective date range of each operational status event

---

## 5. PROPOSED DATABASE OBJECTS

> These were discussed as proposed design objects. Verify against the latest branch / migration script before implementing.

### Proposed table: `bts_ma_state_hist`

```sql
CREATE TABLE bts_ma_state_hist (
  ID                      INT AUTO_INCREMENT PRIMARY KEY,
  MARKET_AUTHORIZATION_FK INT NOT NULL,
  STATE_CODE              VARCHAR(30) NOT NULL,
  AUTHORIZED_TYPE_CODE    VARCHAR(20) NULL,
  EFFECTIVE_START_DATE    DATE NOT NULL,
  EFFECTIVE_END_DATE      DATE NULL,
  ISSUER                  VARCHAR(100) NULL,
  CREATED_BY              VARCHAR(100),
  CREATED_ON              DATETIME DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_auth_type CHECK (
    (STATE_CODE = 'AUTHORIZED' AND AUTHORIZED_TYPE_CODE IN ('INITIAL','AMENDMENT'))
    OR (STATE_CODE = 'NOT_AUTHORIZED' AND AUTHORIZED_TYPE_CODE IS NULL)
  )
);
```

### Proposed table: `bts_ma_status_hist`

```sql
CREATE TABLE bts_ma_status_hist (
  ID                      INT AUTO_INCREMENT PRIMARY KEY,
  MARKET_AUTHORIZATION_FK INT NOT NULL,
  STATUS_CODE             VARCHAR(50) NOT NULL,
  EFFECTIVE_START_DATE    DATE NOT NULL,
  EFFECTIVE_END_DATE      DATE NULL,
  ISSUER                  VARCHAR(100) NULL,
  CREATED_BY              VARCHAR(100),
  CREATED_ON              DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Proposed enhancement to header table

```sql
ALTER TABLE bts_appian_rt.bts_market_authorization
  ADD COLUMN ORIGINAL_ISSUE_DATE DATE NULL,
  ADD COLUMN ORIGINAL_ISSUER     VARCHAR(100) NULL;
```

---

## 6. PROPOSED STORED PROCEDURES

### Proposed procedure: `sp_ma_submit_state(...)`

Previously discussed working intent:

1. Resolve / ensure a `bts_market_authorization` row exists for the BIN
2. End-date any prior open state interval row
3. Insert a new state-history row
4. If state is `AUTHORIZED + INITIAL`, populate `ORIGINAL_ISSUE_DATE` / `ORIGINAL_ISSUER` if not already set
5. If state is `AUTHORIZED + AMENDMENT`, do not overwrite original issue metadata
6. If state is `NOT_AUTHORIZED`, preserve original issue metadata

### Proposed procedure: `sp_ma_update_status(...)`

Previously discussed working intent:

1. Require an initial authorized state before allowing operational status updates
2. End-date current open status row
3. Insert new status-history row
4. Apply cross-effects for revoked / suspension scenarios per ticket rules

### Cross-effects discussed in prior sessions

- **Revoked-like status**
  - end-date open authorized state
  - insert `NOT_AUTHORIZED` state
- **Temporary suspension-like status**
  - end-date open marketed-like status
  - end-date open authorized state where required by design rule
  - insert `NOT_AUTHORIZED` state where ticket logic requires it

> Exact cross-effect rules should be revalidated against the latest approved business logic before coding.

---

## 7. PROPOSED VIEWS

| View                         | Intended Purpose                         |
| ---------------------------- | ---------------------------------------- |
| `bts_view_ma_current`        | Current MA state / status rollup per BIN |
| `bts_view_ma_state_history`  | Ordered MA state-history view            |
| `bts_view_ma_status_history` | Ordered MA status-history view           |

### Intended rollup concepts for `bts_view_ma_current`

- current state code
- current status code
- simplified display code
- original issue date

---

## 8. REFERENCE-TABLE STRATEGY

### Existing candidate reference table

- `bts_ref_market_authorization_status`

### Previously discussed direction

This table was treated as the likely reference-table anchor for MA code management, with possible support for fields such as:

- `CATEGORY`
- `IS_ACTIVE`
- `SEQUENCE`
- `DATE_IS_REQUIRED`

### Important caution

Do **not** assume these columns already exist in all environments. Confirm whether this is:

- already deployed reality
- migration-script work
- only a design proposal

---

## 9. UI / FRONT-END CONTRACT DIRECTION

> These are design-direction notes, not guaranteed deployed Appian reality.

### Prior direction included

- separate dropdown sourcing for MA **state** vs MA **status**
- simplified dashboard display driven from a current rollup view
- richer history pages driven from state-history and status-history views
- amendment subtype emphasized more in history/details than on dashboards

### Previously referenced example directions

- query reference data filtered by category for dropdowns
- use current rollup view for dashboard display
- use dedicated history views for detail/history sections

---

## 10. ACCESS GROUPS REFERENCED

The following access groups were previously referenced in the workstream context:

- `TEST_BTS_ADMIN_BUSINESS`
- `TEST_BTS_ADMIN_IT`
- `TEST_BTS_REVIEWER`

These should be treated as environment / implementation notes and confirmed in Appian / security configuration.

---

## 11. IMPLEMENTATION CAUTIONS

### Treat as active work

This file documents **active workstream context**, not guaranteed final production architecture.

### Verify before implementation

Before coding or migration work, verify:

- latest approved ticket scope
- actual deployed schema
- latest migration scripts
- Appian form / process expectations
- business rule confirmation for revoke / suspension cross-effects

### Key risk

Future readers may mistake this design for already-landed production truth. Avoid that assumption unless directly verified.

---

## 12. SUMMARY

### What this file is

A dedicated workstream note for the BTS MA state/status refactor under `NBT522`.

### What it is not

- not proof of deployment
- not a final production spec unless independently verified
- not a substitute for the live schema or migration scripts

### Practical use

Use this file when you need the historical design logic and implementation direction for NBT522 without polluting the core BTS technical reference.
