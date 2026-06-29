# Phase 1
- [ ] Build MVP with a contraint of $0 cost
- [ ] Keep it production-grade
- [ ] Implement Star schema

# Phase 2

- [ ] Add Data Quality Tests (dbt)
- [ ] Add Documentation
- [ ] Implement SCD Type 2
- [ ] ADD CI/CD (Github Actions)
- [ ] Add IaC (Terraform)
- [ ] Add Orchestration (Airflow)
- [ ] Monitoring Costs (Grafana)
- [ ] Add more data sources

# Data Architect

1. Source: [Git API](https://docs.github.com/en/rest?apiVersion=2026-03-10)
2. Ingestion: Fivetran
3. Storage: Snowflake
4. Transformation: dbt Cloud
5. BI: Looker Studio

![data-architect](img/data-engineer-project-design.png)

## Star schema

### Fact table
- `fct_repo_activity`: Stores daily counts of commits, PRs, and issues for each repository
### Dimension table
- `dim_repositories`: Stores details about each repository e.g., name, language, owner, and description.
- `dim_users`: Stores user information, e.g., username, name, and profile details.
- `dim_dates`: Stores date-related details, e.g., the date, month, quarter, and year.

## Output
- This project will focus more on the process of data engineer developing a reliable data pipleline and data infrastructure that will serve to DA/DS. 
- Constraint: $0 cost. This project will rely on free and trial products.
- Result: A working product that demonstrate my data engineering skills.
- Business questions (BI)

1. Which programming languages are most popular?
2. Which repository have the most stars?
3. How fast are repositry growing?
4. Who are the most active contributors?
5. How many issues get closed vs stay open?


# Techstack Choices

## Data source
- Kafka (Redpanda)
- Pyflink

## Cloud
- GCP/GCS

## IaC
- Terraform

## Containerization
- Docker (Orbstack)

## Database
- Postgres
- NEON

## Transformation
- dbt-core
- Spark

## Orchestrator
- Airflow

## Dashboard
- Looker Studio

# Reference
- [Your First Data Engineering Project: Build an End-to-End Solution for Free with best tools by Dmitry Anoshin](https://blog.surfalytics.com/p/your-first-data-engineering-project)