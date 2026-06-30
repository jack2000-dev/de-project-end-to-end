WITH repositories AS (
    SELECT * FROM {{ ref('stg_repositories') }}
)

SELECT
    repository_id,
    repository_name,
    full_name,
    owner_username,
    description,
    language,
    stars,
    forks,
    created_at AS repo_created_at,
FROM repositories