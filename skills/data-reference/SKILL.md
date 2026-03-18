---
name: data-reference
description: >
  Complete data engineering best practices reference covering dbt, SQL transformations,
  StarRocks/Snowflake/BigQuery patterns, JSON handling, window functions, incremental
  strategies, and data quality. Load this when you need to verify a data pattern
  during code review.
---

# Data Engineering Reference — dbt, SQL & Warehouse Best Practices

---

## dbt Patterns

### Materialization Selection

```yaml
# Ephemeral: type casting, renaming — no physical table
{{ config(materialized='ephemeral') }}
# Use for: incoming/staging layers, lightweight transforms
# Avoid for: models referenced by many downstream models (recomputed each time)

# View: simple transforms, infrequently queried
{{ config(materialized='view') }}

# Table: complex transforms, frequently queried
{{ config(materialized='table') }}

# Incremental: large datasets, append-only or slowly changing
{{ config(materialized='incremental', unique_key='id') }}

# Materialized View (StarRocks): auto-refreshing aggregations
{{ config(
    materialized='materialized_view',
    refresh_method='ASYNC EVERY (INTERVAL 1 HOUR)'
) }}
```

### Incremental Model Pattern

```sql
-- GOOD: proper incremental with lookback window
{{ config(materialized='incremental', unique_key='id') }}

SELECT ...
FROM {{ ref('source_model') }}

{% if is_incremental() %}
WHERE updated_at >= (
    SELECT DATE_ADD(MAX(updated_at), INTERVAL -30 MINUTE)
    FROM {{ this }}
)
{% endif %}

-- BAD: no lookback window (misses late-arriving data)
{% if is_incremental() %}
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

### Source vs Ref

```sql
-- GOOD: source() for external/raw tables
FROM {{ source('payment_ms', 'transactions') }}

-- GOOD: ref() for dbt model dependencies
FROM {{ ref('stg_transactions') }}

-- BAD: hardcoded table name (breaks lineage, environment portability)
FROM payment_ms_prod.transactions
```

### CDC Deduplication

```sql
-- GOOD: keep latest version of each record
WITH ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY primary_key
            ORDER BY updated_at DESC
        ) AS rn
    FROM {{ ref('incoming_model') }}
)
SELECT * FROM ranked WHERE rn = 1

-- BAD: no deduplication (CDC sends multiple events per record)
SELECT * FROM {{ ref('incoming_model') }}
-- Duplicates accumulate over time
```

---

## SQL Correctness Patterns

### Window Functions After GROUP BY

```sql
-- GOOD: nested aggregate in window function
-- SUM(COUNT(*)) sums the per-group counts across the partition
SELECT
    channel_id,
    category,
    COUNT(*)                                    AS count_per_category,
    SUM(COUNT(*)) OVER (PARTITION BY channel_id) AS total_for_channel
FROM messages
GROUP BY channel_id, category;
-- channel_id=A, category=X: count=30, total=50
-- channel_id=A, category=Y: count=20, total=50

-- BAD: COUNT(*) OVER after GROUP BY counts groups, not rows
SELECT
    channel_id,
    category,
    COUNT(*)                                      AS count_per_category,
    COUNT(*) OVER (PARTITION BY channel_id)        AS total_for_channel
FROM messages
GROUP BY channel_id, category;
-- channel_id=A, category=X: count=30, total=2  ← WRONG! counts 2 groups, not 50 rows

-- Same pattern for MIN/MAX across groups:
-- GOOD
MIN(MIN(timestamp)) OVER (PARTITION BY channel_id) AS earliest_across_all_types
MAX(MAX(timestamp)) OVER (PARTITION BY channel_id) AS latest_across_all_types

-- BAD
MIN(timestamp)  -- only within current group
MAX(timestamp)  -- only within current group
```

### NULL Pitfalls

```sql
-- BAD: = NULL is always false
WHERE status = NULL          -- never matches!
-- GOOD
WHERE status IS NULL

-- BAD: NOT IN with NULLs
WHERE id NOT IN (SELECT id FROM other WHERE id IS NULL)
-- NOT IN returns NULL if any element is NULL → no rows returned!
-- GOOD
WHERE id NOT IN (SELECT id FROM other WHERE id IS NOT NULL)
-- or use NOT EXISTS

-- BAD: COALESCE in wrong place
COALESCE(SUM(amount), 0)     -- SUM of no rows is NULL, COALESCE fixes it ✓
SUM(COALESCE(amount, 0))     -- replaces NULLs before summing — different result!
```

### JOIN Pitfalls

```sql
-- BAD: LEFT JOIN + WHERE on right table = INNER JOIN
SELECT a.*, b.name
FROM orders a
LEFT JOIN customers b ON a.customer_id = b.id
WHERE b.status = 'active'    -- filters out NULLs from LEFT JOIN → becomes INNER
-- GOOD: move filter to ON clause
LEFT JOIN customers b ON a.customer_id = b.id AND b.status = 'active'

