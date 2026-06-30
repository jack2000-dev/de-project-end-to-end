# Data Engineering Project Notes

Lecture-style notes on every problem faced building this pipeline and how each was solved.

Pipeline: GitHub API -> Fivetran -> Snowflake -> dbt -> Looker Studio

---

## 1. dbt Profiles: which profiles.yml is which?

**Problem:** Confusion between two profiles.yml files. One in `~/.dbt/profiles.yml` (global) and one created by dbt Cloud that contained credentials and wanted to be committed to GitHub.

**Key concepts:**
- dbt needs a `profiles.yml` to know how to connect to the warehouse.
- The "profile name" is the top-level YAML key in profiles.yml. It must match the `profile:` value in `dbt_project.yml`.
- Local dbt CLI reads from `~/.dbt/profiles.yml` by default, OR from a directory set by `DBT_PROFILES_DIR`.

**Solution:**
- Keep ONE source of truth. Use a project-level `profiles.yml` inside `transform/` that uses `env_var()` references instead of hardcoded credentials.
- Never commit a profiles.yml that contains passwords.

---

## 2. Profile name mismatch

**Problem:** Error `Profile 'default' not found in profiles.yml`.

**Cause:** `dbt_project.yml` had `profile: 'default'` but the top-level key in profiles.yml was something else (for example `user:`).

**Solution:** The profile name is the TOP-LEVEL key in profiles.yml, not `default`, not `dbname`. Make `dbt_project.yml`'s `profile:` match that exact key.

---

## 3. Credential-free profiles with env_var

**Problem:** Wanted a clean local dev setup without passwords sitting in profiles.yml.

**Solution:** Use Jinja `env_var()` in profiles.yml and store secrets in a `.env` file at the project root.

```yaml
default:
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: "{{ env_var('SNOWFLAKE_ROLE') }}"
      warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE') }}"
      database: GITHUB_STAGING
      schema: dev
      threads: 1
  target: dev
```

This profiles.yml is safe to commit because it holds no secrets. The `.env` stays gitignored.

---

## 4. DBT_PROFILES_DIR pointing to a file

**Problem:** Error showing a doubled path `profiles.yml/profiles.yml`.

**Cause:** Set `DBT_PROFILES_DIR` to the file path. dbt appends `profiles.yml` automatically, so it must point to the DIRECTORY.

**Solution:**
```bash
export DBT_PROFILES_DIR=/path/to/transform
```
Point it to the folder that contains profiles.yml, not the file itself.

---

## 5. .env not visible to dbt

**Problem:** dbt threw `env_var SNOWFLAKE_ACCOUNT not found` even though the values were in `.env`.

**Cause:** Variables set without `export` are not passed to child processes (dbt runs as a child process).

**Solution:** Auto-export everything when sourcing:
```bash
set -a && source .env && set +a
```
Or prefix each line in `.env` with `export`. For convenience, `direnv` can auto-load `.env` on entering the directory.

---

## 6. .env parse error near `&`

**Problem:** `parse error near '&'` when sourcing `.env`.

**Cause:** Special characters in values (like `&`) are interpreted by the shell.

**Solution:** Wrap all values in double quotes.
```bash
export SNOWFLAKE_PASSWORD="my&pass"
```

---

## 7. The .user.yml file

**Problem:** dbt generated `transform/.user.yml`. Unsure what it is.

**Solution:** It only holds an anonymous user id for dbt. It is a local file and should be gitignored. Already covered by the `.user.yml` entry in `.gitignore`.

---

## 8. The target/ folder

**Question:** What is the `target/` folder in dbt?

**Answer:** It is generated output. dbt compiles models into runnable SQL and stores artifacts (compiled SQL, run results, manifest) there. Never edit it by hand. It is gitignored.

---

## 9. Snowflake database vs schema

**Problem:** Could not tell which object in the Snowflake explorer was a database and which was a schema.

**Key concept:** Snowflake has a 3-level hierarchy:
```
Database -> Schema -> Table
```

**Project structure (medallion architecture):**
- `GITHUB_RAW` = Bronze, raw data from Fivetran
- `GITHUB_STAGING` = Silver, cleaned staging views
- `GITHUB_ANALYTICS` = Gold, business-ready marts

---

## 10. Data landed in the wrong schema (FIVETRAN vs GITHUB)

**Problem:** Configured the dbt source as `GITHUB_RAW.FIVETRAN`, but data actually landed in `GITHUB_RAW.GITHUB`. Error: `Schema 'GITHUB_RAW.FIVETRAN' does not exist`.

**Cause:** Fivetran names the destination schema after the connector type (`github`), and that name is LOCKED after the first save. It ignored the intended `FIVETRAN` name.

**Solution:** Update the dbt source in `_staging.yml` to match reality:
```yaml
sources:
  - name: github_raw
    database: GITHUB_RAW
    schema: GITHUB
```

**Lesson:** `GITHUB` is arguably the better name anyway since it describes the data origin. The production way to handle this is to align dbt sources to whatever the ingestion tool actually produces.

---

## 11. Schema does not exist or not authorized

