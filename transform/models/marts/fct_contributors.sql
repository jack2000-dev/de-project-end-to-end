WITH commits AS (
    SELECT * FROM {{ ref('stg_commits') }}
)

SELECT
    author_name,
    DATE_TRUNC('day', committed_at) AS commit_date,
    COUNT(*) AS commit_count,
    COUNT(DISTINCT repository_id) AS repos_contributed_to
FROM commits
WHERE author_name IS NOT NULL
GROUP BY author_name, commit_date