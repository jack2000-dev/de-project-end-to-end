WITH source AS (
    SELECT * FROM {{ source('github_raw', 'user') }}
),

cleaned AS (
    SELECT
        id AS user_id,
        login AS username,
        name AS display_name,
        email,
        company,
        location,
        bio,
        public_repos AS public_repo_count,
        followers AS follower_count,
        following AS following_count,
        created_at,
        updated_at
    FROM source
    WHERE id IS NOT NULL
)

SELECT * FROM cleaned