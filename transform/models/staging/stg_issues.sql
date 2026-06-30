WITH source AS (
    SELECT * FROM {{ source('github_raw', 'issue') }}
),

cleaned AS (
    SELECT
        id AS issue_id,
        number AS issue_number,
        state AS issue_state, -- 'open' / 'closed'
        title,
        user_id,
        repository_id,
        created_at,
        closed_at
    FROM source
    WHERE id IS NOT NULL
)

SELECT * FROM cleaned