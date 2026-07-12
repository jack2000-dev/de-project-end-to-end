# GCP / BigQuery Migration Notes

## Create dataset schema

- Using `gcp_db_structure.sql` file in the `infra/gcp` directory, create the necessary datasets and tables in BigQuery for the project. This will create the necessary datasets and tables for the project.

## Create service account and grant permissions

- BigQuery Data Editor + BigQuery Job User
- BigQuery Read Session User, needed separately for the Storage API to stream query results back. Data Editor and Job User do not include `bigquery.readsessions.create`, so without this role `dbt debug` fails with a misleading `AuthenticationFailed` error whose real message is `Storage API is not available for query`
- Add the `.json` key files in `.gitignore`

## Configure dbt profile (transform/profiles.yml)

- Replace the Snowflake target with a bigquery target: `type: bigquery`, `method: service-account`, `project`, `dataset`, `keyfile`, `threads`
- Keyfile path goes through `env_var`, same pattern as the old Snowflake password. Add `GCP_KEYFILE` to `.env` (use an absolute path) and reference it as `{{ env_var('GCP_KEYFILE') }}` in profiles.yml
- `dataset` field is just a fallback schema, not really used since every model already sets its own `+schema` (same as the old unused FIVETRAN schema fallback, see NOTE.md)
- `threads: 6` is fine to keep. BigQuery is serverless, so it is limited by project query quota, not warehouse size

## Update dbt_project.yml

- Important: unlike Snowflake's 3 separate databases, BigQuery only has 1 project. Do not vary `+database` per layer anymore
- Only `+schema` should differ per layer: staging uses `GITHUB_STAGING`, marts uses `GITHUB_ANALYTICS`

## Update sources (_staging.yml)

- Old source pointed at `database: GITHUB_RAW, schema: GITHUB` (Fivetran's locked schema name)
- New source should point at `schema: GITHUB_RAW` (the dataset the new pipeline writes into directly), drop or update `database` to the project id

## Verify

- Run `dbt debug` from `transform/` before anything else
- Confirm datasets exist and the service account has access before troubleshooting dbt errors

## Known SQL dialect fixes (after dbt debug passes)

- `fct_issues.sql`: `COUNT_IF(...)` becomes `COUNTIF(...)`, no underscore
- `fct_contributors.sql` and `fct_daily_stats.sql`: `DATE_TRUNC('day', column)` becomes `DATE_TRUNC(column, DAY)`. Arguments are reversed in BigQuery and `DAY` is a bare keyword, not a string
- Re-check every model for other Snowflake-specific syntax. Build one model at a time and check the actual values, not just whether it errors
