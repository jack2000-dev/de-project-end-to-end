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
        owner_id AS owner_username,
        description,
        language,
        
        -- Metrics
        watchers_count AS stars,
        forks_count AS forks,
        
        -- Dates
        created_at
    FROM source
    WHERE id IS NOT NULL
)

SELECT * FROM cleaned