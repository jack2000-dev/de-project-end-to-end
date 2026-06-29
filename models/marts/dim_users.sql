WITH users AS (
    SELECT * FROM {{ ref('stg_users') }}
)

SELECT
    user_id,
    username,
    display_name,
    email,
    company,
    location,
    bio,
    public_repo_count,
    follower_count,
    following_count,
    created_at AS user_created_at
FROM users