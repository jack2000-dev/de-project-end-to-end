WITH source AS (
    SELECT * FROM {{ source('github_raw', 'commit') }}
),

cleaned AS (
    SELECT
        sha AS commit_sha,
        author_name,
        repository_id,
        author_date AS committed_at
    FROM source
    WHERE sha IS NOT NULL
)

SELECT * FROM cleaned