-- BAD: JOIN causing fanout (1:many without aggregation)
SELECT o.*, p.name
FROM orders o
JOIN order_items p ON o.id = p.order_id
-- If order has 3 items, order row appears 3x → inflated counts downstream
-- GOOD: aggregate first, then join
```

---

## JSON Handling

### StarRocks JSON Functions

```sql
-- Extract string value
get_json_string(column, '$.field')
get_json_string(column, '$.nested.field')
get_json_string(column, '$[0].field')        -- array element

-- Extract numeric value
get_json_int(column, '$.count')
get_json_double(column, '$.score')

-- Parse string to JSON type
parse_json(varchar_column)

-- Array explosion (UNNEST equivalent)
SELECT t.value
FROM table_name,
     json_each(parse_json(array_column)) t

-- Array length — CORRECT way to count elements
json_length(parse_json(array_column))

-- BAD: comma counting for array size
LENGTH(x) - LENGTH(REPLACE(x, ',', '')) + 1
-- Breaks on: nested objects, strings with commas, empty arrays
-- '[]' → 1 (wrong, should be 0)
-- '[{"a":"b","c":"d"}]' → 3 (wrong, should be 1)
-- '["hello, world"]' → 2 (wrong, should be 1)
```

### Snowflake JSON Functions

```sql
-- Extract with path notation
column:field::VARCHAR
column:nested.field::INT
column[0]:field::VARCHAR

-- Array explosion
SELECT f.value
FROM table_name,
     LATERAL FLATTEN(input => array_column) f

-- Array length
ARRAY_SIZE(array_column)
```

### BigQuery JSON Functions

```sql
-- Extract scalar
JSON_EXTRACT_SCALAR(column, '$.field')

-- Array explosion
SELECT element
FROM table_name,
     UNNEST(JSON_EXTRACT_ARRAY(column, '$.array')) AS element

-- Array length
ARRAY_LENGTH(JSON_EXTRACT_ARRAY(column, '$.array'))
```

### JSON Array to CSV Conversion

```sql
-- FRAGILE: REPLACE chain to strip JSON syntax
REPLACE(REPLACE(REPLACE(REPLACE(
    '["tool_a","tool_b"]',
    '["', ''), '"]', ''), '","', ','), '"', '')
-- Result: 'tool_a,tool_b'
-- Breaks on: empty arrays, values with commas/quotes, single element

-- BETTER: use json_each at the point of consumption
SELECT get_json_string(CAST(t.value AS VARCHAR), '$') AS tool_name
FROM json_each(parse_json(tools_array)) t

-- If CSV is needed, use GROUP_CONCAT after json_each:
SELECT GROUP_CONCAT(
    get_json_string(CAST(t.value AS VARCHAR), '$')
) AS tools_csv
FROM json_each(parse_json(tools_array)) t
```

---

## Data Quality Patterns

### Array Size Counting

```sql
-- WRONG: comma counting
CASE
    WHEN x IS NULL OR x = '[]' THEN 0
    ELSE (LENGTH(x) - LENGTH(REPLACE(x, ',', ''))) + 1
END
-- Fails for: nested objects, strings with commas, single-element arrays with commas

-- CORRECT: JSON parsing (StarRocks)
CASE
    WHEN x IS NULL OR x IN ('[]', '') THEN 0
    ELSE json_length(parse_json(x))
END

-- CORRECT: JSON parsing (Snowflake)
COALESCE(ARRAY_SIZE(x), 0)

-- CORRECT: JSON parsing (BigQuery)
COALESCE(ARRAY_LENGTH(JSON_EXTRACT_ARRAY(x, '$')), 0)
```

### Phantom Values from Empty Arrays

```sql
-- PROBLEM: empty JSON array '[]' processed through REPLACE chain
-- '[]' → REPLACE('["', '') → ']' → REPLACE('"]', '') → '' or '[]'
-- Then in Gold: CONCAT('["', REPLACE('[]', ',', '","'), '"]')
-- → '["[]"]' → json_each → phantom tool named '[]'

-- FIX in Silver: output NULL for empty arrays
CASE
    WHEN sources_used IS NULL OR sources_used IN ('[]', '[""]', '')
    THEN NULL
    ELSE <extraction logic>
END AS tools_used

-- FIX in Gold: defensive filter
WHERE tools_used IS NOT NULL
  AND tools_used != ''
  AND tools_used != '[]'
```

### VARCHAR Truncation

```sql
-- SILENT DATA LOSS: VARCHAR(N) truncates without error in most engines
CAST(large_json_column AS VARCHAR(65000))
-- If data is 70KB, last 5KB silently dropped
-- Downstream parse_json() may fail or return partial data

