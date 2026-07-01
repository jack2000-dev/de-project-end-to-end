WITH issues AS (
    SELECT * FROM {{ ref('stg_issues') }}
),

repositories AS (
    SELECT * FROM {{ ref('dim_repositories') }}
)

SELECT
    i.repository_id,
    r.repository_name,
    r.full_name,
    COUNT(*) AS total_issues,
    COUNT_IF(i.issue_state = 'open') AS open_issues,
    COUNT_IF(i.issue_state = 'closed') AS closed_issues,
    ROUND(COUNT_IF(i.issue_state = 'closed') / COUNT(*) * 100, 1) AS closed_pct
FROM issues i
LEFT JOIN repositories r
    ON i.repository_id = r.repository_id
GROUP BY i.repository_id, r.repository_name, r.full_name

-- `COUNT_IF` is a Snowflake shortcut replacing `CASE WHEN`