**Problem:** Error `Schema 'GITHUB_RAW.GITHUB' does not exist or not authorized` even after granting the role.

**Cause:** In Snowflake, access needs USAGE on the database AND on each schema, plus SELECT on tables. The schema-level USAGE grant was missing.

**Solution:** Add schema grants (including FUTURE schemas so new ones are covered automatically):
```sql
GRANT USAGE ON ALL SCHEMAS IN DATABASE GITHUB_RAW TO ROLE DBT_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE GITHUB_RAW TO ROLE DBT_ROLE;
```

---

## 12. Invalid column identifiers in models

**Problem:** Errors like `invalid identifier EMAIL`, `OWNER_LOGIN`, `OPEN_ISSUES`, `UPDATED_AT`.

**Cause:** The tutorial's model SQL assumed GitHub API field names, but Fivetran's connector does not load all of those fields. The tutorial code did not match the actual Fivetran output.

**Solution:** Inspect the real columns in Snowflake and rewrite models to use only what exists.

| Tutorial assumed | Fivetran actually provides |
|---|---|
| owner_login | owner_id only |
| stargazers_count | watchers_count |
| open_issues_count | not synced |
| updated_at, pushed_at | not synced |
| email, public_repos, followers, following | not synced (email lives in a separate USER_EMAIL table) |

**Lesson:** Never trust tutorial column names. Always verify against the source.

---

## 13. Reserved keyword: following

**Problem:** `following` is a reserved keyword in Snowflake and broke the query.

**Solution:** Quote it: `"following"`. (Ultimately removed since the column did not exist anyway.)

---

## 14. Email in a separate table

**Problem:** `email` column did not exist on the USER table.

**Cause:** Fivetran splits email into a separate `USER_EMAIL` table. One user can have multiple emails.

**Solution:** Create a dedicated `stg_user_emails` staging model from the `user_email` source table.

---

## 15. dbt tests and grain

**Concept:** A dbt test is a SQL query that looks for rows that should NOT exist. 0 rows returned = pass. Any rows = fail.

**Built-in generic tests used:** `unique`, `not_null`.

**Problem found:** `stg_user_emails` had a `unique` test on `user_id`. But one user can have many emails, so `user_id` is not unique here. The test would fail.

**Solution:** Put `unique` on the column that is actually one-row-per-value (the grain). For emails, that is `email`, not `user_id`.

```yaml
- name: stg_user_emails
  columns:
    - name: user_id
      tests:
        - not_null
    - name: email
      tests:
        - unique
        - not_null
```

**Lesson:** Always ask "what is the grain of this table?" before adding a unique test.

**Running tests:**
```bash
dbt test                    # all tests, after dbt run
dbt build                   # runs models AND tests in DAG order
```

---

## 16. No usable date column for dashboards

**Problem:** Worried there was no date column for Looker Studio, and `fct_daily_stats` used a non-existent `updated_at`.

**Solution:** Use `created_at` (exists on USER and REPOSITORY) or `_fivetran_synced`. For `fct_daily_stats`, group by `created_at` to show repos created per day by language. Still a valid, meaningful metric.

---

## 17. dbt output landed in the wrong database and schema

**Problem:** dbt built everything into `GITHUB_STAGING` with prefixed schemas `FIVETRAN_STAGING` and `FIVETRAN_MARTS`. The marts were supposed to be in `GITHUB_ANALYTICS`, and `GITHUB_ANALYTICS.MARTS` was empty.

**Cause (two separate issues):**
1. dbt writes every model into the `database` from the active connection (`GITHUB_STAGING`). The `+schema` config changes the schema only, never the database. dbt does not read `db_structure.sql`.
2. dbt's default `generate_schema_name` macro concatenates `<connection_schema>_<custom_schema>`. Connection schema `FIVETRAN` + custom `marts` = `FIVETRAN_MARTS`. The prefix is a team safety feature.

**Solution part A:** Route layers to the right database with `+database`:
```yaml
models:
  de-project-end-to-end:
    staging:
      +database: GITHUB_STAGING
      +schema: staging
      +materialized: view
    marts:
      +database: GITHUB_ANALYTICS
      +schema: marts
      +materialized: table
```

