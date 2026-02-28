# BTS Working Context

> Environment-specific metadata and operator context for BTS development.
> Companion to `BTS_Technical_Reference.md` — separated during v2 cleanup.

---

## Developer Role

- **Role:** Lead backend developer — full owner of schema, views, debug
- **Tooling:** MySQL Workbench, Appian Designer (frontend — low-code BPM)

## Environment Metadata

| Property | Value |
|---|---|
| **DB Engine** | MySQL 8.0 |
| **Schema** | `bts_appian_rt` |
| **View Definer** | `` `bts_appian_owner_dv`@`%` `` |
| **Frontend** | Appian (low-code BPM platform) |

## View Definer Usage

The view definer value is required when creating or replacing any view in BTS:

```sql
DEFINER = `bts_appian_owner_dv`@`%`
```

Use this in all `CREATE OR REPLACE VIEW` statements.

## Appian Access Groups

- `TEST_BTS_ADMIN_BUSINESS`
- `TEST_BTS_ADMIN_IT`
- `TEST_BTS_REVIEWER`

---

*Moved from BTS_Technical_Reference.md v1 (section 1 system overview, section 9 access groups) during v2 restructuring — 2026-02-28*
