WITH source AS (
    SELECT * FROM {{ source('github_raw', 'user_email') }}
),

cleaned AS (
      SELECT
        user_id,
        email
      FROM source
      WHERE user_id IS NOT NULL
)

SELECT * FROM cleaned