**Solution part B:** Override the schema naming macro to use names verbatim. Create `transform/macros/generate_schema_name.sql`:
```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

**Permissions follow-up:** marts now write to a new database, so grant it:
```sql
GRANT USAGE, CREATE SCHEMA ON DATABASE GITHUB_ANALYTICS TO ROLE DBT_ROLE;
```

**Cleanup:** old objects do not auto-delete:
```sql
DROP SCHEMA GITHUB_STAGING.FIVETRAN_STAGING;
DROP SCHEMA GITHUB_STAGING.FIVETRAN_MARTS;
```

**Lesson:** dbt creates schemas automatically. You do not need manual CREATE SCHEMA statements.

---

## 18. Scheduling daily runs with dbt Cloud

**Goal:** Run transforms daily without keeping the laptop on.

**Mental model:** Locally, you are the runtime. In dbt Cloud, dbt Cloud is the runtime. It clones the repo, uses credentials stored in the Cloud UI (not your `.env`), and runs on a schedule.

**Setup:**
1. Connect the GitHub repo. Set the project subdirectory to `transform` since the dbt project is not at repo root.
2. Configure connection (account, warehouse) and deployment credentials in the UI. dbt Cloud does NOT use profiles.yml; it generates the profile from these settings.
3. Create a Deployment environment with a target schema (for example PROD).
4. Create a Job:
   - Command: `dbt build`
   - Schedule: cron such as `0 6 * * *` (06:00 UTC daily). Schedules are in UTC.

**Ordering:** Fivetran must sync before dbt runs. Simplest approach is a time offset (Fivetran at 05:00 UTC, dbt at 06:00 UTC). Advanced approach is trigger chaining via Fivetran calling the dbt Cloud API.

**Production touches:** failure notifications, `dbt source freshness` checks, and a separate PROD schema isolated from dev.

---

## Key Takeaways

- The profile name is the top-level key in profiles.yml and must match `dbt_project.yml`.
- Keep secrets in `.env`, reference them with `env_var()`, never commit credentials.
- `DBT_PROFILES_DIR` points to a directory, not a file.
- Use `export` (or `set -a`) so env vars reach the dbt child process.
- Snowflake hierarchy is Database -> Schema -> Table; access needs USAGE at every level.
- Ingestion tools name things their own way (Fivetran used GITHUB). Align dbt sources to reality.
- Never trust tutorial column names. Verify against the actual source.
- dbt tests look for rows that should not exist. Match unique tests to the table grain.
- dbt writes to the connection database by default. Use `+database` and a custom `generate_schema_name` macro to control placement.
- dbt creates schemas automatically and never reads your manual SQL setup scripts.
- dbt Cloud becomes the runtime for scheduled jobs; credentials live in the UI, not your `.env`.

# dbt Notes

## dbt_project.yml vs profiles.yml

The two files confuse people because both are YAML and both configure dbt, but they answer different questions.

| | profiles.yml | dbt_project.yml |
|---|---|---|
| Answers | WHERE do I connect? | WHAT do I build and HOW? |
| Concerns | Connection / credentials | Project structure / behavior |
| Contains | account, user, password, role, warehouse, database, schema, threads | project name, model paths, materializations, +schema, +database, tests, seeds config |
| Holds secrets? | Yes (passwords) | No, never |
| Lives where | ~/.dbt/ or a private dir; gitignored when it has creds | Repo root of the dbt project (transform/); committed |
| One per | Machine / environment | Project |

Analogy: profiles.yml is the key to the building (how you get into Snowflake). dbt_project.yml is the blueprint of what you build once you are inside.

The link between them: dbt_project.yml has a `profile:` line, and that name must match the top-level key in profiles.yml. That is the handshake.

```
dbt_project.yml:  profile: 'default'  ----+
                                          | must match
profiles.yml:     default:  <-------------+
```

Where models land (database/schema) is a WHAT/HOW decision, so it belongs in dbt_project.yml, not profiles.yml. The connection (profiles.yml) only sets the default landing zone.

---

## How dbt run, dbt test, and dbt build work together

Two kinds of work dbt does:

- **dbt run** = builds your models. It takes each .sql file, wraps it in CREATE VIEW / CREATE TABLE, and executes it in Snowflake. Produces STG_USERS, DIM_REPOSITORIES, etc. It does NOT run any tests.
- **dbt test** = runs your tests (the unique, not_null, etc. from _staging.yml). It queries tables/views that already exist, so it is useless until dbt run has built them.

Manual two-step workflow:

```bash
dbt run     # build everything
dbt test    # then check everything
```

Problem with two steps: dbt run builds everything first, ignoring quality. If stg_users has duplicate IDs, dim_users gets built on top of bad data anyway, and you only find out at the very end.

### dbt build fixes that

**dbt build** = run + test (plus seeds and snapshots) interleaved in DAG order, model by model.

DAG = the dependency graph dbt builds from your ref() and source() calls. It knows dim_users depends on stg_users, so it orders them.

dbt build walks that graph and, for each node:

```
build stg_users  ->  test stg_users  ->  (pass?) ->  build dim_users  ->  test dim_users ...
                                         (fail?) ->  SKIP dim_users (and anything downstream)
```

Key advantage: if a model's tests fail, dbt build stops bad data from flowing downstream. You never build dim_users on top of a broken stg_users.

### Comparison

| Command | Builds models | Runs tests | Stops on test failure |
|---|---|---|---|
| dbt run | Yes | No | n/a |
| dbt test | No | Yes | reports, but nothing was building |
| dbt build | Yes | Yes | Yes, skips downstream |

### What to use when

- **dbt run** while iterating fast on one model's SQL and you do not care about tests yet. Often with --select: `dbt run --select stg_users`.
- **dbt test** when you changed only tests, or want to re-check without rebuilding.
- **dbt build** as the default for any real run, and always in the scheduled dbt Cloud job. It is the production-correct command because it guarantees tested data.

