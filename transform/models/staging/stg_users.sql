WITH source AS (
    SELECT * FROM {{ source('github_raw', 'user') }}
),

cleaned AS (
    SELECT
        id AS user_id,
        login AS username,
        name AS display_name,
        company,
        location,
        bio,
        created_at,
        updated_at
    FROM source
    WHERE id IS NOT NULL
)

SELECT * FROM cleaned