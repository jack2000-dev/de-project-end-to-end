WITH users AS (
    SELECT * FROM {{ ref('stg_users') }}
)

SELECT
    user_id,
    username,
    display_name,
    company,
    location,
    bio,
    created_at AS user_created_at
FROM users