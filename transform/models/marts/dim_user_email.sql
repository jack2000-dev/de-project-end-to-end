WITH users AS (
    SELECT * FROM {{ ref('stg_user_emails') }}
)

SELECT
    user_id,
    email
FROM users