# NBT522 — MA State/Status Refactor Workstream

> This document captures **active design / implementation context**, not guaranteed fully deployed production reality. Validate against the latest approved ticket / branch before implementation.
>
> Extracted from `BTS_Technical_Reference.md` Section 12 to reduce auto-load token cost.

---

## Overview

* **Ticket:** `NBT522`
* **Theme:** Market Authorization State / Status separation
* **Status in prior sessions:** active design / implementation workstream
* **Key participants previously referenced:** DB implementation by you, front-end work by Yawei, business ownership / amendments from Shannon's team

## Business direction

The legacy `bts_market_authorization.STATUS` field conflates distinct concepts that the refactor aims to separate:

| Concept       | Meaning                                                   | Intended treatment   |
| ------------- | --------------------------------------------------------- | -------------------- |
| **MA State**  | Whether the authorization is authorized vs not authorized | state-history model  |
| **MA Status** | Operational status such as marketed / suspended / revoked | status-history model |

## Proposed state model

| STATE_CODE       | AUTHORIZED_TYPE_CODE | Intended display       |
| ---------------- | -------------------- | ---------------------- |
| `AUTHORIZED`     | `INITIAL`            | AUTHORIZED -- INITIAL   |
| `AUTHORIZED`     | `AMENDMENT`          | AUTHORIZED -- AMENDMENT |
| `NOT_AUTHORIZED` | `NULL`               | NOT AUTHORIZED         |

## Key design intent

* Store `STATE_CODE` and `AUTHORIZED_TYPE_CODE` together for state history
* Use simplified state display in dashboards
* Preserve subtype nuance such as amendment in history / detail contexts

## Proposed date categories

1. Initial market authorization effective date
2. Amendment effective dates
3. MA operational status effective dates

## Proposed new history tables

### `bts_ma_state_hist`

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

### `bts_ma_status_hist`

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

## Proposed header enhancement

```sql
ALTER TABLE bts_appian_rt.bts_market_authorization
  ADD COLUMN ORIGINAL_ISSUE_DATE DATE NULL,
  ADD COLUMN ORIGINAL_ISSUER     VARCHAR(100) NULL;
```

## Proposed stored procedures

### `sp_ma_submit_state(...)`

Working intent previously discussed:

1. Resolve / ensure MA row exists
2. End-date prior open state interval
3. Insert new state row
4. Preserve original issue date / issuer for initial authorization
5. Do not overwrite original issue metadata on amendments
6. Preserve original issue metadata when later state becomes not authorized

### `sp_ma_update_status(...)`

Working intent previously discussed:

1. Require an initial authorized state before status updates
2. End-date current open status row
3. Insert new status row
4. Apply cross-effects for revoked / suspension scenarios as specified in ticket logic

## Proposed views

| View                         | Intended purpose                         |
| ---------------------------- | ---------------------------------------- |
| `bts_view_ma_current`        | Current MA state / status rollup per BIN |
| `bts_view_ma_state_history`  | Ordered state-history view               |
| `bts_view_ma_status_history` | Ordered status-history view              |

## Reference-table strategy

`bts_ref_market_authorization_status` was treated as an existing candidate reference table for MA codes. Prior design direction suggested it may need to support concepts such as:

* `CATEGORY`
* `IS_ACTIVE`
* `SEQUENCE`
* `DATE_IS_REQUIRED`

Do **not** assume those columns already exist everywhere; verify against the live schema / approved migration script.

## UI / integration direction

Prior design notes indicated:

* separate dropdown sourcing for MA state vs MA status
* simplified dashboard display from current-state/current-status rollup
* richer history displays from state/status history views
* amendment subtype emphasized in history/detail rather than high-level dashboard display

## Access groups previously referenced

* `TEST_BTS_ADMIN_BUSINESS`
* `TEST_BTS_ADMIN_IT`
* `TEST_BTS_REVIEWER`

## Important caution

Treat all NBT522 DB objects, stored procedure names, reference-table expansions, and UI contract notes as **design / implementation reference** unless verified as deployed in the target environment.

---

*Extracted: 2026-02-28 | Source: BTS_Technical_Reference.md Section 12*