-- DETECTION: add a data quality test
SELECT COUNT(*) FROM source_table
WHERE LENGTH(json_column) > 64000
-- If count > 0, increase VARCHAR size or use STRING/TEXT type
```

---

## StarRocks-Specific Patterns

### Table Configuration

```sql
-- PRIMARY table: for upserts (CDC, slowly changing dimensions)
{{ config(
    table_type='PRIMARY',
    keys=['id'],
    distributed_by=['id'],
    buckets=8
) }}

-- DUPLICATE table: for append-only (event logs, time series)
{{ config(
    table_type='DUPLICATE',
    distributed_by=['event_date'],
    buckets=16,
    partition_by=["date_trunc('month', event_date)"]
) }}
```

### Distribution Strategy

```sql
-- GOOD: distribute by high-cardinality column used in JOINs
distributed_by=['user_id']    -- many distinct values, used in WHERE/JOIN

-- BAD: distribute by low-cardinality column
distributed_by=['status']     -- only 3-5 values → data skew, hot buckets

-- GOOD: bucket count proportional to data volume
buckets=4    -- < 1M rows
buckets=8    -- 1M-10M rows
buckets=16   -- 10M-100M rows
buckets=32   -- > 100M rows
```

### Materialized View Refresh

```sql
-- Real-time dashboards (payments, alerts)
refresh_method='ASYNC EVERY (INTERVAL 1 MINUTE)'

-- Operational dashboards (agent usage, ingestion)
refresh_method='ASYNC EVERY (INTERVAL 1 HOUR)'

-- Daily reports (reconciliation, billing)
refresh_method="ASYNC START('2025-01-01 00:30:00') EVERY (INTERVAL 1 DAY)"

-- On-demand (TAM/KAM reports, ad-hoc)
refresh_method='MANUAL'

-- CAUTION: MV-on-MV chaining
-- If Gold MV depends on Silver MV, refresh ordering is NOT guaranteed
-- Gold may read stale Silver data
-- Options:
--   1. Stagger intervals (Silver: every 1h at :00, Gold: every 1h at :30)
--   2. Use incremental tables instead of MVs for the base layer
--   3. Accept eventual consistency (data is at most 1 refresh behind)
```

---

## Medallion Architecture

### Layer Responsibilities

```
Bronze (incoming/staging):
  - Raw data from sources
  - Type casting only (CAST to proper types)
  - No business logic
  - Ephemeral in dbt (no physical table)
  - 1:1 mapping with source tables

Silver (intermediate/cleaned):
  - Flatten nested structures (JSON → columns)
  - Deduplicate (ROW_NUMBER for CDC)
  - Resolve business keys
  - Drop heavy/unnecessary fields
  - Apply data quality rules
  - This is the "single source of truth"

Gold (marts/aggregated):
  - Pre-aggregated for specific use cases
  - Optimized for dashboard queries
  - May denormalize for read performance
  - Simple aggregations over Silver
  - Should be fast to refresh
```

### Anti-Patterns

```
BAD: Bronze → Gold (skip Silver)
  - No deduplication
  - No data quality layer
  - No audit trail
  - Gold becomes complex and slow

BAD: Business logic in Bronze
  - Bronze should be a pure mirror of the source
  - Transformations belong in Silver

BAD: Complex JOINs in Gold
  - Gold should aggregate Silver, not join raw sources
  - Heavy JOINs belong in Silver

BAD: Silver depends on Gold
  - Creates circular dependency
  - Gold is derived from Silver, never the reverse
```

---

## Common Anti-Patterns

| Anti-Pattern | Why It's Bad | Fix |
|-------------|-------------|-----|
| Comma counting for JSON array size | Breaks on nested objects, strings with commas | `json_length(parse_json(x))` |
| `COUNT(*) OVER` after `GROUP BY` | Counts groups, not rows | `SUM(COUNT(*)) OVER` |
| `REPLACE` chain for JSON→CSV | Order-dependent, breaks on edge cases | Keep JSON, use `json_each()` at point of use |
| No lookback window in incremental | Misses late-arriving data | `MAX(updated_at) - INTERVAL 30 MINUTE` |
| `VARCHAR(N)` for large JSON | Silent truncation | Use `STRING`/`TEXT` or add length checks |
| Hardcoded schema names in dbt | Breaks environment portability | Use `{{ var(target.name)['environment'] }}` |
| No `unique` test on PKs | Duplicates go undetected | Add `dbt_expectations` tests |
| MV refresh < 1 minute | Wastes compute, may not finish before next refresh | Match refresh to actual data freshness needs |
| `LEFT JOIN` + `WHERE` on right table | Silently becomes `INNER JOIN` | Move filter to `ON` clause |
| `SELECT *` in incremental models | Schema changes break the model | Explicit column list |
