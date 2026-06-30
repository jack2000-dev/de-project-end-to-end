WITH issues AS (
    SELECT * FROM {{ ref('stg_issues') }}
)

SELECT
    repository_id,
    COUNT(*) AS total_issues,
    COUNT_IF(issue_state = 'open') AS open_issues,
    COUNT_IF(issue_state = 'closed') AS closed_issues,
    ROUND(COUNT_IF(issue_state = 'closed') / COUNT(*) * 100, 1) AS closed_pct
FROM issues
GROUP BY repository_id

-- `COUNT_IF` is a Snowflake shortcut replacing `CASE WHEN`