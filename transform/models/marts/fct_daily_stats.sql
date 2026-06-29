WITH repositories AS (
    SELECT * FROM {{ ref('stg_repositories') }}
),

daily_stats AS (
    SELECT
        DATE_TRUNC('day', updated_at) AS stat_date,
        language,
        COUNT(*) AS repo_count,
        SUM(stars) AS total_stars,
        SUM(forks) AS total_forks,
        ROUND(AVG(stars), 2) AS avg_stars,
        ROUND(AVG(forks), 2) AS avg_forks
    FROM repositories
    WHERE language IS NOT NULL
    GROUP BY 1, 2
)

SELECT * FROM daily_stats