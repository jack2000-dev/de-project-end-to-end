WITH source AS (
    SELECT * FROM {{ source('github_raw', 'repository') }}
),

cleaned AS (
    SELECT
        -- Primary key
        id AS repository_id,
        
        -- Attributes
        name AS repository_name,
        full_name,
        owner_login AS owner_username,
        description,
        language,
        
        -- Metrics
        stargazers_count AS stars,
        forks_count AS forks,
        open_issues_count AS open_issues,
        
        -- Dates
        created_at,
        updated_at,
        pushed_at
    FROM source
    WHERE id IS NOT NULL
)

SELECT * FROM cleaned